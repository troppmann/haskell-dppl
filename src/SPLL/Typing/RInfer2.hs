
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module SPLL.Typing.RInfer2 (
  inferRType
, RTypeError (..)
, addRTypeInfo
, tryAddRTypeInfo
) where

import Control.Monad.Except
import Control.Monad.State
import Control.Monad.Reader
import Control.Monad.Identity

import Data.List (nub)
import qualified Data.Set as Set
import Data.Monoid
import Data.Foldable hiding (toList)
import qualified Data.Map as Map

import SPLL.Typing.RInfer (Scheme (..))

import Text.Pretty.Simple

import SPLL.Lang.Lang
import SPLL.Typing.Typing
import SPLL.Typing.RType
import SPLL.Examples
import SPLL.Typing.PType( PType(..) )
import SPLL.InferenceRule

import PredefinedFunctions

data RTypeError
  = UnificationFail RType RType
  | InfiniteType TVarR RType
  | UnboundVariable String
  | Ambigious [Constraint]
  | UnificationMismatch [RType] [RType]
  | ExprInfo [String]
  | FalseParameterFail String
  deriving (Show)

data TEnv = TypeEnv { types :: Map.Map Name Scheme }
  deriving (Eq, Show)

empty :: TEnv
empty = TypeEnv Map.empty

extend :: TEnv -> (Name, Scheme) -> TEnv
extend env (x, s) = env { types = Map.insert x s (types env) }

remove :: TEnv -> Name -> TEnv
remove (TypeEnv env) var = TypeEnv (Map.delete var env)

extends :: TEnv -> [(Name, Scheme)] -> TEnv
extends env xs = env { types = Map.union (Map.fromList xs) (types env) }

lookupE :: Name -> TEnv -> Maybe Scheme
lookupE key (TypeEnv tys) = Map.lookup key tys

merge :: TEnv -> TEnv -> TEnv
merge (TypeEnv a) (TypeEnv b) = TypeEnv (Map.union a b)

mergeTEnvs :: [TEnv] -> TEnv
mergeTEnvs = foldl' merge empty

singleton :: Name -> Scheme -> TEnv
singleton x y = TypeEnv (Map.singleton x y)

keys :: TEnv -> [Name]
keys (TypeEnv env) = Map.keys env

fromList :: [(Name, Scheme)] -> TEnv
fromList xs = TypeEnv (Map.fromList xs)

toList :: TEnv -> [(Name, Scheme)]
toList (TypeEnv env) = Map.toList env

instance Semigroup TEnv where
  (<>) = merge

instance Monoid TEnv where
  mempty = empty
  mappend = (<>)


makeMain :: Expr a -> Program a
makeMain expr = Program [("main", expr)] []

-- | Inference monad
type Infer a = (ReaderT
                  TEnv             -- Typing TEnvironment
                  (StateT         -- Inference state
                  InferState
                  (Except         -- Inference errors
                    RTypeError))
                  a)              -- Result

-- | Inference state
data InferState = InferState { var_count :: Int }

-- | Initial inference state
initInfer :: InferState
initInfer = InferState { var_count = 0 }

type Constraint = (RType, RType)

type Unifier = (Subst, [Constraint])

-- | Constraint solver monad
type Solve a = ExceptT RTypeError Identity a

newtype Subst = Subst (Map.Map TVarR RType)
  deriving (Eq, Show, Monoid, Semigroup)

class Substitutable a where
  apply :: Subst -> a -> a
  ftv   :: a -> Set.Set TVarR

instance Substitutable (Program a) where
  apply s (Program decls nns) = Program (zip (map fst decls) (map (apply s . snd) decls)) nns
  ftv _ = Set.empty

instance Substitutable (Expr a) where
  apply s = tMap (apply s . getTypeInfo)
  ftv _ = Set.empty

instance Substitutable (TypeInfo a) where
  apply s ti@(TypeInfo {rType=rt}) = setRType ti (apply s rt)
  ftv _ = Set.empty

instance Substitutable RType where
  apply _ TBool = TBool
  apply _ TInt = TInt
  apply _ TSymbol = TSymbol
  apply _ TFloat = TFloat
  apply _ NullList = NullList
  apply _ BottomTuple = BottomTuple
  apply s (ListOf t) = ListOf $ apply s t
  apply s (Tuple t1 t2) = Tuple (apply s t1) (apply s t2)
  apply s (TArrow t1 t2) = apply s t1 `TArrow` apply s t2
  apply (Subst s) t@(TVarR a) = Map.findWithDefault t a s
  apply s (GreaterType t1 t2) = apply s t1 `GreaterType` apply s t2
  -- rest of RType arent used as of now
  apply _ val = error ("Missing Substitute: " ++ show val)

  ftv (ListOf t) = ftv t
  ftv (Tuple t1 t2) = Set.union (ftv t1) (ftv t2)
  ftv (TVarR a)       = Set.singleton a
  ftv (t1 `TArrow` t2) = ftv t1 `Set.union` ftv t2
  ftv (t1 `GreaterType` t2) = ftv t1 `Set.union` ftv t2
  ftv _ = Set.empty

