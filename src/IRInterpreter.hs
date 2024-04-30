module IRInterpreter where
  
import Statistics.Distribution (ContGen, genContVar, quantile, density)
import SPLL.IntermediateRepresentation (IRExpr(..), Operand(..), UnaryOperand(..), Distribution(..), Distribution)
import SPLL.Lang (Value(..), Value)

import Control.Monad.Random
import Statistics.Distribution.Normal (normalDistr)
import Debug.Trace (trace)

type IRThetas a = [a]
type IREnv a = [(String, IRExpr a)]

generate :: (Ord a, Fractional a, Show a, Eq a, Floating a, RandomGen g, Random a) => IREnv a -> IREnv a -> IRThetas a -> [IRExpr a]-> IRExpr a -> Rand g (Value a)
generate globalEnv env thetas args expr | trace (show expr) False = undefined
generate globalEnv env thetas args (IRIf cond thenCase elseCase) = do
  condVal <- generate globalEnv env thetas args cond
  case condVal of
    VBool True -> generate globalEnv env thetas args thenCase
    VBool False -> generate globalEnv env thetas args elseCase
    _ -> error "Type error: Condition is not a boolean"
generate globalEnv env thetas args (IROp OpPlus a b) = do
  aVal <- generate globalEnv env thetas args a
  bVal <- generate globalEnv env thetas args b
  case (aVal, bVal) of
    (VFloat af, VFloat bf) -> return $ VFloat (af + bf)
    (VInt af, VInt bf) -> return $ VInt (af + bf)
    _ -> error "Type error: Plus can only add up numbers (of the same type)"
generate globalEnv env thetas args (IROp OpMult a b) = do
  aVal <- generate globalEnv env thetas args a
  bVal <- generate globalEnv env thetas args b
  case (aVal, bVal) of
    (VFloat af, VFloat bf) -> return $ VFloat (af * bf)
    (VInt af, VInt bf) -> return $ VInt (af * bf)
    _ -> error "Type error: ;ult can only multiply numbers (of the same type)"
generate globalEnv env thetas args (IROp OpGreaterThan a b) = do
  aVal <- generate globalEnv env thetas args a
  bVal <- generate globalEnv env thetas args b
  case (aVal, bVal) of
      (VFloat af, VFloat bf) -> return $ VBool (af > bf)
      (VInt af, VInt bf) -> return $ VBool (af > bf)
      _ -> error "Type error: greater than can only compare two numbers (of the same type)"
generate globalEnv env thetas args (IROp OpDiv a b) = do
  aVal <- generate globalEnv env thetas args a
  bVal <- generate globalEnv env thetas args b
  case (aVal, bVal) of
      (VFloat af, VFloat bf) -> return $ VFloat (af / bf)
      --(VInt af, VInt bf) -> return $ VFloat (af / bf)
      _ -> error "Type error: Divide can only divide two numbers (of the same type)"
generate globalEnv env thetas args (IROp OpSub a b) = do
  aVal <- generate globalEnv env thetas args a
  bVal <- generate globalEnv env thetas args b
  case (aVal, bVal) of
      (VFloat af, VFloat bf) -> return $ VFloat (af - bf)
      (VInt af, VInt bf) -> return $ VInt (af - bf)
      _ -> error "Type error: Minus can only subtract two numbers (of the same type)"
generate globalEnv env thetas args (IROp OpOr a b) = do
  aVal <- generate globalEnv env thetas args a
  bVal <- generate globalEnv env thetas args b
  case (aVal, bVal) of
        (VBool af, VBool bf) -> return $ VBool (af || bf)
        _ -> error "Type error: Or can only evaluate on two booleans"
generate globalEnv env thetas args (IROp OpEq a b) = do
  aVal <- generate globalEnv env thetas args a
  bVal <- generate globalEnv env thetas args b
  case (aVal, bVal) of
    (VBool af, VBool bf) -> return $ VBool (af == bf)
    (VFloat af, VFloat bf) -> return $ VBool (af == bf)
    (VInt af, VInt bf) -> return $ VBool (af == bf)
    _ -> error "Type error: Equals can only evaluate on two values"
