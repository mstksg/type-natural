{-# LANGUAGE DataKinds, EmptyDataDecls, FlexibleContexts, FlexibleInstances #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE GADTs, KindSignatures, PolyKinds, StandaloneDeriving           #-}
{-# LANGUAGE TypeFamilies, TypeOperators                                    #-}
-- | Set-theoretic ordinal arithmetic
module Data.Type.Ordinal
       ( -- * Data-types
         Ordinal (..),
         -- * Conversion from cardinals to ordinals.
         sNatToOrd', sNatToOrd, ordToInt, ordToSNat,
         ordToSNat', CastedOrdinal(..),
         unsafeFromInt,
         -- * Ordinal arithmetics
         (@+), enumOrdinal
       ) where
import Data.Type.Monomorphic
import Data.Type.Natural hiding (promote)

-- | Set-theoretic (finite) ordinals:
--
-- > n = {0, 1, ..., n-1}
--
-- So, @Ordinal n@ has exactly n inhabitants. So especially @Ordinal Z@ is isomorphic to @Void@.
data Ordinal n where
  OZ :: Ordinal (S n)
  OS :: Ordinal n -> Ordinal (S n)

-- | Parsing always fails, because there are no inhabitant.
instance Read (Ordinal Z) where
  readsPrec _ _ = []

instance SingRep n => Num (Ordinal n) where
  _ + _ = error "Finite ordinal is not closed under addition."
  _ - _ = error "Ordinal subtraction is not defined"
  negate OZ = OZ
  negate _  = error "There are no negative oridnals!"
  OZ * _ = OZ
  _ * OZ = OZ
  _ * _  = error "Finite ordinal is not closed under multiplication"
  abs    = id
  signum = error "What does Ordinal sign mean?"
  fromInteger = unsafeFromInt . fromInteger

deriving instance Read (Ordinal n) => Read (Ordinal (S n))
deriving instance Show (Ordinal n)
deriving instance Eq (Ordinal n)
deriving instance Ord (Ordinal n)

instance SingRep n => Enum (Ordinal n) where
  fromEnum = ordToInt
  toEnum   = unsafeFromInt
  enumFrom = enumFromOrd
  enumFromTo = enumFromToOrd

enumFromToOrd :: forall n. SingRep n => Ordinal n -> Ordinal n -> [Ordinal n]
enumFromToOrd ok ol =
  let k = ordToInt ok
      l = ordToInt ol
  in take (l - k + 1) $ enumFromOrd ok

enumFromOrd :: forall n. SingRep n => Ordinal n -> [Ordinal n]
enumFromOrd ord = drop (ordToInt ord) $ enumOrdinal (sing :: SNat n)

enumOrdinal :: SNat n -> [Ordinal n]
enumOrdinal SZ = []
enumOrdinal (SS n) = OZ : map OS (enumOrdinal n)

instance SingRep n => Bounded (Ordinal (S n)) where
  minBound = OZ
  maxBound =
    case propToBoolLeq $ leqRefl (sing :: SNat n) of
      LeqTrueInstance -> sNatToOrd (sing :: SNat n)

unsafeFromInt :: forall n. SingRep n => Int -> Ordinal n
unsafeFromInt n = 
    case promote n of
      Monomorphic sn ->
        case sS sn %:<<= (sing :: SNat n) of
          STrue -> sNatToOrd' (sing :: SNat n) sn
          SFalse -> error "Bound over!"

-- | 'sNatToOrd'' @n m@ injects @m@ as @Ordinal n@.
sNatToOrd' :: (S m :<<= n) ~ True => SNat n -> SNat m -> Ordinal n
sNatToOrd' (SS _) SZ = OZ
sNatToOrd' (SS n) (SS m) = OS $ sNatToOrd' n m
sNatToOrd' _ _ = bugInGHC

-- | 'sNatToOrd'' with @n@ inferred.
sNatToOrd :: (SingRep n, (S m :<<= n) ~ True) => SNat m -> Ordinal n
sNatToOrd = sNatToOrd' sing

data CastedOrdinal n where
  CastedOrdinal :: (S m :<<= n) ~ True => SNat m -> CastedOrdinal n

-- | Convert @Ordinal n@ into @SNat m@ with the proof of @S m :<<= n@.
ordToSNat' :: Ordinal n -> CastedOrdinal n
ordToSNat' OZ = CastedOrdinal sZ
ordToSNat' (OS on) =
  case ordToSNat' on of
    CastedOrdinal m -> CastedOrdinal (sS m)

-- | Convert @Ordinal n@ into monomorphic @SNat@
ordToSNat :: Ordinal n -> Monomorphic (Sing :: Nat -> *)
ordToSNat OZ = Monomorphic SZ
ordToSNat (OS n) =
  case ordToSNat n of
    Monomorphic sn ->
      case singInstance sn of
        SingInstance -> Monomorphic (SS sn)

-- | Convert ordinal into @Int@.
ordToInt :: Ordinal n -> Int
ordToInt OZ = 0
ordToInt (OS n) = 1 + ordToInt n

-- | Inclusion function for ordinals.
inclusion' :: (n :<<= m) ~ True => SNat m -> Ordinal n -> Ordinal m
inclusion' (SS SZ) OZ = OZ
inclusion' (SS (SS _)) OZ = OZ
inclusion' (SS (SS n)) (OS m) = OS $ inclusion' (sS n) m
inclusion' _ _ = bugInGHC

-- | Inclusion function for ordinals with codomain inferred.
inclusion :: ((n :<<= m) ~ True, SingRep m) => Ordinal n -> Ordinal m
inclusion = inclusion' sing

-- | Ordinal addition.
(@+) :: forall n m. (SingRep n, SingRep m) => Ordinal n -> Ordinal m -> Ordinal (n :+ m)
OZ @+ n =
  let sn = sing :: SNat n
      sm = sing :: SNat m
  in case singInstance (sn %+ sm) of
       SingInstance ->
         case propToBoolLeq (plusLeqR sn sm) of
           LeqTrueInstance -> inclusion n
OS n @+ m =
  case sing :: SNat n of
    SS sn -> case singInstance sn of SingInstance -> OS $ n @+ m
    _ -> bugInGHC
