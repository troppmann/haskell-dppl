{-# OPTIONS_GHC -fwarn-incomplete-patterns #-}
{-# LANGUAGE FlexibleContexts #-}

module SPLL.Typing.Typing (
  Env,
  TypeError,
  TypeInfo(..),
  ChainName,
  HornClause,
  Tag(..),
  CType(..),
  makeTypeInfo,
  setRType,
  setPType,
  setCType,
  setWitnessedVars,
  setChainName,
  setTags,
  progToEnv,
  autoVal,
  autoEnv,
  autoExpr
)where

import SPLL.Lang
import SPLL.Typing.RType
import SPLL.Typing.PType
import SPLL.InferenceRule
import GHC.Records

import Data.Maybe
import Data.Set (empty)
import Control.Monad.Reader
import Control.Monad.Except

import Numeric.AD (grad', auto)
import Numeric.AD.Internal.Reverse ( Reverse, Tape)
import Data.Reflection (Reifies)
data Tag a = EnumRange (Value a, Value a)
           | EnumList [Value a]
           | Alg InferenceRule
           deriving (Show, Eq, Ord)

type ChainName = String

-- (Set of Preconditions with CType, set of Inferable variables with attached CType, Expression this HornClause originates from with its inversion number
type HornClause a = ([(ChainName, CType a)], [(ChainName, CType a)], (ExprStub, Int))

data CType a = CDeterministic
             | CInferDeterministic
             | CConstrainedTo a a
             | CBottom
             | CNotSetYet
             deriving (Show, Eq)
           
instance Eq a => Ord (CType a) where
  compare x y = compare (rank x) (rank y)
    where
      rank CDeterministic = 10
      rank CInferDeterministic = 9
      rank (CConstrainedTo _ _) = 5
      rank CBottom = 1
      rank CNotSetYet = -1

--Do not use this constructor, use makeTypeInfo instead
data TypeInfo a = TypeInfo
  { rType :: RType
  , pType :: PType
  , cType :: CType a
  , derivingHornClause :: Maybe (HornClause a)
  , witnessedVars :: WitnessedVars
  , chainName :: ChainName
  , tags :: [Tag a]} deriving (Show, Eq, Ord)
-- only use ord instance for algorithmic convenience, not for up/downgrades / lattice work.

makeTypeInfo = TypeInfo
    { rType = SPLL.Typing.RType.NotSetYet
    , pType = SPLL.Typing.PType.NotSetYet
    , cType = CNotSetYet
    , derivingHornClause = Nothing
    , witnessedVars = empty
    , chainName = ""
    , tags = []}

setRType :: TypeInfo a -> RType -> TypeInfo a
setRType t rt = t {rType = rt}

setPType :: TypeInfo a -> PType -> TypeInfo a
setPType t pt = t {pType = pt}

setCType :: TypeInfo a -> CType a -> TypeInfo a
setCType t ct = t {cType = ct}

setDerivingHornClause :: TypeInfo a -> HornClause a -> TypeInfo a
setDerivingHornClause t dhc = t {derivingHornClause = Just dhc}

setWitnessedVars :: TypeInfo a-> WitnessedVars -> TypeInfo a
setWitnessedVars t wit = t {witnessedVars = wit}

setChainName:: TypeInfo a -> ChainName -> TypeInfo a
setChainName t name = t {chainName = name}

setTags:: TypeInfo a -> [Tag a] -> TypeInfo a
setTags t tgs = t {tags = tgs}

-- Because Env will be polluted by local symbols as we evaluate, we need to reset when calling functions.
-- Therefore, we define that all functions must exist in the global namespace.
-- That way, it is sufficient to carry only the global namespace as reset point.
-- local functions are in principle possible, but they need to carry their own environment with them,
-- e.g. by expanding Env to be of [(String, Env x a, Expr x a)], where [] indicates a shorthand for the global scope.
type Env x a = [(String, Expr x a)]
type Check a = ExceptT TypeError (Reader (Env () a))

data TypeError = Mismatch RType RType
               deriving (Show, Eq)

rIntersect :: RType -> RType -> Maybe RType
--here be all cases where types are "equal" but one is more strict
-- or where we can match unequal types anyway.
rIntersect l@(RConstraint _ _ retT) r@(RConstraint _ _ retT2) =
  if retT == retT2 && isJust sectType
  -- We need to worry about recursive Constraint types.
  then Just $ buildConstraints (getConstraints l ++ getConstraints r) $ fromJust sectType --Just $ RConstraint name constraint $ RConstraint name2 constraint2 retT2
  else Nothing
    where
      getFinal (RConstraint _ _ b) = getFinal b
      getFinal other = other
      getConstraints (RConstraint x y ys) = (x, y) : getConstraints ys
      getConstraints _ = []
      buildConstraints [] finalR = finalR
      buildConstraints ((a,b):cs) finalR = RConstraint a b (buildConstraints cs finalR)
      leftFinal = getFinal retT
      rightFinal = getFinal retT2
      sectType = rIntersect leftFinal rightFinal
rIntersect left (RConstraint name constraint retT) =
  if isNothing sectType
  then Nothing
  else Just $ RConstraint name constraint $ fromJust sectType
    where sectType = rIntersect left retT
rIntersect (RConstraint name constraint retT) right =
  if isNothing sectType
  then Nothing
  else Just $ RConstraint name constraint $ fromJust sectType
    where sectType = rIntersect right retT
--TODO: Validate the next two lines
rIntersect (RIdent name) t = Just $ RConstraint name t t
rIntersect t (RIdent name) = Just $ RConstraint name t t
rIntersect (ListOf x) NullList = Just $ ListOf x
rIntersect NullList (ListOf x) = Just $ ListOf x
rIntersect left right = if left == right then Just left else Nothing

matchRExpr :: (Show a) => Expr () a -> Expr () a -> Check a RType
matchRExpr e1 e2 = do
  e1R <- inferR e1
  e2R <- inferR e2
  matchRType e1R e2R

matchRType :: RType -> RType -> Check a RType
matchRType t1 t2 =
  if isNothing intersection
  then throwError $ Mismatch t1 t2
  else return $ fromJust intersection
    where intersection = rIntersect t1 t2

matchTwoReturnThird :: RType -> RType -> RType -> Check a RType
matchTwoReturnThird a b ret =
  if isNothing intersection
  then throwError $ Mismatch a b
  else return ret
    where intersection = rIntersect a b

--TODO: if Expr is Let_in or otherwise affects Env.
typeCheckExpr :: (Show a) => Env () a -> Expr () a -> Expr (TypeInfo a) a
typeCheckExpr env = tMap (mkTypeInfo2 env)

mkTypeInfo2 :: (Show a) => Env () a -> Expr () a -> TypeInfo a
mkTypeInfo2 env expr =
  case mkTypeInfo env expr of
    Left err -> error $ show err
    Right result -> result

mkTypeInfo :: (Show a) => Env () a -> Expr () a -> Either TypeError (TypeInfo a)
mkTypeInfo env expr =
  do
    pType <- runReader (runExceptT (inferP expr)) env
    rType <- runReader (runExceptT (inferR expr)) env
    return $ makeTypeInfo {rType = rType, pType = pType}

inferR :: (Show a) => Expr () a -> Check a RType
inferR (IfThenElse () cond left right) = do
  condR <- inferR cond
  ret <- matchRExpr left right
  matchTwoReturnThird condR TBool ret
  --if condR /= TBool
  --then throwError $ Mismatch condR TBool
  --else matchRExpr left right
inferR (GreaterThan () left right) = do
  e1R <- inferR left
  e2R <- inferR right
  matchTwoReturnThird e1R e2R TBool
  --if e1R /= e2R
  --then throwError $ Mismatch e1R e2R
  --else return TBool
inferR (ThetaI () a _) = return TFloat        -- TODO I don't know what this is for. Might6 be incorrect
inferR (Subtree () a _) = return TThetaTree
inferR (Uniform ()) = return TFloat
inferR (Normal ()) = return TFloat
inferR (Constant () val) = return $ getRType val
--inferR (Constant () (VFloat _)) = return TFloat
--inferR (Constant () (VBool _)) = return TBool
--inferR (Constant () (VList xs)) = return $ ListOf xs
inferR (MultF () e1 e2) = matchRExpr e1 e2
inferR (MultI () e1 e2) = matchRExpr e1 e2
inferR (PlusF () e1 e2) = matchRExpr e1 e2
inferR (PlusI () e1 e2) = matchRExpr e1 e2
inferR (Null ()) = return NullList
inferR (Cons () headX tailX) = do
  tHead <- inferR headX
  tTail <- inferR tailX
  case tTail of
    ListOf innerType -> liftM ListOf $ matchRType innerType tHead
    NullList -> return (ListOf tHead)
    _ -> matchRType tTail (ListOf tHead)
inferR (Call () name) = return $ RIdent name
inferR e = error $ "RType inference failed for: " ++ show e

--TODO: Find a way to statically align the result of inferP with the constraints of the likelihood function.
inferP :: (Show a) => Expr () a -> Check a PType
inferP (IfThenElse _ cond left right) = do
  condP <- inferP cond
  leftP <- inferP left
  rightP <- inferP right
  -- assumption: cond is always binomial - this should follow from typing rules.
  return $ downgrade condP $ downgrade leftP rightP
inferP (GreaterThan _ left right) = do
  leftP <- inferP left
  rightP <- inferP right
  return $ downgrade leftP rightP
inferP (ThetaI _ _ _) = return Deterministic
inferP (Subtree _ _ _) = return Deterministic
inferP (Constant _ _) = return Deterministic
inferP (Uniform _) = return Integrate
inferP (Normal _) = return Integrate
--Integer arithmetic omitted here
inferP (MultF _ left right) = do
  leftP <- inferP left
  rightP <- inferP right
  if upgrade leftP rightP == Deterministic
  then return $ downgrade leftP rightP
  -- we do not know how to integrate over a product
  else return Bottom
inferP (PlusF _ left right) = do
  leftP <- inferP left
  rightP <- inferP right
  if upgrade leftP rightP == Deterministic
  then return $ downgrade leftP rightP
  -- we do not know how to integrate over a sum
  else return Bottom
inferP (Null _) = return Deterministic
inferP (Cons _ headX tailX) = do
  -- TODO: Assumes independence. Invalid if there exists x elem Env that is used in head and tail.
  headP <- inferP headX
  tailP <- inferP tailX
  return $ downgrade headP tailP
--inferP (Call _ name) = return $ PIdent name [(Deterministic, Deterministic), (Integrate, Integrate), (Chaos, Chaos)]--TODO: here there be dragons
--inferP (LetIn _ name assignment inExpr) = inferP inExpr
--TODO: Arg needs to make sure the variable has proper type, same as let_in
--inferP (Arg _ name inExpr) = inferP inExpr
--inferP (CallArg _ name withExpr) = return $ PIdent name [(Deterministic, Deterministic), (Integrate, Integrate), (Chaos, Chaos)]
inferP e = error $ "PType inference failed for: " ++ show e


progToEnv :: Program (TypeInfo a) a -> Env (TypeInfo a) a
progToEnv (Program funcs main_expr) = ("main", main_expr): funcs

autoExpr :: (Eq a, Num a, Reifies s Tape) => Expr (TypeInfo a) a -> Expr (TypeInfo (Reverse s a)) (Reverse s a)
autoExpr e = tMap (autoTypeInfo . getTypeInfo) $ exprMap auto e

autoTypeInfo :: (Eq a, Num a, Reifies s Tape) =>TypeInfo a ->TypeInfo (Reverse s a)
autoTypeInfo t = t {tags = Prelude.map autoTag (tags t), cType = autoCType (cType t), derivingHornClause = do
  hc <- derivingHornClause t
  return (autoHornClause hc)}

autoHornClause :: (Eq a, Num a, Reifies s Tape) => HornClause a -> HornClause (Reverse s a)
autoHornClause (cn, hc, inv) =  (map (\(cn1, ct) -> (cn1, autoCType ct)) cn, map (\(cn1, ct) -> (cn1, autoCType ct)) hc, inv)

autoCType :: (Num a, Reifies s Tape) => CType a -> CType (Reverse s a)
autoCType (CConstrainedTo a b) = CConstrainedTo (auto a) (auto b)
autoCType CDeterministic = CDeterministic
autoCType CInferDeterministic = CInferDeterministic
autoCType CBottom = CBottom
autoCType CNotSetYet = CNotSetYet


autoTag :: (Num a, Reifies s Tape) => Tag a -> Tag (Reverse s a)
autoTag (EnumRange (a, b))= EnumRange (autoVal a, autoVal b)
autoTag (EnumList l) = EnumList (Prelude.map autoVal l)
autoTag (Alg a) = Alg a
autoTag _ = error "Failed to convert to auto tag"

autoEnv :: (Eq a, Num a, Reifies s Tape) => Env (TypeInfo a) a -> Env (TypeInfo (Reverse s a)) (Reverse s a)
autoEnv = Prelude.map (\ (name, expr) -> (name, autoExpr expr))

autoVal :: (Num a, Reifies s Tape) => Value a -> Value (Reverse s a)
autoVal (VBool x) = VBool x
autoVal (VFloat y) = VFloat (auto y)
autoVal (VList xs) = VList (Prelude.map autoVal xs)
autoVal (VTuple x1 x2) = VTuple (autoVal x1) (autoVal x2)
autoVal (VInt x) = VInt x
autoVal (VSymbol x) = VSymbol x
autoVal _ = error "Failed to convert to auto value"