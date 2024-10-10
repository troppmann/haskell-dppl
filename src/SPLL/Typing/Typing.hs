{-# OPTIONS_GHC -fwarn-incomplete-patterns #-}
{-# LANGUAGE FlexibleContexts #-}

module SPLL.Typing.Typing (
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
  autoVal,
  autoExpr
)where

import SPLL.Lang.Types
import SPLL.Lang.Lang
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

data TypeError = Mismatch RType RType
               deriving (Show, Eq)

autoProg :: (Eq a, Num a, Reifies s Tape) => Program a -> Program (Reverse s a)
autoProg p = Program (map (\(n, f) -> (n, autoExpr f)) (functions p)) (map autoNeuralDecl (neurals p))

autoExpr :: (Eq a, Num a, Reifies s Tape) => Expr a -> Expr (Reverse s a)
autoExpr e = exprMap auto e

autoNeuralDecl :: (Eq a, Num a, Reifies s Tape) => NeuralDecl a -> NeuralDecl (Reverse s a)
autoNeuralDecl (n, rt, t) = (n, rt, autoTag t)

--TODO: Maybe we should genericize this to be (a -> b) -> TI a -> TI b
autoTypeInfo :: (Eq a, Num a, Reifies s Tape) =>TypeInfo a -> TypeInfo (Reverse s a)
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


autoVal :: (Num a, Reifies s Tape) => Value a -> Value (Reverse s a)
autoVal (VBool x) = VBool x
autoVal (VFloat y) = VFloat (auto y)
autoVal (VList xs) = VList (Prelude.map autoVal xs)
autoVal (VTuple x1 x2) = VTuple (autoVal x1) (autoVal x2)
autoVal (VInt x) = VInt x
autoVal (VSymbol x) = VSymbol x
autoVal _ = error "Failed to convert to auto value"