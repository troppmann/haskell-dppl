module SPLL.Examples where

import SPLL.Lang

import SPLL.Typing.RType
import SPLL.Typing.PType

--weatherHask lastDay = if lastDay == rainy
--  then let current = randA in (current, weatherHask current)
--  else let current = randB in (current, weatherHask current)

paramExpr :: Expr () Float
paramExpr = Arg () "iterations" TFloat (IfThenElse ()
  (GreaterThan () (Call () "iterations") (Constant () (VFloat 0.5)))
  (Cons () (Constant () (VBool True)) (CallArg () "main" [Plus () (Call () "iterations") (Constant () (VFloat (-1.0)))]))
  (Null ()))

variableLength :: Expr () a
variableLength = IfThenElse ()
  (GreaterThan () (Uniform ()) (ThetaI () 0))
  (Null ())
  --(Cons () (Normal ()) (Call () "main"))
  (Cons () (Constant () (VBool True)) (Call () "main"))

testProg :: Program () a
testProg = Program [("main", ThetaI () 0), ("b", ThetaI () 1)]
             (Call () "main")
             
-- Mutual recursion 
testProgFix :: Program () a
testProgFix = Program [("main", IfThenElse ()
                                    (GreaterThan () (Uniform ()) (Call () "b"))
                                    (Null ())
                                    (Cons () (Constant () (VBool True)) (Call () "main"))),
                       ("b", ThetaI () 1)]
              (Call () "main")
varLenFix :: Expr () a
varLenFix = Fix () (Lambda () "main" (
  IfThenElse ()
    (GreaterThan () (Uniform ()) (ThetaI () 0))
    (Null ())
    (Cons () (Constant () (VBool True)) (Var () "main"))))
    
nullIf :: Expr () a
nullIf =  IfThenElse ()
    (GreaterThan () (Uniform ()) (ThetaI () 0))
    (Null ())
    (Cons () (GreaterThan () (Uniform ()) (ThetaI () 1)) 
    (Null ()))

--testExpr :: Num a => Expr a
testIf :: Expr () a
testIf = IfThenElse ()
  (GreaterThan () (Uniform ()) (ThetaI () 0))
  (Constant () (VBool True))
  (Constant () (VBool False))
  
testP :: Expr () a
testP = Uniform ()

testPlus :: Expr () a
testPlus = Plus () (Uniform ()) testPlus2

testPlus2 :: Expr () a
testPlus2 = Plus () (ThetaI () 0) (ThetaI () 0)

testGreater :: Expr () a
testGreater = GreaterThan () (Uniform ()) (ThetaI () 0)

testGreater2 :: Expr () a
testGreater2 = GreaterThan () (ThetaI () 0) (Uniform ())

testExpr2 :: Expr () a
testExpr2 = IfThenElse ()
  (GreaterThan () (Uniform ()) (ThetaI () 0))
  (Null ())
  (Cons () (Constant () (VBool True)) (Call () "main"))

testBool :: Expr () a
testBool = GreaterThan () (Uniform ()) (ThetaI () 0)

testGauss :: Expr () a
--testGauss = Plus () (Normal ()) (ThetaI () 0)
testGauss = Plus () (Mult () (Normal ()) (ThetaI () 0)) (ThetaI () 1)


--  (IfThenElse ()
--    (GreaterThan () (Uniform ()) (ThetaI () 1))
--    (Cons () (Constant () (VBool True)) (Call () "main"))
--    )

--testGauss = compile "Normal * theta[0] + theta[1]"

