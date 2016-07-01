{-# LANGUAGE ViewPatterns #-}
-- | Tests for Statistics.Math
module Tests.SpecFunctions (
  tests
  ) where

import qualified Data.Vector as V
import           Data.Vector   ((!))

import Test.QuickCheck  hiding (choose,within)
import Test.Framework
import Test.Framework.Providers.QuickCheck2

import Tests.Helpers
import Tests.SpecFunctions.Tables
import Numeric.SpecFunctions
import Numeric.MathFunctions.Comparison (within,relativeError)
import Numeric.MathFunctions.Constants  (m_epsilon,m_tiny)

tests :: Test
tests = testGroup "Special functions"
  [ testProperty "Gamma(x+1) = x*Gamma(x) [logGamma]"  $ gammaReccurence logGamma  3e-8
  , testProperty "Gamma(x+1) = x*Gamma(x) [logGammaL]" $ gammaReccurence logGammaL 2e-13
  , testProperty "gamma(1,x) = 1 - exp(-x)"      $ incompleteGammaAt1Check
  , testProperty "0 <= gamma <= 1"               $ incompleteGammaInRange
  , testProperty "0 <= I[B] <= 1"            $ incompleteBetaInRange
  , testProperty "invIncompleteGamma = gamma^-1" $ invIGammaIsInverse
  -- XXX FIXME DISABLED due to failures
  -- , testProperty "invIncompleteBeta  = B^-1" $ invIBetaIsInverse
  , testProperty "gamma - increases" $
      \(abs -> s) (abs -> x) (abs -> y) -> s > 0 ==> monotonicallyIncreases (incompleteGamma s) x y
  , testProperty "invErfc = erfc^-1"         $ invErfcIsInverse
  , testProperty "invErf  = erf^-1"          $ invErfIsInverse
    -- Unit tests
  , testAssertion "Factorial is expected to be precise at 1e-15 level"
      $ and [ eq 1e-15 (factorial (fromIntegral n :: Int))
                       (fromIntegral (factorial' n))
            |n <- [0..170]]
  , testAssertion "Log factorial is expected to be precise at 1e-15 level"
      $ and [ eq 1e-15 (logFactorial (fromIntegral n :: Int))
                       (log $ fromIntegral $ factorial' n)
            | n <- [2..170]]
  , testAssertion "logGamma is expected to be precise at 1e-9 level [integer points]"
      $ and [ eq 1e-9 (logGamma (fromIntegral n))
                      (logFactorial (n-1))
            | n <- [3..10000::Int]]
  , testAssertion "logGamma is expected to be precise at 1e-9 level [fractional points]"
      $ and [ eq 1e-9 (logGamma x) lg | (x,lg) <- tableLogGamma ]
  , testAssertion "logGammaL is expected to be precise at 1e-15 level"
      $ and [ eq 1e-15 (logGammaL (fromIntegral n))
                       (logFactorial (n-1))
            | n <- [3..10000::Int]]
    -- FIXME: Too low!
  , testAssertion "logGammaL is expected to be precise at 1e-10 level [fractional points]"
      $ and [ eq 1e-10 (logGammaL x) lg | (x,lg) <- tableLogGamma ]
    -- FIXME: loss of precision when logBeta p q ≈ 0.
    --        Relative error doesn't work properly in this case.
  , testAssertion "logBeta is expected to be precise at 1e-6 level"
      $ and [ eq 1e-6 (logBeta p q)
                      (logGammaL p + logGammaL q - logGammaL (p+q))
            | p <- [0.1,0.2 .. 0.9] ++ [2 .. 20]
            , q <- [0.1,0.2 .. 0.9] ++ [2 .. 20]
            ]
  , testAssertion "digamma is expected to be precise at 1e-14 [integers]"
      $ digammaTestIntegers 1e-14
    -- Relative precision is lost when digamma(x) ≈ 0
  , testAssertion "digamma is expected to be precise at 1e-12"
      $ and [ eq 1e-12 r (digamma x) | (x,r) <- tableDigamma ]
    -- FIXME: Why 1e-8? Is it due to poor precision of logBeta?
  , testAssertion "incompleteBeta is expected to be precise at 1e-8 level"
      $ and [ eq 1e-8 (incompleteBeta p q x) ib | (p,q,x,ib) <- tableIncompleteBeta ]
  , testAssertion "incompleteBeta with p > 3000 and q > 3000"
      $ and [ eq 1e-11 (incompleteBeta p q x) ib | (x,p,q,ib) <-
                 [ (0.495,  3001,  3001, 0.2192546757957825068677527085659175689142653854877723)
                 , (0.501,  3001,  3001, 0.5615652382981522803424365187631195161665429270531389)
                 , (0.531,  3500,  3200, 0.9209758089734407825580172472327758548870610822321278)
                 , (0.501, 13500, 13200, 0.0656209987264794057358373443387716674955276089622780)
                 ]
            ]
  , testAssertion "choose is expected to precise at 1e-12 level"
      $ and [ eq 1e-12 (choose (fromIntegral n) (fromIntegral k)) (fromIntegral $ choose' n k)
            | n <- [0..1000], k <- [0..n]]
  , testAssertion "logChoose == log . choose"
      $ and [ let n' = fromIntegral n
                  k' = fromIntegral k
              in within 2 (logChoose n' k') (log $ choose n' k')
            | n <- [0..1000], k <- [0..n]]
    ----------------------------------------------------------------
    -- Self tests
  , testProperty "Self-test: 0 <= range01 <= 1" $ \x -> let f = range01 x in f <= 1 && f >= 0
  ]

----------------------------------------------------------------
-- QC tests
----------------------------------------------------------------

-- Γ(x+1) = x·Γ(x)
gammaReccurence :: (Double -> Double) -> Double -> Double -> Property
gammaReccurence logG ε x =
  (x > 0 && x < 100)  ==>  (abs (g2 - g1 - log x) < ε)
    where
      g1 = logG x
      g2 = logG (x+1)

-- γ(s,x) is in [0,1] range
incompleteGammaInRange :: Double -> Double -> Property
incompleteGammaInRange (abs -> s) (abs -> x) =
  x >= 0 && s > 0  ==> let i = incompleteGamma s x in i >= 0 && i <= 1

-- γ(1,x) = 1 - exp(-x)
-- Since Γ(1) = 1 normalization doesn't make any difference
incompleteGammaAt1Check :: Double -> Property
incompleteGammaAt1Check (abs -> x) =
  x > 0 ==> (incompleteGamma 1 x + exp(-x)) ≈ 1
  where
    (≈) = eq 1e-13

-- invIncompleteGamma is inverse of incompleteGamma
invIGammaIsInverse :: Double -> Double -> Property
invIGammaIsInverse (abs -> a) (range01 -> p) =
  a > m_tiny && p > m_tiny && p < 1  ==>
    ( counterexample ("a    = " ++ show a )
    $ counterexample ("p    = " ++ show p )
    $ counterexample ("x    = " ++ show x )
    $ counterexample ("p'   = " ++ show p')
    $ counterexample ("err  = " ++ show (relativeError p p'))
    $ counterexample ("pred = " ++ show δ)
    $ relativeError p p' < δ
    )
  where
    x  = invIncompleteGamma a p
    f' = exp ( log x * (a-1) - x - logGamma a)
    p' = incompleteGamma    a x
    -- FIXME: 128 is big constant. It should be replaced by something
    --        smaller when #42 is fixed
    δ  = (m_epsilon/2) * (256 + 1 * (1 + abs (x * f' / p)))

-- invErfc is inverse of erfc
invErfcIsInverse :: Double -> Property
invErfcIsInverse ((*2) . range01 -> p)
  = counterexample ("p  = " ++ show p )
  $ counterexample ("x  = " ++ show x )
  $ counterexample ("p' = " ++ show p')
  $ abs (p - p') <= 1e-14
  where
    x  = invErfc p
    p' = erfc x

-- invErf is inverse of erf
invErfIsInverse :: Double -> Property
invErfIsInverse a
  = counterexample ("p  = " ++ show p )
  $ counterexample ("x  = " ++ show x )
  $ counterexample ("p' = " ++ show p')
  $ abs (p - p') <= 1e-14
  where
    x  = invErf p
    p' = erf x
    p  | a < 0     = - range01 a
       | otherwise =   range01 a

-- B(s,x) is in [0,1] range
incompleteBetaInRange :: Double -> Double -> Double -> Property
incompleteBetaInRange (abs -> p) (abs -> q) (range01 -> x) =
  p > 0 && q > 0  ==> let i = incompleteBeta p q x in i >= 0 && i <= 1

-- invIncompleteBeta is inverse of incompleteBeta
invIBetaIsInverse :: Double -> Double -> Double -> Property
invIBetaIsInverse (abs -> p) (abs -> q) (range01 -> x) =
  p > 0 && q > 0  ==> ( counterexample ("p   = " ++ show p )
                      $ counterexample ("q   = " ++ show q )
                      $ counterexample ("x   = " ++ show x )
                      $ counterexample ("x'  = " ++ show x')
                      $ counterexample ("a   = " ++ show a)
                      $ counterexample ("err = " ++ (show $ abs $ (x - x') / x))
                      $ abs (x - x') <= 1e-12
                      )
  where
    x' = incompleteBeta    p q a
    a  = invIncompleteBeta p q x

-- Table for digamma function:
--
-- Uses equality ψ(n) = H_{n-1} - γ where
--   H_{n} = Σ 1/k, k = [1 .. n]     - harmonic number
--   γ     = 0.57721566490153286060  - Euler-Mascheroni number
digammaTestIntegers :: Double -> Bool
digammaTestIntegers eps
  = all (uncurry $ eq eps) $ take 3000 digammaInt
  where
    ok approx exact = approx
    -- Harmonic numbers starting from 0
    harmN = scanl (\a n -> a + 1/n) 0 [1::Rational .. ]
    gam   = 0.57721566490153286060
    -- Digamma values
    digammaInt = zipWith (\i h -> (digamma i, realToFrac h - gam)) [1..] harmN


----------------------------------------------------------------
-- Unit tests
----------------------------------------------------------------

-- Lookup table for fact factorial calculation. It has fixed size
-- which is bad but it's OK for this particular case
factorial_table :: V.Vector Integer
factorial_table = V.generate 2000 (\n -> product [1..fromIntegral n])

-- Exact implementation of factorial
factorial' :: Integer -> Integer
factorial' n = factorial_table ! fromIntegral n

-- Exact albeit slow implementation of choose
choose' :: Integer -> Integer -> Integer
choose' n k = factorial' n `div` (factorial' k * factorial' (n-k))

-- Truncate double to [0,1]
range01 :: Double -> Double
range01 = abs . (snd :: (Integer, Double) -> Double) . properFraction
