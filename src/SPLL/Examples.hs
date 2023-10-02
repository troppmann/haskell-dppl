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

uniformProg :: Program () a
uniformProg = Program [] (Uniform ())
normalProg :: Program () a
normalProg = Program [] (Normal ())
uniformProgPlus :: Program () Double
uniformProgPlus = Program [] (Mult () (Uniform ()) (Constant () (VFloat (-0.5))))

flipCoin :: Expr () Double
flipCoin = GreaterThan () (Uniform ()) (Constant () (VFloat 0.5))
variableLength :: Expr () a
variableLength = IfThenElse ()
  (GreaterThan () (Uniform ()) (ThetaI () 0))
  (Null ())
  --(Cons () (Normal ()) (Call () "main"))
  (Cons () (Constant () (VBool True)) (Call () "b"))

testProg :: Program () a
testProg = Program [("b", variableLength)]
             (Call () "b")

testProgFix :: Program () Float
testProgFix = Program [
                        ("main", IfThenElse ()
                                    (GreaterThan () (Uniform ())(ThetaI () 1))
                                    (Call () "term")
                                    (Plus () (ThetaI () 1) (Call () "main"))),
                       ("b", ThetaI () 1),
                       ("term", IfThenElse ()
                           (GreaterThan () (Call () "b")(ThetaI () 1))
                           (Constant () (VFloat 0.0))
                           (Plus () (ThetaI () 1) (Call () "term")))]
              (Call () "main")
testCoin :: Program () Double
testCoin = Program [
                      ("f", IfThenElse ()
                                  (GreaterThan () (Uniform ()) (Call () "b"))
                                  (Null ())
                                  (Cons () flipCoin (Call () "f"))),
                     ("b", ThetaI () 0)
                     ]
              (Call () "f")
dummyExpr :: Program () a
dummyExpr = Program [("main", GreaterThan () (Uniform ()) (Call () "b")),
                                   ("b", ThetaI () 1)]
                          (Call () "main")
maybeAdd :: Program () Float
maybeAdd = Program [("maybeAddOne", IfThenElse ()
                                (GreaterThan () (Uniform ()) (ThetaI () 0))
                                (Constant () (VFloat 0.0))
                                (Plus () (Constant () (VFloat 1.0)) (Call () "maybeAddTwo"))),
                   ("maybeAddTwo", IfThenElse ()
                               (GreaterThan () (Uniform ()) (ThetaI () 1))
                               (Constant () (VFloat 0.0))
                               (Plus () (Constant () (VFloat 2.0)) (Call () "maybeAddOne")))]
                          (Call () "maybeAddOne")
nullIf :: Expr () a
nullIf =  IfThenElse ()
    (GreaterThan () (Uniform ()) (ThetaI () 0))
    (Null ())
    (Cons () (GreaterThan () (Uniform ()) (ThetaI () 1)) 
    (Null ()))

--testExpr :: Num a => Expr a
testIf :: Expr () Float
testIf = IfThenElse ()
  (GreaterThan () (Uniform ()) (ThetaI () 0))
  (Constant () (VBool True))
  (Constant () (VBool False))

--TODO Make params like Constant values (change to a type variable dynamically how?)
testLet2 :: Program () a
testLet2 = Program [](LetIn () "x"
                      (Plus () (ThetaI () 0) (Normal ()))
                      (InjF () "sig" [] (InjF () "mult" [ThetaI () 1]  (Var () "x"))))
-- let x = theta1 + normal in theta2 + sig(x) + theta3 * normal
-- let x = theta2 + sig(theta1 + normal) + theta3 * normal
-- theta1 = 0.1 theta2 = 0.8 
-- sample 1.9 -> x? sig(x) = 1.1 --> invert(sig = 1.1) = NaN
-- theta2 = 0.2
testLetNonInvert :: Program () Double
testLetNonInvert = Program [] (LetIn () "x" (Plus () (ThetaI () 0) (Normal ()))
          (Plus () (InjF () "sig" [] (Var () "x")) (ThetaI () 1)))
          