{--
MNIST_CNN_GEN :: Image -> Int (CNN yields distribution, we return sample)
e.g. [0 -> 0.5; 1 -> 0.3, 2 -> 0.2]; when sampling: return 0 with probability 0.5
     [0 -> 0.98; 1 -> 0.01, 2 -> 0.01]; when sampling: return 0 with probability 0.98
MNIST_CNN_Likelihood :: Image -> Int -> Float (index into distribution)
AutoDiff yields gradient for
MNIST_CNN:: Image -> Int (As Softmax over probabilities)
main =
  let
    x <- MNIST_CNN(imgA)
    y <- MNIST_CNN(imgB)
  in x + y

How do we train this? We get a result... 15 and imgA and imgB.
  MaxP(MNIST_CNN(imgA) = 6 && MNIST_CNN(imgB) = 9)
  MaxP(MNIST_CNN(imgA) = 7 && MNIST_CNN(imgB) = 8)
  MaxP(MNIST_CNN(imgA) = 8 && MNIST_CNN(imgB) = 7)
  MaxP(MNIST_CNN(imgA) = 9 && MNIST_CNN(imgB) = 6)

likelihood(imgA, imgB, N) = \sum{x,y | x+y=15} (imgA == x && imgB == y)

Maybe we can do Distributional MNist? (Assume for example we have a distribution of x-digit MNIST postal codes and samples from that distribution.
Assume we know the distribution, can we find the MNIST mapping?
 -}
testGaussianMixture :: Expr () a
testGaussianMixture = IfThenElse ()
  (GreaterThan () (Uniform ()) (ThetaI () 0))
  (Cons ()
    (Plus ()
      (Mult () (Normal ()) (ThetaI () 1))
      (ThetaI () 2))
    (Cons ()
      (Plus ()
        (Mult () (Normal ()) (ThetaI () 3))
        (ThetaI () 4))
      (Null ())))
  (Cons ()
    (Plus ()
      (Mult () (Normal ()) (ThetaI () 5))
      (ThetaI () 6))
    (Cons ()
      (Plus ()
        (Mult () (Normal ()) (ThetaI () 7))
        (ThetaI () 8))
      (Null ())))

gaussianMixture :: Expr () a
gaussianMixture = IfThenElse ()
  (GreaterThan () (Uniform ()) (ThetaI () 0))
  (Cons ()
    (Plus ()
      (Mult () (Normal ()) (ThetaI () 1))
      (ThetaI () 2))
    (Cons ()
      (Plus ()
        (Mult () (Normal ()) (ThetaI () 3))
        (ThetaI () 4))
      (Cons ()
        (Constant () (VBool True))
        (Null ()))))
  (Cons ()
    (Plus ()
      (Mult () (Normal ()) (ThetaI () 5))
      (ThetaI () 6))
    (Cons ()
      (Plus ()
        (Mult () (Normal ()) (ThetaI () 7))
        (ThetaI () 8))
      (Cons ()
        (Constant () (VBool True))
        (Null ()))))

testIntractable :: Expr () a
testIntractable = Mult ()
  (Mult () (Normal ()) (ThetaI () 1))
  (Mult () (Normal ()) (ThetaI () 2))

testInconsistent :: Expr () Double
testInconsistent = IfThenElse ()
  (GreaterThan () (Constant () (VFloat 0.0)) (ThetaI () 0))
  (Constant () (VBool True))
  (Constant () (VBool False))

failureCase :: Expr () a
failureCase = Mult () (Normal ()) (ThetaI () 0)

gaussLists :: Expr () a
gaussLists = IfThenElse ()
  (GreaterThan () (Uniform ()) (ThetaI () 0))
  (Null ())
  (Cons () (Plus () (Mult () (Normal ()) (ThetaI () 1)) (ThetaI () 2)) (Call () "main"))
  
gaussMultiLists :: Expr () a
gaussMultiLists = IfThenElse ()
  (GreaterThan () (Uniform ()) (ThetaI () 0) )
  (Null ())
  (Cons ()
    (IfThenElse ()
      (GreaterThan () (Uniform ()) (ThetaI () 1))
      (Plus () (Mult () (Normal ()) (ThetaI () 2)) (ThetaI () 3))
      (Plus () (Mult () (Normal ()) (ThetaI () 4)) (ThetaI () 5)))
    (Call () "main"))

-- typeinfer :: Expr () a -> Expr RType a
-- typeInferMaybe :: Expr (Maybe RType) a -> Expr RType a

testNNUntyped :: Expr () a
--testNN : Lambda im1 -> (Lambda im2 -> readNN im1 + readNN im2)
testNNUntyped = Lambda () "im1" (Lambda () "im2" (Plus () (ReadNN () "classifyMNist" (Var () "im1")) (ReadNN () "classifyMNist" (Var () "im2"))))

testNN :: Expr TypeInfo a
testNN = Lambda (TypeInfo (Arrow TSymbol (Arrow TSymbol TInt)) Chaos) "im1"
  (Lambda (TypeInfo (Arrow TSymbol TInt) Chaos) "im2" (Plus (TypeInfo TInt Integrate)
    (ReadNN (TypeInfo TInt Integrate) "classifyMNist" (Var (TypeInfo TSymbol Deterministic) "im1"))
    (ReadNN (TypeInfo TInt Integrate) "classifyMNist" (Var (TypeInfo TSymbol Deterministic) "im2"))))
    

mNistNoise :: Expr TypeInfo a
mNistNoise = Lambda (TypeInfo (Arrow TSymbol (Arrow TSymbol TInt)) Chaos) "im1"
  (Lambda (TypeInfo (Arrow TSymbol TInt) Chaos) "im2"
    (IfThenElse (TypeInfo TInt Integrate) (GreaterThan (TypeInfo TBool Integrate) (Uniform (TypeInfo TFloat Integrate)) (ThetaI (TypeInfo TFloat Deterministic) 0) )
    (Plus (TypeInfo TInt Integrate)
      (Constant (TypeInfo TInt Deterministic) (VInt 1))
      (Plus (TypeInfo TInt Integrate)
            (ReadNN (TypeInfo TInt Integrate) "classifyMNist" (Var (TypeInfo TSymbol Deterministic) "im1"))
            (ReadNN (TypeInfo TInt Integrate) "classifyMNist" (Var (TypeInfo TSymbol Deterministic) "im2"))))
    (Plus (TypeInfo TInt Integrate)
      (ReadNN (TypeInfo TInt Integrate) "classifyMNist" (Var (TypeInfo TSymbol Deterministic) "im1"))
      (ReadNN (TypeInfo TInt Integrate) "classifyMNist" (Var (TypeInfo TSymbol Deterministic) "im2")))))

triMNist :: Expr TypeInfo a
triMNist = Lambda (TypeInfo (Arrow TSymbol (Arrow TSymbol (Arrow TSymbol TInt))) Chaos) "im1"
  (Lambda (TypeInfo (Arrow TSymbol (Arrow TSymbol TInt)) Chaos) "im2"
    (Lambda (TypeInfo (Arrow TSymbol TInt) Chaos) "im3" (Plus (TypeInfo TInt Integrate)
      (ReadNN (TypeInfo TInt Integrate) "classifyMNist" (Var (TypeInfo TSymbol Deterministic) "im3"))
      (Plus (TypeInfo TInt Integrate)
        (ReadNN (TypeInfo TInt Integrate) "classifyMNist" (Var (TypeInfo TSymbol Deterministic) "im1"))
        (ReadNN (TypeInfo TInt Integrate) "classifyMNist" (Var (TypeInfo TSymbol Deterministic) "im2")))
      )))

expertModels :: Expr () a
expertModels = Lambda () "im" (IfThenElse ()
  (ReadNN () "isMnist" (Var () "im"))
  (ReadNN () "classifyMNist" (Var () "im"))
  (ReadNN () "classifyCIFAR" (Var () "im")))
  
expertModelsTyped :: Expr TypeInfo a
expertModelsTyped = Lambda (TypeInfo (Arrow TSymbol TInt) Integrate) "im" (IfThenElse (TypeInfo TInt Integrate)
  (ReadNN (TypeInfo TBool Integrate) "isMnist" (Var (TypeInfo TSymbol Deterministic) "im"))
  (ReadNN (TypeInfo TInt Integrate) "classifyMNist" (Var (TypeInfo TSymbol Deterministic) "im"))
  (ReadNN (TypeInfo TInt Integrate) "classifyCIFAR" (Var (TypeInfo TSymbol Deterministic) "im")))

--expert_model_proofs image =
--  if isMNist
--    then (1, classifyMNist image)
--    else (2, classifyCIFAR image)

--expert_model image =
--  if is28x28x1 image
--    then classifyMNist image
--    else classifyCIFAR image

