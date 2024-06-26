{-# LANGUAGE OverloadedStrings #-}

module SPLL.InferenceRule (
  InferenceRule(..)
, RuleConstraint(..)
, ExprStub(..)
, toStub
, allAlgorithms
, checkExprMatches
) where

import SPLL.Typing.PType hiding (TV, NotSetYet)
import Data.List (isInfixOf, isSuffixOf)
import SPLL.Lang (Expr(..))
import SPLL.Typing.RType

data ExprStub = StubIfThenElse
              | StubGreaterThan
              | StubThetaI
              | StubUniform
              | StubNormal
              | StubConstant
              | StubMultF
              | StubMultI
              | StubPlusF
              | StubPlusI
              | StubNegF
              | StubExpF
              | StubNull
              | StubCons
              | StubTCons
              | StubCall
              | StubVar
              | StubLetIn
              | StubArg
              | StubInjF
              | StubCallArg
              | StubLambda
              | StubReadNN
              deriving (Show, Eq)

toStub :: Expr x a -> ExprStub
toStub expr = case expr of
  IfThenElse {}  -> StubIfThenElse
  GreaterThan {} -> StubGreaterThan
  (ThetaI _ _)   -> StubThetaI
  (Uniform _)    -> StubUniform
  (Normal _)     -> StubNormal
  (Constant _ _) -> StubConstant
  MultF {}       -> StubMultF
  MultI {}       -> StubMultI
  PlusF {}       -> StubPlusF
  PlusI {}       -> StubPlusI
  ExpF {}        -> StubExpF
  NegF {}        -> StubNegF
  (Null _)       -> StubNull
  Cons {}        -> StubCons
  TCons {}       -> StubTCons
  (Call _ _)     -> StubCall
  (Var _ _)      -> StubVar
  LetIn {}       -> StubLetIn
  Arg {}         -> StubArg
  InjF {}        -> StubInjF
  CallArg {}     -> StubCallArg
  Lambda {}      -> StubLambda
  (ReadNN _ _ _) -> StubReadNN

data RuleConstraint = SubExprNIsType Int PType
                    | SubExprNIsNotType Int PType
                    | SubExprNIsAtLeast Int PType
                    | ResultingTypeMatch
                    deriving Show

-- can we encode symmetries?
data InferenceRule = InferenceRule { forExpression :: ExprStub
                                   , constraints :: [RuleConstraint]
                                   , algName :: String
                                   --apply all subexpr PTypes to find PType
                                   , resultingPType :: [PType] -> PType
                                   , assumedRType :: Scheme
                                   }

instance Show InferenceRule where
  show (InferenceRule _ _ name _ _) = name

instance Eq InferenceRule where
  a1 == a2 = algName a1 == algName a2

checkExprMatches :: Expr x a -> InferenceRule -> Bool
checkExprMatches e alg = toStub e == forExpression alg


--mirror the constraints and the ptype of a 2-arg function.
mirror2 :: InferenceRule -> InferenceRule
mirror2 (InferenceRule stub constrs name pty rty) = InferenceRule stub (map mirrorC constrs) (mirrorN name) (mirrorPty pty) rty

mirrorN :: String -> String
mirrorN name
  | "Left"  `isSuffixOf` name = take (length name - 4) name ++ "Right"
  | "Right" `isSuffixOf` name = take (length name - 5) name ++ "Left"
  | otherwise = name ++ "'"

mirrorPty :: ([PType] -> PType) -> ([PType] -> PType)
mirrorPty function subexprTypes = function (reverse subexprTypes)

mirrorC :: RuleConstraint -> RuleConstraint
mirrorC ResultingTypeMatch = ResultingTypeMatch
mirrorC (SubExprNIsNotType 0 a) = SubExprNIsNotType 1 a
mirrorC (SubExprNIsNotType 1 a) = SubExprNIsNotType 0 a
mirrorC (SubExprNIsType 0 a) = SubExprNIsType 1 a
mirrorC (SubExprNIsType 1 a) = SubExprNIsType 0 a
mirrorC c = error ("can not mirror Constraint: " ++ show c)

greaterThanLeft :: InferenceRule
greaterThanLeft = InferenceRule
                    StubGreaterThan
                    [SubExprNIsType 0 Deterministic]
                    "greaterThanLeft"
                    (const Integrate)
                    (Forall [] (TFloat `TArrow` (TFloat `TArrow` TBool)))

greaterThanRight :: InferenceRule
greaterThanRight = mirror2 greaterThanLeft --InferenceRule StubGreaterThan [SubExprNIsType 1 Deterministic] "greaterThanRight" (const Integrate)

greaterThanSigmoid :: InferenceRule
greaterThanSigmoid = InferenceRule
                       StubGreaterThan
                       [SubExprNIsType 0 Deterministic, SubExprNIsType 1 Deterministic]
                       "greaterThanSigmoid"
                       (const Integrate)
                       (Forall [] (TFloat `TArrow` (TFloat `TArrow` TBool)))

--TODO: Lacking implementation of invertible arithmetic on Integers.
plusLeft :: InferenceRule
plusLeft = InferenceRule
             StubPlusF
             [SubExprNIsType 0 Deterministic]
             "plusLeft"
             mostChaotic
             (Forall [] (TFloat `TArrow` (TFloat `TArrow` TFloat)))

plusRight :: InferenceRule
plusRight = mirror2 plusLeft
-- = InferenceRule StubPlusF [SubExprNIsType 1 Deterministic] "plusRight" mostChaotic

multLeft :: InferenceRule
multLeft = InferenceRule
             StubMultF
             [SubExprNIsType 0 Deterministic]
             "multLeft"
             mostChaotic
             (Forall [] (TFloat `TArrow` (TFloat `TArrow` TFloat)))

multRight :: InferenceRule
multRight = mirror2 multLeft
--multRight = InferenceRule StubMultF [SubExprNIsType 1 Deterministic] "multRight" mostChaotic

expF :: InferenceRule
expF = InferenceRule
          StubNegF
          []
          "negF"
          mostChaotic
          (Forall [] (TFloat `TArrow` TFloat))

negF :: InferenceRule
negF = InferenceRule
          StubNegF
          []
          "negF"
          mostChaotic
          (Forall [] (TFloat `TArrow` TFloat))

enumeratePlusLeft :: InferenceRule
--TODO: Introduce a new type for intractable results? Does that expand the lattice into a 2d configuration?
enumeratePlusLeft = InferenceRule
                      StubPlusI
                      [SubExprNIsNotType 0 Deterministic, SubExprNIsNotType 1 Deterministic]
                      "enumeratePlusLeft"
                      (const Prob)
                      (Forall [] (TInt `TArrow` (TInt `TArrow` TInt)))

ifThenElse :: InferenceRule
ifThenElse = InferenceRule
               StubIfThenElse
               [SubExprNIsAtLeast 0 Integrate]
               "ifThenElse"
               (\[_, a, b] -> mostChaotic [a,b])
               (Forall [TV "a"] (TBool `TArrow` (TVarR (TV "a") `TArrow` (TVarR (TV "a") `TArrow` TVarR (TV "a")))))

theta :: InferenceRule
theta = InferenceRule
          StubThetaI
          []
          "theta"
          (const Deterministic)
          (Forall [] TFloat)

uniform :: InferenceRule
uniform = InferenceRule
            StubUniform
            []
            "uniform"
            (const Integrate)
            (Forall [] TFloat)

normal :: InferenceRule
normal = InferenceRule
           StubNormal
           []
           "normal"
           (const Integrate)
           (Forall [] TFloat)

constant :: InferenceRule
constant = InferenceRule
             StubConstant
             []
             "constant"
             (const Deterministic)
             (Forall [] NotSetYet)

exprNull :: InferenceRule
exprNull = InferenceRule
             StubNull
             []
             "null"
             (const Deterministic)
             (Forall [TV "a"] (ListOf $ TVarR $ TV "a"))

cons :: InferenceRule
cons = InferenceRule
         StubCons
         []
         "cons"
         (mostChaotic . (Prob:))
         (Forall [TV "a"] ((TVarR $ TV "a") `TArrow` ((ListOf $ TVarR $ TV "a") `TArrow` (ListOf $ TVarR $ TV "a"))))

allAlgorithms :: [InferenceRule]
allAlgorithms = [ifThenElse, theta, uniform, normal, constant, exprNull, greaterThanLeft, greaterThanRight, greaterThanSigmoid, plusLeft, plusRight, multLeft, multRight, negF, expF, enumeratePlusLeft]