generate globalEnv env thetas args (IRUnaryOp OpNot a) = do
  aVal <- generate globalEnv env thetas args a
  case aVal of
    VBool af -> return $ VBool (not af)
    _ -> error "Type error: Not can only evaluate on a Bool"
generate globalEnv env thetas args (IRUnaryOp OpNeg a) = do
  aVal <- generate globalEnv env thetas args a
  case aVal of
    VFloat af -> return $ VFloat (-af)
    VInt af -> return $ VInt (-af)
    _ -> error "Type error: Neg can only evaluate on a number"
generate globalEnv env thetas args (IRUnaryOp OpAbs a) = do
  aVal <- generate globalEnv env thetas args a
  case aVal of
    VFloat af -> return $ VFloat (abs af)
    VInt af -> return $ VInt (abs af)
    _ -> error "Type error: Abs can only evaluate on a number"
generate globalEnv env thetas args (IRTheta i) = return $ VFloat $ thetas!!i
generate globalEnv env thetas args (IRConst val) = return val
generate globalEnv env thetas args (IRCons hd tl) = do
  ls <- generate globalEnv env thetas args tl
  case ls of
    VList xs -> do
      x <- generate globalEnv env thetas args hd
      return $ VList (x : xs)
    _ -> error "Type error: Tail of cons is not a list"
generate globalEnv env thetas args (IRHead listExpr) = do
  listVal <- generate globalEnv env thetas args listExpr
  case listVal of 
    VList (a:_) -> return a
    _ -> error "Type error: head must be called on a non-empty list"
generate globalEnv env thetas args (IRTail listExpr) = do
  listVal <- generate globalEnv env thetas args listExpr
  case listVal of
    VList (_:a) -> return $ VList a
    _ -> error "Type error: tail must be called on a non-empty list"
generate globalEnv env thetas args (IRDensity dist expr) = do
  x <- generate globalEnv env thetas args expr
  irPDF dist x
generate globalEnv env thetas args (IRSample dist) = 
  case dist of
    IRUniform -> do
      r <- getRandomR (0.0, 1.0) --uniformR (0.0, 1.0)
      return $ VFloat r
    IRNormal -> do
      let gauss = normalDistr 0 1
      r <- getRandomR (0.0, 1.0)
      let result = quantile gauss r
      return $ VFloat $ realToFrac result
-- Let in evaluates the declaration expression to avoid sampling the same term multiple times
generate globalEnv env thetas args (IRLetIn name decl body) = do
  declVal <- generate globalEnv env thetas args decl
  let extendedEnv = (name, IRConst declVal):env
  generate globalEnv extendedEnv thetas args body
generate globalEnv env thetas args (IRVar name) = generate globalEnv env thetas args expr
  where Just expr = lookup name env
generate globalEnv env thetas args (IRCall name callArgs) = generate globalEnv globalEnv thetas args expr
  where Just expr = lookup name globalEnv
generate globalEnv env thetas (arg:args) (IRLambda name expr) = generate globalEnv ((name, arg):env) thetas args expr
generate globalEnv env thetas [] (IRLambda name expr) = error "No args provided to lambda"
--TODO: Fehler bei args für nicht lambda
generate globalEnv env thetas args (IREnumSum varname val expr) = error "Not yet implemented"  --TODO
generate globalEnv env thetas args (IREvalNN varname expr) = error "EvalNN cannot be interpreted on the IR. Please use PyTorch or Julia" --TODO
generate globalEnv env thetas args (IRIndex expr index) = error "Not yet implemented"  --TODO
generate globalEnv env thetas args (IRReturning expr) = error "Not yet implemented"  --TODO

irPDF :: (Ord a, Fractional a, Show a, Eq a, Floating a, Random a) => Distribution -> Value a -> Rand g (Value a)
irPDF IRUniform (VFloat x) = if x >= 0 && x <= 1 then return $ VFloat 1 else return $ VFloat 0
irPDF IRNormal (VFloat x) = return $ VFloat ((1 / sqrt (2 * pi)) * exp (-0.5 * x * x))
irPDF expr _ = error "Expression must be the density of a valid distribution"
  
  