instance Substitutable Scheme where
  apply (Subst s) (Forall as t)   = Forall as $ apply s' t
                            where s' = Subst $ foldr Map.delete s as
  ftv (Forall as t) = ftv t `Set.difference` Set.fromList as

instance Substitutable Constraint where
   apply s (t1, t2) = (apply s t1, apply s t2)
   ftv (t1, t2) = ftv t1 `Set.union` ftv t2

instance Substitutable a => Substitutable [a] where
  apply = map . apply
  ftv   = foldr (Set.union . ftv) Set.empty

instance Substitutable TEnv where
  apply s (TypeEnv env) = TypeEnv $ Map.map (apply s) env
  ftv (TypeEnv env) = ftv $ Map.elems env

addRTypeInfo :: (Show a) => Program a -> Program a
addRTypeInfo p =
  case runInfer empty (inferProg p) of
    Left err -> error ("error in addRTypeInfo: " ++ show err)
    Right (ty, cs, p) -> case runSolve cs of
      Left err -> error ("error in solve addRTypeInfo: " ++ show err)
      Right subst -> apply subst p

tryAddRTypeInfo :: (Show a) => Program a -> Either RTypeError (Program a)
tryAddRTypeInfo p@(Program decls _) = do
  (ty, cs, p) <- runInfer empty (inferProg p)
  subst <- runSolve cs
  return $ apply subst p

inferRType :: (Show a) => Program a -> Either RTypeError RType
inferRType = undefined

rtFromScheme :: Scheme -> RType
rtFromScheme (Forall _ rt) = rt

--TODO: Simply give everything a fresh var as a unified first pass.
inferProg :: (Show a) => Program a -> Infer (RType, [Constraint], Program a)
inferProg p@(Program decls nns) = do
  -- init type variable for all function decls beforehand so we can build constraints for
  -- calls between these functions
  tv_rev <- freshVars (length decls) []
  let tvs = reverse tv_rev
  -- env building with (name, scheme) for infer methods
  let func_tvs = zip (map fst decls) (map (Forall []) tvs)
  -- infer the type and constraints of the declaration expressions
  cts <- mapM ((inTEnvF func_tvs . infer) . snd) decls
  let Just expr = lookup "main" decls
  -- inferring the type of the top level expression
  (t1, c1, et) <- inTEnvF func_tvs (infer expr)
  -- building the constraints that the built type variables of the functions equal
  -- the inferred function type
  let tcs = zip (map (rtFromScheme . snd) func_tvs) (map fst3cts cts)
  -- combine all constraints
  return (t1, tcs ++ concatMap snd3cts cts ++ c1, Program (zip (map fst decls) (map trd3cts cts)) nns)

--TODO: Error on ambiguous InferenceRule
infer :: Show a => Expr a -> Infer (RType, [Constraint], Expr a)
infer expr = if solvesSimply
    then if not allSchemesEq
      then error "unviable Inference Rule configuration"
      else do
        -- use ForAll scheme from InferenceRule.
        let subexprs = getSubExprs expr
        tuples <- mapM infer subexprs
        let localConstraints = concatMap snd3cts tuples
        let subExprTypes = map fst3cts tuples
        let typedSubExprs = map trd3cts tuples
        rescoped <- rescope scheme
        (resultingtype, recursiveConstraints) <- inferResultingType rescoped subExprTypes
        return (resultingtype, recursiveConstraints ++ localConstraints, reformExpr expr typedSubExprs resultingtype)
    else
      error ("no inference implemented for " ++ show expr)
  where
    plausibleAlgs = filter (checkExprMatches expr) allAlgorithms
    --since we don't care about ambiguous inference rules (i.e. multiple plausible rules)
    -- we just make sure that they agree on resulting types.
    allSchemesEq = all (\alg -> assumedRType (head plausibleAlgs) == assumedRType alg) (tail plausibleAlgs)
    solvesSimply = not (null plausibleAlgs)
    scheme = assumedRType (head plausibleAlgs)

--put all new TVars into a scheme
rescope :: Scheme -> Infer Scheme
rescope (Forall tvars rty) = do
  newTVars <- mapM (const fresh) tvars
  let newvars = map unwrap newTVars
  let substitution = Subst $ Map.fromList (zip tvars newTVars)
  let substituted = apply substitution rty
  return (Forall newvars substituted)
    where unwrap (TVarR tv) = tv

-- into an existing expression, replace a subexpresison and rtype.
reformExpr :: Expr a -> [Expr a] -> RType -> Expr a
reformExpr original subexprs ownTy = tMapHead (const newTy) $ setSubExprs original subexprs
  where
    newTy = setRType (getTypeInfo original) ownTy

