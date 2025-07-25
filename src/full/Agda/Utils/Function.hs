{-# OPTIONS_GHC -Wunused-imports #-}

{-# LANGUAGE RebindableSyntax #-}

module Agda.Utils.Function
  ( module Agda.Utils.Function
  , module Data.Function
  ) where

import Prelude hiding ( not, (&&), (||) )

import Data.Function  ( on )
import Data.String    ( fromString )       -- for RebindableSyntax, somehow not covered by Prelude

import Agda.Utils.Boolean

-- | Repeat a state transition @f :: a -> (b, a)@ with output @b@
--   while condition @cond@ on the output is true.
--   Return all intermediate results and the final result
--   where @cond@ is @False@.
--
--   Postconditions (when it terminates):
--   @fst (last (iterWhile cond f a)) == False@.
--   @all fst (init (interWhile cond f a))@.

iterWhile :: (b -> Bool) -> (a -> (b, a)) -> a -> [(b,a)]
iterWhile cond f = loop where
  loop a = r : if cond b then loop a' else []
    where r@(b, a') = f a

-- | Repeat something while a condition on some state is true.
--   Return the last state (including the changes of the last
--   transition, even if the condition became false then).

repeatWhile :: (a -> (Bool, a)) -> a -> a
repeatWhile f = loop where
  loop a = if again then loop a' else a'
    where (again, a') = f a

-- | Monadic version of 'repeatWhile'.
repeatWhileM :: (Monad m) => (a -> m (Bool, a)) -> a -> m a
repeatWhileM f = loop where
  loop a = do
    (again, a') <- f a
    if again then loop a' else return a'

-- | A version of the trampoline function.
--
--   The usual function iterates @f :: a -> Maybe a@ as long
--   as @Just{}@ is returned, and returns the last value of @a@
--   upon @Nothing@.
--
--   @usualTrampoline f = trampolineWhile $ \ a -> maybe (False,a) (True,) (f a)@.
--
--   @trampolineWhile@ is very similar to @repeatWhile@, only that
--   it discards the state on which the condition went @False@,
--   and returns the last state on which the condition was @True@.
trampolineWhile :: (a -> (Bool, a)) -> a -> a
trampolineWhile f = repeatWhile $ \ a ->
  let (again, a') = f a
  in (again,) $ if again then a' else a

-- | Monadic version of 'trampolineWhile'.
trampolineWhileM :: (Monad m) => (a -> m (Bool, a)) -> a -> m a
trampolineWhileM f = repeatWhileM $ \ a -> do
  (again, a') <- f a
  return $ (again,) $ if again then a' else a

-- | More general trampoline, which allows some final computation
--   from iteration state @a@ into result type @b@.
trampoline :: (a -> Either b a) -> a -> b
trampoline f = loop where
  loop a = either id loop $ f a

-- | Monadic version of 'trampoline'.
trampolineM :: Monad m => (a -> m (Either b a)) -> a -> m b
trampolineM f = loop where
  loop a = either return loop =<< f a

-- | Iteration to fixed-point.
--
--   @iterateUntil r f a0@ iterates endofunction @f@, starting with @a0@,
--   until @r@ relates its result to its input, i.e., @f a `r` a@.
--
--   This is the generic pattern behind saturation algorithms.
--
--   If @f@ is monotone with regard to @r@,
--   meaning @a `r` b@ implies @f a `r` f b@,
--   and @f@-chains starting with @a0@ are finite
--   then iteration is guaranteed to terminate.
--
--   A typical instance will work on sets, and @r@ could be set inclusion,
--   and @a0@ the empty set, and @f@ the step function of a saturation algorithm.
iterateUntil :: (a -> a -> Bool) -> (a -> a) -> a -> a
iterateUntil r f = loop where
  loop a = if r a' a then a' else loop a'
    where a' = f a

-- | Monadic version of 'iterateUntil'.
iterateUntilM :: Monad m => (a -> a -> Bool) -> (a -> m a) -> a -> m a
iterateUntilM r f = loop where
  loop a = do
    a' <- f a
    if r a' a then return a' else loop a'

-- | @'iterate'' n f x@ applies @f@ to @x@ @n@ times and returns the
-- result.
--
-- The applications are calculated strictly.

iterate' :: Integral i => i -> (a -> a) -> a -> a
iterate' n f x
  | n >= 0    = go n x
  | otherwise = error "iterate': Negative input."
  where
    go n x
      | n > 0     = go (n - 1) $! f x
      | otherwise = x

-- * Iteration over Booleans.

-- | @applyWhen b f a@ applies @f@ to @a@ when @b@.
{-# SPECIALIZE applyWhen :: Bool -> (a -> a) -> (a -> a) #-}
{-# INLINE applyWhen #-}
applyWhen :: IsBool b => b -> (a -> a) -> a -> a
applyWhen b f = if b then f else id
  -- Note: RebindableSyntax translates this if-then-else to ifThenElse of IsBool.

-- | @applyUnless b f a@ applies @f@ to @a@ unless @b@.
{-# SPECIALIZE applyUnless :: Bool -> (a -> a) -> (a -> a) #-}
{-# INLINE applyUnless #-}
applyUnless :: IsBool b => b -> (a -> a) -> a -> a
applyUnless b f = if b then id else f
  -- Note: RebindableSyntax translates this if-then-else to ifThenElse of IsBool.

-- | @applyWhenIts p f a@ applies @f@ to @a@ when @p a@.
{-# SPECIALIZE applyWhenIts :: (a -> Bool) -> (a -> a) -> (a -> a) #-}
{-# INLINE applyWhenIts #-}
applyWhenIts :: IsBool b => (a -> b) -> (a -> a) -> a -> a
applyWhenIts p f a = if p a then f a else a
  -- Note: RebindableSyntax translates this if-then-else to ifThenElse of IsBool.

-- | @applyUnlessIts p f a@ applies @f@ to @a@ unless @p a@.
{-# SPECIALIZE applyUnlessIts :: (a -> Bool) -> (a -> a) -> (a -> a) #-}
{-# INLINE applyUnlessIts #-}
applyUnlessIts :: IsBool b => (a -> b) -> (a -> a) -> a -> a
applyUnlessIts p f a = if p a then a else f a
  -- Note: RebindableSyntax translates this if-then-else to ifThenElse of IsBool.

-- | Monadic version of @applyWhen@
{-# SPECIALIZE applyWhenM :: Monad m => m Bool -> (m a -> m a) -> m a -> m a #-}
{-# INLINE applyWhenM #-}
applyWhenM :: (IsBool b, Monad m) => m b -> (m a -> m a) -> m a -> m a
applyWhenM mb f x = mb >>= \ b -> applyWhen b f x

-- | Monadic version of @applyUnless@
{-# SPECIALIZE applyUnlessM :: Monad m => m Bool -> (m a -> m a) -> m a -> m a #-}
{-# INLINE applyUnlessM #-}
applyUnlessM :: (IsBool b, Monad m) => m b -> (m a -> m a) -> m a -> m a
applyUnlessM mb f x = mb >>= \ b -> applyUnless b f x

-- | 'Maybe' version of 'applyWhen'.
{-# INLINE applyWhenJust #-}
applyWhenJust :: Maybe b -> (b -> a -> a) -> a -> a
applyWhenJust m f = maybe id f m

-- | 'Maybe' version of 'applyUnless'.
{-# INLINE applyWhenNothing #-}
applyWhenNothing :: Maybe b -> (a -> a) -> a -> a
applyWhenNothing m f = maybe f (const id) m