testLetPot :: Program () Double
testLetPot = Program [] (LetIn () "x" (Plus () (ThetaI () 0) (Normal ())) (InjF () "mult" [ThetaI () 1] (Var () "x")))
testList :: Program () Double
testList = Program [] (Cons () (Plus () (ThetaI () 0) (Normal ())) (Cons () (Normal ()) (Null ())))

-- If theta0 >= uniform then (True, normal) else (False, theta1 + normal)
testTuple :: Program () Double
testTuple = Program [] (IfThenElse () (GreaterThan () (Uniform ()) (ThetaI () 0))
          (TCons () (Constant () (VBool True)) (TCons () (Normal ()) (TNull ())))
          (TCons () (Constant () (VBool False)) (TCons () (Plus () (Normal ()) (ThetaI () 1)) (TNull ())))
          )
testInjFNot :: Program () Double
testInjFNot  = Program [] (IfThenElse () (InjF () "not" [] (GreaterThan () (ThetaI () 0)(Uniform ())))
                            (Normal ()) 
                            (InjF () "plus" [ThetaI () 1] (Normal ())))
testListPlus :: Program () Double
testListPlus  = Program [] (InjF () "listMult" 
    [Cons () (ThetaI () 0) (Cons () (ThetaI () 1) (Null ()))] 
    (Cons () (Plus () (Normal ()) (Constant () (VFloat 2.0)))
     (Cons () (Plus () (Normal ()) (Constant () (VFloat 3.0))) (Null ())))
    )
testHakaru :: Program () Double
testHakaru = Program [](LetIn() "x" (Uniform ())
                                      (LetIn ()  "y" (Uniform ())
                                         (Cons () (Var () "x")
                                           (Cons ()
                                             (Var () "y")
                                             (Cons ()
                                                (Plus () (Mult () (Constant () (VFloat (-2.0)))(Var () "x")) (Var () "y"))
                                                (Null ()))))))
-- let x = normal in (if flip then x + theta else x - 0.7)
testBranchedLetList :: Program () Double
testBranchedLetList = Program [](LetIn() "x" (Plus () (Normal ()) (Constant () (VFloat 1.0)))
                              (LetIn() "y" (Normal ())
                                    (IfThenElse ()
                                      (GreaterThan () (Uniform ())(Constant () (VFloat 0.8)))
                                        (Cons ()
                                          (InjF () "sig" [] (InjF () "plus" [ThetaI () 0]  (Var () "x")))
                                          (Cons ()  (InjF () "sig" []  (Var () "y")) (Null ())))
                                        (Cons ()
                                          (InjF () "sig" [] (InjF () "plus" [Constant () (VFloat (-0.7))]  (Var () "x")))
                                          (Cons ()  (InjF () "sig" [] (InjF () "plus" [ThetaI () 1]  (Var () "y"))) (Null ())))
                                          )))
testBranchedLetList2 :: Program () Double
testBranchedLetList2 = Program [](LetIn() "x" (Plus () (Normal ()) (Constant () (VFloat 0.357)))
                                        (Cons ()
                                          (IfThenElse ()
                                            (GreaterThan () (Uniform ())(Constant () (VFloat 0.659)))
                                            (InjF () "sig" [] (InjF () "plus" [ThetaI () 0]  (Var () "x")))
                                            (InjF () "sig" [] (InjF () "plus" [Constant () (VFloat (-0.358))]  (Var () "x"))))
                                          (Cons ()(InjF () "sig" []
                                                  (Mult () (Constant () (VFloat (-0.358)))
                                                   (Plus () (Var () "x") (Normal ())))) (Null ()))
                                        ))
-- let x = normal in let y = normal in [(if flip then f(x*y) else g(x)), (if flip then f(y) else g(y)), sig(y * (x + normal))]
-- y = VBranch val1 val2
-- sig(y * (x + normal)) = BranchedProbability "x" (BranchedProbability "y" val1 val2) (BranchedProbability "y" val3 val4)
-- BranchProbability "y" v1 v2
-- BranchedProbability "x" 


