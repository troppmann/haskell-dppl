module PredefinedFunctions (
globalFenv,
getHornClause,
FPair(..),
FDecl(..),
FEnv
) where

import SPLL.Typing.RType (RType(..))
import SPLL.IntermediateRepresentation (IRExpr, IRExpr(..), Operand(..)) --FIXME
import SPLL.Lang.Lang
import SPLL.Typing.Typing
import Data.Set (fromList)
import Data.Maybe (fromJust)

-- InputVars, OutputVars, fwd, grad
newtype FDecl a = FDecl (RType, [String], [String], IRExpr a, [(String, IRExpr a)])
-- Forward, inverse
newtype FPair a = FPair (FDecl a, [FDecl a])
type FEnv a = [(String, FPair a)]

doubleFwd :: (Floating a) => FDecl a
doubleFwd = FDecl (TArrow TFloat TFloat, ["a"], ["b"], IROp OpMult (IRVar "a") (IRConst $ VFloat 2) , [("a", IRConst $ VFloat 2)])

doubleInv :: (Floating a) => FDecl a
doubleInv = FDecl (TArrow TFloat TFloat, ["b"], ["a"], IROp OpDiv (IRVar "b") (IRConst $ VFloat 2) , [("b", IRConst $ VFloat 0.5)])

globalFenv :: (Floating a) => FEnv a
globalFenv = [("double", FPair (doubleFwd, [doubleInv]))]

getHornClause :: (Eq a, Floating a) => Expr a -> [HornClause a]
getHornClause e = case e of
  InjF t name params -> (constructHornClause subst eFwd): map (constructHornClause subst) eInv
    where
      subst = (outV, eCN):zip inV (getInputChainNames e)
      eCN = chainName $ getTypeInfo e
      FDecl (_, inV, [outV], _, _) = eFwd
      Just (FPair (eFwd, eInv)) = lookup name globalFenv
  _ -> error "Cannot get horn clause of non-predefined function"

constructHornClause :: (Eq a) => [(String, ChainName)] -> FDecl a -> HornClause a
constructHornClause subst decl = (map lookUpSubstAddDet inV, map lookUpSubstAddDet outV, (StubInjF, 0)) --FIXME correct inversion parameters 
  where
    FDecl (_, inV, outV, _, _) = decl
    lookupSubst v = fromJust (lookup v subst)
    lookUpSubstAddDet v = (lookupSubst v, CInferDeterministic)


getInputChainNames :: Expr a -> [ChainName]
getInputChainNames e = map (chainName . getTypeInfo) (getSubExprs e)