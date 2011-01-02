{-# LANGUAGE GADTs #-}

module Main where

import Control.DeepSeq
import Control.Exception (evaluate)
import Control.Monad.Trans (liftIO)
import Criterion.Config
import Criterion.Main
import Data.Bits ((.&.))
import Data.Hashable (Hashable)
import qualified Data.ByteString as BS
import qualified Data.HashMap as HM
import qualified Data.IntMap as IM
import qualified Data.Map as M
import Data.List (foldl')
import Data.Maybe (fromMaybe)
import Prelude hiding (lookup)

import qualified Util.ByteString as UBS
import qualified Util.Int as UI
import qualified Util.String as US

instance NFData BS.ByteString

data B where
    B :: NFData a => a -> B

instance NFData B where
    rnf (B b) = rnf b

main :: IO ()
main = do
    let hm   = fromList elems :: HM.HashMap String Int
        hmbs = fromList elemsBS :: HM.HashMap BS.ByteString Int
        hmi  = fromList elemsI :: HM.HashMap Int Int
        m    = M.fromList elems :: M.Map String Int
        mbs  = M.fromList elemsBS :: M.Map BS.ByteString Int
        im   = IM.fromList elemsI :: IM.IntMap Int
    defaultMainWith defaultConfig
        (liftIO . evaluate $ rnf [B m, B mbs, B hm, B hmbs, B hmi, B im])
        [
          -- * Comparison to other data structures
          -- ** Map
          bgroup "Map"
          [ bgroup "lookup"
            [ bench "String" $ nf (lookupM keys) m
            , bench "ByteString" $ nf (lookupM keysBS) mbs
            ]
          , bgroup "insert"
            [ bench "String" $ nf (insertM elems) M.empty
            , bench "ByteStringString" $ nf (insertM elemsBS) M.empty
            ]
          , bgroup "delete"
            [ bench "String" $ nf (insertM elems) M.empty
            , bench "ByteString" $ nf (insertM elemsBS) M.empty
            ]
          ]

          -- ** IntMap
        , bgroup "IntMap"
          [ bench "lookup" $ nf (lookupIM keysI) im
          , bench "insert" $ nf (insertIM elemsI) IM.empty
          , bench "delete" $ nf (deleteIM keysI) im
          ]

          -- * Basic interface
        , bgroup "lookup"
          [ bench "String" $ nf (lookup keys) hm
          , bench "ByteString" $ nf (lookup keysBS) hmbs
          , bench "Int" $ nf (lookup keysI) hmi
          ]
        , bgroup "insert"
          [ bench "String" $ nf (insert elems) HM.empty
          , bench "ByteString" $ nf (insert elemsBS) HM.empty
          , bench "Int" $ nf (insert elemsI) HM.empty
          ]
        , bgroup "delete"
          [ bench "String" $ nf (delete keys) hm
          , bench "ByteString" $ nf (delete keysBS) hmbs
          , bench "Int" $ nf (delete keysI) hmi
          ]

          -- Transformations
        , bench "mapValues" $ nf (HM.mapValues (\ v -> v + 1)) hmi

          -- Folds
        , bench "fold" $ nf (HM.fold (\ k v z -> (k, v) : z) []) hmi
        , bench "fold'" $ nf (HM.fold' (\ _ v z -> v + z) 0) hmi

          -- Filter
        , bench "filter" $ nf (HM.filter (\ k _ -> k .&. 1 == 0)) hmi
        , bench "filterKeys" $ nf (HM.filterKeys (\ k -> k .&. 1 == 0)) hmi
        , bench "filterValues" $ nf (HM.filterValues (\ v -> v .&. 1 == 0)) hmi
        ]
  where
    n :: Int
    n = 2^(12 :: Int)

    elems   = zip keys [1..n]
    keys    = US.rnd 8 n
    elemsBS = zip keysBS [1..n]
    keysBS  = UBS.rnd 8 n
    elemsI  = zip keysI [1..n]
    keysI   = UI.rnd n n

------------------------------------------------------------------------
-- * HashMap

lookup :: (Eq k, Hashable k) => [k] -> HM.HashMap k Int -> Int
lookup xs m = foldl' (\z k -> fromMaybe z (HM.lookup k m)) 0 xs
{-# SPECIALIZE lookup :: [Int] -> HM.HashMap Int Int -> Int #-}
{-# SPECIALIZE lookup :: [String] -> HM.HashMap String Int -> Int #-}
{-# SPECIALIZE lookup :: [BS.ByteString] -> HM.HashMap BS.ByteString Int
                      -> Int #-}

insert :: (Eq k, Hashable k) => [(k, Int)] -> HM.HashMap k Int
       -> HM.HashMap k Int
insert xs m0 = foldl' (\m (k, v) -> HM.insert k v m) m0 xs
{-# SPECIALIZE insert :: [(Int, Int)] -> HM.HashMap Int Int
                      -> HM.HashMap Int Int #-}
{-# SPECIALIZE insert :: [(String, Int)] -> HM.HashMap String Int
                      -> HM.HashMap String Int #-}
{-# SPECIALIZE insert :: [(BS.ByteString, Int)] -> HM.HashMap BS.ByteString Int
                      -> HM.HashMap BS.ByteString Int #-}

delete :: (Eq k, Hashable k) => [k] -> HM.HashMap k Int -> HM.HashMap k Int
delete xs m0 = foldl' (\m k -> HM.delete k m) m0 xs
{-# SPECIALIZE delete :: [Int] -> HM.HashMap Int Int -> HM.HashMap Int Int #-}
{-# SPECIALIZE delete :: [String] -> HM.HashMap String Int
                      -> HM.HashMap String Int #-}
{-# SPECIALIZE delete :: [BS.ByteString] -> HM.HashMap BS.ByteString Int
                      -> HM.HashMap BS.ByteString Int #-}

------------------------------------------------------------------------
-- * Map

lookupM :: Ord k => [k] -> M.Map k Int -> Int
lookupM xs m = foldl' (\z k -> fromMaybe z (M.lookup k m)) 0 xs
{-# SPECIALIZE lookupM :: [String] -> M.Map String Int -> Int #-}
{-# SPECIALIZE lookupM :: [BS.ByteString] -> M.Map BS.ByteString Int -> Int #-}

insertM :: Ord k => [(k, Int)] -> M.Map k Int -> M.Map k Int
insertM xs m0 = foldl' (\m (k, v) -> M.insert k v m) m0 xs
{-# SPECIALIZE insertM :: [(String, Int)] -> M.Map String Int
                       -> M.Map String Int #-}
{-# SPECIALIZE insertM :: [(BS.ByteString, Int)] -> M.Map BS.ByteString Int
                       -> M.Map BS.ByteString Int #-}

deleteM :: Ord k => [k] -> M.Map k Int -> M.Map k Int
deleteM xs m0 = foldl' (\m k -> M.delete k m) m0 xs
{-# SPECIALIZE deleteM :: [String] -> M.Map String Int -> M.Map String Int #-}
{-# SPECIALIZE deleteM :: [BS.ByteString] -> M.Map BS.ByteString Int
                       -> M.Map BS.ByteString Int #-}

------------------------------------------------------------------------
-- * IntMap

lookupIM :: [Int] -> IM.IntMap Int -> Int
lookupIM xs m = foldl' (\z k -> fromMaybe z (IM.lookup k m)) 0 xs

insertIM :: [(Int, Int)] -> IM.IntMap Int -> IM.IntMap Int
insertIM xs m0 = foldl' (\m (k, v) -> IM.insert k v m) m0 xs

deleteIM :: [Int] -> IM.IntMap Int -> IM.IntMap Int
deleteIM xs m0 = foldl' (\m k -> IM.delete k m) m0 xs

------------------------------------------------------------------------
-- * Helpers

fromList :: (Eq k, Hashable k) => [(k, v)] -> HM.HashMap k v
fromList = foldl' (\m (k, v) -> HM.insert k v m) HM.empty