-- let x = normal in [sig(x), x+uniform]
-- query [ < 0.5, 1]
testBranchedLetList3 :: Program () Double
testBranchedLetList3 = Program [](LetIn() "x" (Plus () (Normal ()) (Constant () (VFloat 0.357)))
                                  (LetIn() "y" (Normal ())
                                        (Cons ()
                                          (IfThenElse ()
                                            (GreaterThan () (Uniform ())(Constant () (VFloat 0.659)))
                                            (InjF () "sig" [] (InjF () "plus" [ThetaI () 0]  (Var () "x")))
                                            (InjF () "sig" [] (InjF () "plus" [Constant () (VFloat (-0.358))]  (Var () "x"))))
                                          (Cons ()
                                            (IfThenElse ()
                                              (GreaterThan () (Uniform ())(Constant () (VFloat 0.659)))
                                              (InjF () "sig" [] (InjF () "plus" [ThetaI () 0]  (Var () "y")))
                                              (InjF () "sig" [] (InjF () "plus" [Constant () (VFloat (-0.358))]  (Var () "y"))))
                                          
                                          (Cons ()(InjF () "sig" []
                                                     (Mult () (Var () "y")
                                                      (Plus () (Var () "x") (Normal ())))) (Null ())
                                                    ))
                                                   )
                                        ))
                                        
testBranchedLet :: Program () Double
testBranchedLet = Program [](LetIn() "x" (Plus () (Normal ()) (Constant () (VFloat 1.0)))
                                    (IfThenElse ()
                                      (GreaterThan () (Uniform ())(Constant () (VFloat 0.8)))
                                      (InjF () "sig" [] (InjF () "plus" [ThetaI () 0]  (Var () "x")))
                                      (InjF () "sig" [] (InjF () "plus" [Constant () (VFloat (-0.7))]  (Var () "x")))))

testNestedLetInDecl :: Program () Double
testNestedLetInDecl = Program [] (LetIn() "x" (Plus () (ThetaI () 0) (Normal ()))
                         (LetIn ()  "y" (Plus () (ThetaI () 1) (Plus () (Normal ()) (Var () "x")))
                                  (Cons () (Var () "x")
                                     (Cons () (Var () "y")
                                       (Cons () (Plus () (Normal ())  (Var () "y"))
                                        (Null ()))))))
-- let x = normal in let y = normal in [x, x+y]
                                   
testNestedLetInWit :: Program () Double
testNestedLetInWit = Program [] (LetIn () "x" (Mult () (ThetaI () 0) (Normal ()))
                         (LetIn ()  "y" (Mult () (Normal ()) (ThetaI () 0) )
                                  (Cons () (Plus () (Var () "y") (Var () "x"))
                                    (Cons ()  (Var () "x")
                                     (Null ())))))
testInjFD :: Program () Double
testInjFD = Program [] (InjF () "mult" [Constant () (VFloat (-2.0))] (Plus () (ThetaI () 0) (Normal ())))

testObserve :: Program () Double
testObserve = Program [] (LetIn() "x"  (Normal ())
                              (LetIn() "x" (Plus () (Constant () (VFloat 2.0)) (Normal ()))
                                (Var () "x")))

testLetXYD :: Program () Double
testLetXYD = Program [] (LetIn() "x" (Plus () (ThetaI () 0) (Normal ()))
                          (LetIn ()  "y"  (ThetaI () 1)
                                         (Cons () (Var () "x") 
                                           (Cons () 
                                             (Plus () (Normal ())(Var () "y"))
                                             (Cons () 
                                                (Mult () (Plus () (Normal ())(Var () "x")) (Var () "y"))
                                                (Null ()))))))
                                             
