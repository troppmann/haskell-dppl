module SPLL.Transpiler where

import SPLL.Lang
import SPLL.Typing.PType
import Data.Graph
import SPLL.Typing.Typing
import SPLL.InferenceRule

data Annotation a = IIndex Int
                | IIdentifier String
                | IValue (Value a)
                deriving (Show)

data IRNode a = Simple ExprStub [Annotation a]
              | Complex InferenceRule
              deriving (Show)

type IRDefinition a = (String, Tree (IRNode a))

transpile :: Env TypeInfo a -> [IRDefinition a]
transpile = map transpileDefinition

transpileDefinition :: (String, Expr TypeInfo a) -> IRDefinition a
transpileDefinition (name, expression) = (name, transpileExpr expression)

-- OK, static analysis is amazing and just converted this lambda
-- (\alg -> and (map (\constr -> checkConstraint expr constr) (constraints alg) ) )
-- via this
-- (\alg -> all (checkConstraint expr) (constraints alg) )
-- into this
-- (all (checkConstraint expr) . constraints )

transpileExpr :: Expr TypeInfo a -> Tree (IRNode a)
transpileExpr expr = if likelihoodFunctionUsesTypeInfo $ toStub expr
  then case filter (\alg -> all (checkConstraint expr alg) (constraints alg) ) correctExpr of
    [alg] -> Node (Complex alg) (map transpileExpr $ getSubExprs expr)
    [] -> error ("no algorithm found in transpiler in Expression " ++ (show $ toStub expr))
    algs -> error ("ambiguous algorithms in transpiler: " ++ show (map algName algs))
  else Node (Simple (toStub expr) (annotate expr)) (map transpileExpr $ getSubExprs expr)
  where
      correctExpr = filter (checkExprMatches expr) allAlgorithms

annotate :: Expr TypeInfo a -> [Annotation a]
annotate expr = case expr of 
  ThetaI _ i    -> [IIndex i]
  Constant _ x  -> [IValue x]
  Call _ x      -> [IIdentifier x]
  LetIn _ x _ _ -> [IIdentifier x]
  Arg _ x _ _   -> [IIdentifier x]
  CallArg _ x _ -> [IIdentifier x]
  Lambda _ x _  -> [IIdentifier x]
  _             -> []

checkExprMatches :: Expr TypeInfo a -> InferenceRule -> Bool
checkExprMatches e alg = toStub e == forExpression alg

checkConstraint :: Expr TypeInfo a -> InferenceRule -> Constraint -> Bool
checkConstraint expr _ (SubExprNIsType n ptype) = ptype == p
  where TypeInfo r p = getTypeInfo (getSubExprs expr !! n)
checkConstraint expr _ (SubExprNIsNotType n ptype) = ptype /= p
  where TypeInfo r p = getTypeInfo (getSubExprs expr !! n)
checkConstraint expr alg ResultingTypeMatch = resPType == annotatedType
  where
    annotatedType = getP expr
    resPType = resultingType alg (map getP (getSubExprs expr))

arity :: ExprStub -> Int
arity = undefined

likelihoodFunctionUsesTypeInfo :: ExprStub -> Bool
likelihoodFunctionUsesTypeInfo expr = expr `elem` [StubGreaterThan, StubMultF, StubMultI, StubPlusF, StubPlusI]

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
  (Null _)       -> StubNull
  Cons {}        -> StubCons
  (Call _ _)     -> StubCall
  (Var _ _)      -> StubVar
  LetIn {}       -> StubLetIn
  Arg {}         -> StubArg
  CallArg {}     -> StubCallArg
  Lambda {}      -> StubLambda
  (ReadNN _ _ _) -> StubReadNN
  
