{-# LANGUAGE TupleSections #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses#-}

module Learners.MissingP where

import Types
import qualified Data.Text as T
import qualified Data.Text.IO as T
import qualified Data.List as L
import qualified Data.Map as M
import qualified Data.Ord as O

import Debug.Trace

-- optimization so that we don't keep duplicates
simplify :: [(MissingKVRule, Int, Int)] -> [(MissingKVRule, Int, Int)]
simplify xs = L.map combineCounts $ sortedRules xs
  where
    sameRule (r1, y1, n1) (r2, y2, n2) = r1 == r2
    sortKey (r, y, n) = show r -- super hacky solution, sorry
    mergeTwo = (\(r1, y1, n1) (r2, y2, n2) -> (r1, y1 + y2, n1 + n2))
    combineCounts (r:rs) = foldl mergeTwo r rs
    sortedRules xs = L.groupBy sameRule $ (L.sortBy . O.comparing) sortKey xs

-- instead of just a KVRule, keep track of the rule plus counts for + counts against
instance Attribute [] (MissingKVRule, Int, Int) where
  learn [] = []
  -- for each line in our file, see if any of the following lines have the same 'keyword' and if not, then that's a rule
  learn (l:ls) = simplify $ concatMap (\l' -> if (keyword l == keyword l') then [] else [(MissingKVRule l l', 1, 0)]) ls ++ learn ls

  check rs f =
   let
     fRules = learn f
     diff = L.deleteFirstsBy (\(r1, y1, n1) (r2, y2, n2) -> r1 == r2) rs fRules --the difference between the two rule sets
     x = if null diff then Nothing else Just diff
   in
    x

  merge curr new = simplify $ curr ++ new


instance Attribute [] (MissingKRule, Int, Int) where
  learn [] = []
  learn (l:ls) = concatMap (\l' -> if (keyword l == keyword l') then [(MissingKRule (keyword l) (keyword l'), 0, 1)] else [(MissingKRule (keyword l) (keyword l'), 1, 0)]) ls ++ learn ls

  check rs f =
   let
     fRules = learn f
     rs' = L.nubBy (\(x1, y1, n1) (x2, y2, n2) -> x1 == x2) rs
     diff = L.deleteFirstsBy (\(r1, y1, n1) (r2, y2, n2) -> r1 == r2) rs' fRules --the difference between the two rule sets
     x = if null diff then Nothing else Just diff
   in
     x

  merge curr new =
    let
      sameRule (r1, y1, n1) (r2, y2, n2) = r1 == r2
      sortKey (r, y, n) = show r -- super hacky solution, sorry
      addRuleInstances (ri:rest) = foldl (\(r1, y1, n1) (r2, y2, n2) -> (r1, y1 + y2, n1 + n2)) ri rest
    in
      L.map addRuleInstances $ L.groupBy sameRule $ (L.sortBy . O.comparing) sortKey (curr ++ new)