testLetXY :: Program () Double
testLetXY = Program [] (LetIn() "x" (Plus () (ThetaI () 0) (Normal ()))
                          (LetIn ()  "y" (Plus () (ThetaI () 1) (Normal ()))
                                         (Cons () (Var () "x") 
                                           (Cons () 
                                             (Var () "y")
                                             (Cons () 
                                                (Mult () (Plus () (Normal ())(Var () "x")) (Var () "y"))
                                                (Null ()))))))
                                             

testLetTuple :: Program () Double
testLetTuple = Program [] (LetIn() "x" (Plus () (ThetaI () 0) (Normal ()))
                                              (Cons () (Var () "x") 
                                                (Cons () 
                                                  (Plus () (Normal ())(Var () "x")) 
                                                  (Null ()))))

testNormal :: Program () Double
testNormal = Program [] (Normal ())

testLetE :: Expr () Double
testLetE = LetIn () "x" (Normal ()) (InjF () "plus" [Constant () (VFloat 3.0)] (Var () "x"))
testPlusProg :: Program () Float
testPlusProg = Program [("main", IfThenElse ()
                                                   (GreaterThan () (ThetaI () 1)(ThetaI () 1))
                                                   (ThetaI () 1)
                                                   (Plus () (ThetaI () 1) (Call () "main")))]
                             (Call () "main")

testPlus :: Expr () a
testPlus = IfThenElse ()
             (GreaterThan () (Uniform ()) (ThetaI () 0))
             (Null ())
             (Cons () (Constant () (VBool True)) (Null ()))

testPlus2 :: Program () a
testPlus2 = Program [] (Plus () (Mult () (ThetaI () 0) (Uniform ())) (ThetaI () 1))


testGreater :: Expr () a
testGreater = GreaterThan () (Uniform ()) (ThetaI () 0)

testGreater2 :: Expr () Float
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

expertAnnotated :: Expr () a
expertAnnotated = Lambda () "im" (IfThenElse ()
  (ReadNN () "isMnist" (Var () "im"))
  (Cons () (Constant () (VInt 1)) (Cons () (ReadNN () "classifyMNist" (Var () "im")) (Null ())))
  (Cons () (Constant () (VInt 2)) (Cons () (ReadNN () "classifyCIFAR" (Var () "im")) (Null ()))))

expertAnnotatedTyped :: Expr TypeInfo a
expertAnnotatedTyped = Lambda (TypeInfo (Arrow TSymbol (SPLL.Typing.RType.ListOf TInt)) Integrate) "im" (IfThenElse (TypeInfo (SPLL.Typing.RType.ListOf TInt) Integrate)
  (ReadNN (TypeInfo TBool Integrate) "isMnist" (Var (TypeInfo TSymbol Deterministic) "im"))
  (Cons (TypeInfo (SPLL.Typing.RType.ListOf TInt) Integrate) (Constant (TypeInfo TInt Deterministic) (VInt 1)) (Cons (TypeInfo (SPLL.Typing.RType.ListOf TInt) Integrate) (ReadNN (TypeInfo TInt Integrate) "classifyMNist" (Var (TypeInfo TSymbol Deterministic) "im")) (Null (TypeInfo (SPLL.Typing.RType.ListOf TInt) Deterministic))))
  (Cons (TypeInfo (SPLL.Typing.RType.ListOf TInt) Integrate) (Constant (TypeInfo TInt Deterministic) (VInt 2)) (Cons (TypeInfo (SPLL.Typing.RType.ListOf TInt) Integrate) (ReadNN (TypeInfo TInt Integrate) "classifyCIFAR" (Var (TypeInfo TSymbol Deterministic) "im")) (Null (TypeInfo (SPLL.Typing.RType.ListOf TInt) Deterministic)))))

compilationExample :: Expr () a
compilationExample = GreaterThan () (Uniform ()) (ThetaI () 0)

--expert_model_proofs image =
--  if isMNist
--    then (1, classifyMNist image)
--    else (2, classifyCIFAR image)

--expert_model image =
--  if is28x28x1 image
--    then classifyMNist image
--    else classifyCIFAR image