--take a scheme like Forall [a,b,c] (a -> b -> c) and apply a list of types Int, Float to the scheme.
-- should yield (c, [a=Int, b=Float])
inferResultingType :: Scheme -> [RType] -> Infer (RType, [Constraint])
inferResultingType (Forall vars rtype) [] = return (rtype, [])
inferResultingType (Forall vars (TArrow fromTy toTy)) (fstTy:rtypes2) =
  do
    let constraint = (fromTy, fstTy)
    (resultingType, moreConstraints) <- inferResultingType (Forall vars toTy) rtypes2
    return (resultingType, constraint:moreConstraints)


-- | Extend type TEnvironment
inTEnvF :: [(Name, Scheme)] -> Infer a -> Infer a
inTEnvF [] m = m
inTEnvF ((x, sc): []) m = do
  let scope e = remove e x `extend` (x, sc)
  local scope m
inTEnvF ((x, sc): r) m = do
  let scope e = remove e x `extend` (x, sc)
  inTEnvF r (local scope m)

fst3cts ::  (RType, [Constraint], Expr a) -> RType
fst3cts (t, _, _) = t
snd3cts ::  (RType, [Constraint], Expr a) -> [Constraint]
snd3cts (_, cts, _) = cts
trd3cts ::  (RType, [Constraint], Expr a) -> Expr a
trd3cts (_, _, e) = e


letters :: [String]
letters = [1..] >>= flip replicateM ['a'..'z']

fresh :: Infer RType
fresh = do
    s <- get
    put s{var_count = var_count s + 1}
    return $ TVarR $ TV (letters !! var_count s)

freshVars :: Int -> [RType] -> Infer [RType]
freshVars 0 rts = do
    return rts
freshVars n rts = do
    s <- get
    put s{var_count = var_count s + 1}
    freshVars (n - 1)  (TVarR (TV (letters !! var_count s)):rts)


-- | Run the inference monad
runInfer :: TEnv -> Infer (RType, [Constraint], Program a) -> Either RTypeError (RType, [Constraint], Program a)
runInfer env m = runExcept $ evalStateT (runReaderT m env) initInfer


-------------------------------------------------------------------------------
-- Constraint Solver
-------------------------------------------------------------------------------

-- | The empty substitution
emptySubst :: Subst
emptySubst = mempty

-- | Compose substitutions
compose :: Subst -> Subst -> Subst
(Subst s1) `compose` (Subst s2) = Subst $ Map.map (apply (Subst s1)) s2 `Map.union` s1

-- | Run the constraint solver
runSolve :: [Constraint] -> Either RTypeError Subst
runSolve cs = runIdentity $ runExceptT $ solver st
  where st = (emptySubst, cs)

-- Unification solver
solver :: Unifier -> Solve Subst
solver (su, cs) =
  case cs of
    [] -> return su
    ((t1, t2): cs0) -> do
      su1  <- unifies t1 t2
      solver (su1 `compose` su, apply su1 cs0)

unifies :: RType -> RType -> Solve Subst
unifies t1 t2 | t1 == t2 = return emptySubst
unifies (Tuple t1 t2) BottomTuple = return emptySubst
unifies BottomTuple (Tuple t1 t2) = return emptySubst
unifies (ListOf t) NullList = return emptySubst
unifies NullList (ListOf t) = return emptySubst
unifies t1 (GreaterType (TVarR v) t3) = if t1 == t3 then v `bind` t1 else
  throwError $ UnificationFail t1 t3
unifies t1 (GreaterType t3 (TVarR v)) = if t1 == t3 then v `bind` t1 else
  throwError $ UnificationFail t1 t3
unifies (TVarR v) (GreaterType t2 t3) = case greaterType t2 t3 of
  Nothing -> throwError $ UnificationFail t2 t3
  Just t -> v `bind` t
unifies t1 (GreaterType t2 t3) = if t1 == t2 && t2 == t3 then return emptySubst else
  (case greaterType t2 t3 of
    Nothing -> throwError $ UnificationFail t1 (GreaterType t2 t3)
    Just tt -> if t1 == tt then return emptySubst else throwError $  UnificationFail t1 (GreaterType t2 t3))
unifies (TVarR v) t = v `bind` t
unifies t (TVarR v) = v `bind` t
unifies (TArrow t1 t2) (TArrow t3 t4) = unifyMany [t1, t2] [t3, t4]
unifies (Tuple t1 t2) (Tuple t3 t4) = unifyMany [t1, t2] [t3, t4]
unifies t1 t2 = throwError $ UnificationFail t1 t2

unifyMany :: [RType] -> [RType] -> Solve Subst
unifyMany [] [] = return emptySubst
unifyMany (t1 : ts1) (t2 : ts2) =
  do su1 <- unifies t1 t2
     su2 <- unifyMany (apply su1 ts1) (apply su1 ts2)
     return (su2 `compose` su1)
unifyMany t1 t2 = throwError $ UnificationMismatch t1 t2

bind ::  TVarR -> RType -> Solve Subst
bind a t | t == TVarR a     = return emptySubst
         | occursCheck a t = throwError $ InfiniteType a t
         | otherwise       = return (Subst $ Map.singleton a t)
         
occursCheck ::  Substitutable a => TVarR -> a -> Bool
occursCheck a t = a `Set.member` ftv t
