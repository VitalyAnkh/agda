{-# OPTIONS_GHC -Wunused-imports #-}
{-# OPTIONS_GHC -Wunused-matches #-}
{-# OPTIONS_GHC -Wunused-binds #-}

-- | Generic traversal and reduce for concrete syntax,
--   in the style of "Agda.Syntax.Internal.Generic".
--
--   However, here we use the terminology of 'Data.Traversable'.

module Agda.Syntax.Concrete.Generic where

import Data.Bifunctor
import Data.Functor

import Agda.Syntax.Common
import Agda.Syntax.Concrete

import Agda.Utils.Either
import Agda.Utils.List1 (List1)
import Agda.Utils.List2 (List2)

import Agda.Utils.Impossible

-- Generic traversals for concrete expressions.
-- ========================================================================

-- | Generic traversals for concrete expressions.
--
--   Note: does not go into patterns!
class ExprLike a where
  mapExpr :: (Expr -> Expr) -> a -> a
  -- ^ This corresponds to 'map'.

  foldExpr :: Monoid m => (Expr -> m) -> a -> m
  -- ^ This corresponds to 'foldMap'.

  traverseExpr :: Monad m => (Expr -> m Expr) -> a -> m a
  -- ^ This corresponds to 'mapM'.

  default mapExpr :: (Functor t, ExprLike b, t b ~ a) => (Expr -> Expr) -> a -> a
  mapExpr = fmap . mapExpr

  default foldExpr
    :: (Monoid m, Foldable t, ExprLike b, t b ~ a)
    => (Expr -> m) -> a -> m
  foldExpr = foldMap . foldExpr

  default traverseExpr
    :: (Monad m, Traversable t, ExprLike b, t b ~ a)
    => (Expr -> m Expr) -> a -> m a
  traverseExpr = traverse . traverseExpr


-- Instances for things that do not contain expressions.
---------------------------------------------------------------------------

instance ExprLike () where
  mapExpr _      = id
  foldExpr _ _   = mempty
  traverseExpr _ = return

instance ExprLike Name where
  mapExpr _      = id
  foldExpr _ _   = mempty
  traverseExpr _ = return

instance ExprLike QName where
  mapExpr _      = id
  foldExpr _ _   = mempty
  traverseExpr _ = return

instance ExprLike Bool where
  mapExpr _      = id
  foldExpr _ _   = mempty
  traverseExpr _ = return

-- Instances for collections and decorations.
---------------------------------------------------------------------------

instance ExprLike a => ExprLike [a]
instance ExprLike a => ExprLike (List1 a)
instance ExprLike a => ExprLike (List2 a)
instance ExprLike a => ExprLike (Maybe a)

instance ExprLike a => ExprLike (Arg a)
instance ExprLike a => ExprLike (Named name a)
instance ExprLike a => ExprLike (Ranged a)
instance ExprLike a => ExprLike (WithHiding a)

instance ExprLike a => ExprLike (MaybePlaceholder a)
instance ExprLike a => ExprLike (RHS' a)
instance ExprLike a => ExprLike (TacticAttribute' a)
instance ExprLike a => ExprLike (TypedBinding' a)
instance ExprLike a => ExprLike (WhereClause' a)

instance (ExprLike a, ExprLike b) => ExprLike (Either a b) where
  mapExpr f      = bimap (mapExpr f) (mapExpr f)
  traverseExpr f = traverseEither (traverseExpr f) (traverseExpr f)
  foldExpr f     = either (foldExpr f) (foldExpr f)

instance (ExprLike a, ExprLike b) => ExprLike (a, b) where
  mapExpr      f (x, y) = (mapExpr f x, mapExpr f y)
  traverseExpr f (x, y) = (,) <$> traverseExpr f x <*> traverseExpr f y
  foldExpr     f (x, y) = foldExpr f x `mappend` foldExpr f y

instance (ExprLike a, ExprLike b, ExprLike c) => ExprLike (a, b, c) where
  mapExpr      f (x, y, z) = (mapExpr f x, mapExpr f y, mapExpr f z)
  traverseExpr f (x, y, z) = (,,) <$> traverseExpr f x <*> traverseExpr f y <*> traverseExpr f z
  foldExpr     f (x, y, z) = foldExpr f x `mappend` foldExpr f y `mappend` foldExpr f z

instance (ExprLike a, ExprLike b, ExprLike c, ExprLike d) => ExprLike (a, b, c, d) where
  mapExpr      f (x, y, z, w) = (mapExpr f x, mapExpr f y, mapExpr f z, mapExpr f w)
  traverseExpr f (x, y, z, w) = (,,,) <$> traverseExpr f x <*> traverseExpr f y <*> traverseExpr f z <*> traverseExpr f w
  foldExpr     f (x, y, z, w) = foldExpr f x `mappend` foldExpr f y `mappend` foldExpr f z `mappend` foldExpr f w

-- Interesting instances
---------------------------------------------------------------------------

instance ExprLike Expr where
  mapExpr f e0 = case e0 of
     Ident{}                 -> f $ e0
     Lit{}                   -> f $ e0
     QuestionMark{}          -> f $ e0
     Underscore{}            -> f $ e0
     RawApp r es             -> f $ RawApp r               $ mapE es
     App r e es              -> f $ App r       (mapE e)   $ mapE es
     OpApp r q ns es         -> f $ OpApp r q ns           $ mapE es
     WithApp r e es          -> f $ WithApp r   (mapE e)   $ mapE es
     HiddenArg r e           -> f $ HiddenArg r            $ mapE e
     InstanceArg r e         -> f $ InstanceArg r          $ mapE e
     Lam r bs e              -> f $ Lam r       (mapE bs)  $ mapE e
     AbsurdLam{}             -> f $ e0
     ExtendedLam r e cs      -> f $ ExtendedLam r e             $ mapE cs
     Fun r a b               -> f $ Fun r     (mapE <$> a)      $ mapE b
     Pi tel e                -> f $ Pi          (mapE tel)      $ mapE e
     Rec kwr r es            -> f $ Rec kwr r                   $ mapE es
     RecUpdate k r e es      -> f $ RecUpdate k r (mapE e)      $ mapE es
     RecWhere kwr r es       -> f $ RecWhere kwr r              $ mapE es
     RecUpdateWhere k r e es -> f $ RecUpdateWhere k r (mapE e) $ mapE es
     Let r ds e              -> f $ Let r       (mapE ds)       $ mapE e
     Paren r e               -> f $ Paren r                     $ mapE e
     IdiomBrackets r es      -> f $ IdiomBrackets r             $ mapE es
     DoBlock r ss            -> f $ DoBlock r                   $ mapE ss
     Absurd{}                -> f $ e0
     As r x e                -> f $ As r x                 $ mapE e
     Dot r e                 -> f $ Dot r                  $ mapE e
     DoubleDot r e           -> f $ DoubleDot r            $ mapE e
     Tactic r e              -> f $ Tactic r     (mapE e)
     Quote{}                 -> f $ e0
     QuoteTerm{}             -> f $ e0
     Unquote{}               -> f $ e0
     DontCare e              -> f $ DontCare               $ mapE e
     Equal{}                 -> f $ e0
     Ellipsis{}              -> f $ e0
     Generalized e           -> f $ Generalized            $ mapE e
     KnownIdent{}            -> f $ e0
     KnownOpApp nk r q ns es -> f $ KnownOpApp nk r q ns   $ mapE es
   where
     mapE :: ExprLike e => e -> e
     mapE = mapExpr f

  foldExpr     = __IMPOSSIBLE__
  traverseExpr = __IMPOSSIBLE__

instance ExprLike FieldAssignment where
  mapExpr      f (FieldAssignment x e) = FieldAssignment x (mapExpr f e)
  traverseExpr f (FieldAssignment x e) = (\e' -> FieldAssignment x e') <$> traverseExpr f e
  foldExpr     f (FieldAssignment _ e) = foldExpr f e

instance ExprLike ModuleAssignment where
  mapExpr      f (ModuleAssignment m es i) = ModuleAssignment m (mapExpr f es) i
  traverseExpr f (ModuleAssignment m es i) = (\es' -> ModuleAssignment m es' i) <$> traverseExpr f es
  foldExpr     f (ModuleAssignment _ es _) = foldExpr f es

instance ExprLike a => ExprLike (OpApp a) where
  mapExpr f = \case
     SyntaxBindingLambda r bs e -> SyntaxBindingLambda r (mapE bs) $ mapE e
     Ordinary                 e -> Ordinary                        $ mapE e
   where
     mapE :: ExprLike e => e -> e
     mapE = mapExpr f
  foldExpr     = __IMPOSSIBLE__
  traverseExpr = __IMPOSSIBLE__

instance ExprLike LamBinding where
  mapExpr f = \case
     e@DomainFree{}-> e
     DomainFull bs -> DomainFull $ mapE bs
   where mapE e = mapExpr f e
  foldExpr     = __IMPOSSIBLE__
  traverseExpr = __IMPOSSIBLE__

instance ExprLike LHS where
  mapExpr f = \case
     LHS ps res wes -> LHS ps (mapE res) (mapE wes)
   where
     mapE :: ExprLike a => a -> a
     mapE = mapExpr f
  foldExpr     = __IMPOSSIBLE__
  traverseExpr = __IMPOSSIBLE__

instance (ExprLike qn, ExprLike e) => ExprLike (RewriteEqn' qn nm p e) where
  mapExpr f = \case
    Rewrite es    -> Rewrite (mapExpr f es)
    Invert qn pes -> Invert qn $ (fmap . fmap . fmap . mapExpr) f pes
    LeftLet pes   -> LeftLet $ (fmap . fmap . mapExpr) f pes
  foldExpr     = __IMPOSSIBLE__
  traverseExpr = __IMPOSSIBLE__

instance ExprLike LamClause where
  mapExpr f (LamClause ps rhs ca) = LamClause ps (mapExpr f rhs) ca
  foldExpr     = __IMPOSSIBLE__
  traverseExpr = __IMPOSSIBLE__

instance ExprLike DoStmt where
  mapExpr f (DoBind r p e cs) = DoBind r p (mapExpr f e) (mapExpr f cs)
  mapExpr f (DoThen e)        = DoThen (mapExpr f e)
  mapExpr f (DoLet r ds)      = DoLet r (mapExpr f ds)

  foldExpr     = __IMPOSSIBLE__
  traverseExpr = __IMPOSSIBLE__

instance ExprLike ModuleApplication where
  mapExpr f = \case
     SectionApp r bs x es -> SectionApp r (mapE bs) x $ mapE es
     e@RecordModuleInstance{} -> e
   where
     mapE :: ExprLike e => e -> e
     mapE = mapExpr f
  foldExpr     = __IMPOSSIBLE__
  traverseExpr = __IMPOSSIBLE__

instance ExprLike Declaration where
  mapExpr f = \case
     TypeSig ai t x e          -> TypeSig ai (mapE t) x (mapE e)
     FieldSig i t n e          -> FieldSig i (mapE t) n (mapE e)
     Field r fs                -> Field r                              $ map (mapExpr f) fs
     FunClause ai lhs rhs wh ca-> FunClause ai (mapE lhs) (mapE rhs) (mapE wh) ca
     DataSig r er x bs e       -> DataSig r er x (mapE bs)             $ mapE e
     DataDef r n bs cs         -> DataDef r n (mapE bs)                $ mapE cs
     Data r er n bs e cs       -> Data r er n (mapE bs) (mapE e)       $ mapE cs
     RecordSig r er ind bs e   -> RecordSig r er ind (mapE bs)         $ mapE e
     RecordDef r n dir tel ds  -> RecordDef r n dir (mapE tel)         $ mapE ds
     Record r er n dir tel e ds
                               -> Record r er n dir (mapE tel) (mapE e)
                                                                       $ mapE ds
     e@Infix{}                 -> e
     e@Syntax{}                -> e
     e@PatternSyn{}            -> e
     Mutual    r ds            -> Mutual    r                          $ mapE ds
     InterleavedMutual r ds    -> InterleavedMutual r                  $ mapE ds
     LoneConstructor r ds      -> LoneConstructor r                    $ mapE ds
     Abstract  r ds            -> Abstract  r                          $ mapE ds
     Private   r o ds          -> Private   r o                        $ mapE ds
     InstanceB r ds            -> InstanceB r                          $ mapE ds
     Macro     r ds            -> Macro     r                          $ mapE ds
     Postulate r ds            -> Postulate r                          $ mapE ds
     Primitive r ds            -> Primitive r                          $ mapE ds
     Generalize r ds           -> Generalize r                         $ mapE ds
     Opaque  r ds              -> Opaque r                             $ mapE ds
     e@Open{}                  -> e
     e@Import{}                -> e
     ModuleMacro r e n es op dir
                               -> ModuleMacro r e n (mapE es) op dir
     Module r e n tel ds       -> Module r e n (mapE tel)              $ mapE ds
     UnquoteDecl r x e         -> UnquoteDecl r x (mapE e)
     UnquoteDef r x e          -> UnquoteDef r x (mapE e)
     UnquoteData r x xs e      -> UnquoteData r x xs (mapE e)
     e@Pragma{}                -> e
     e@Unfolding{}             -> e
   where
     mapE :: ExprLike e => e -> e
     mapE = mapExpr f

  foldExpr     = __IMPOSSIBLE__
  traverseExpr = __IMPOSSIBLE__


{- Template

instance ExprLike a where
  mapExpr f = \case
    where mapE e = mapExpr f e
  foldExpr     = __IMPOSSIBLE__
  traverseExpr = __IMPOSSIBLE__

-}

-- Generic traversals for concrete declarations.
-- ========================================================================

class FoldDecl a where

  -- | Collect declarations and subdeclarations, transitively.
  -- Prefix-order tree traversal.
  foldDecl :: Monoid m => (Declaration -> m) -> a -> m

  default foldDecl :: (Monoid m, Foldable t, FoldDecl b, t b ~ a)
    => (Declaration -> m) -> a -> m
  foldDecl = foldMap . foldDecl

instance FoldDecl a => FoldDecl [a]
instance FoldDecl a => FoldDecl (List1 a)
instance FoldDecl a => FoldDecl (List2 a)
instance FoldDecl a => FoldDecl (WhereClause' a)

instance FoldDecl Declaration where
  foldDecl f d = f d <> case d of
    Private  _ _        ds  -> foldDecl f ds
    Abstract _          ds  -> foldDecl f ds
    InstanceB _         ds  -> foldDecl f ds
    InterleavedMutual _ ds  -> foldDecl f ds
    LoneConstructor _   ds  -> foldDecl f ds
    Mutual _            ds  -> foldDecl f ds
    Module _ _ _ _      ds  -> foldDecl f ds
    Macro _             ds  -> foldDecl f ds
    Record _ _ _ _ _ _  ds  -> foldDecl f ds
    RecordDef _ _ _ _   ds  -> foldDecl f ds
    TypeSig _ _ _ _         -> mempty
    FieldSig _ _ _ _        -> mempty
    Generalize _ _          -> mempty
    Field _ _               -> mempty
    FunClause _ _ _ wh _    -> foldDecl f wh
    DataSig _ _ _ _ _       -> mempty
    Data _ _ _ _ _ _        -> mempty
    DataDef _ _ _ _         -> mempty
    RecordSig _ _ _ _ _     -> mempty
    Infix _ _               -> mempty
    Syntax _ _              -> mempty
    PatternSyn _ _ _ _      -> mempty
    Postulate _ _           -> mempty
    Primitive _ _           -> mempty
    Open _ _ _              -> mempty
    Import _ _ _ _ _        -> mempty
    ModuleMacro _ _ _ _ _ _ -> mempty
    UnquoteDecl _ _ _       -> mempty
    UnquoteDef _ _ _        -> mempty
    UnquoteData _ _ _ _     -> mempty
    Pragma _                -> mempty
    Opaque _ ds             -> foldDecl f ds
    Unfolding _ _           -> mempty

class TraverseDecl a where

  -- | Update declarations and their subdeclarations.
  -- Prefix-order traversal: traverses subdeclarations of updated declaration.
  --
  preTraverseDecl :: Monad m => (Declaration -> m Declaration) -> a -> m a

  default preTraverseDecl :: (Monad m, Traversable t, TraverseDecl b, t b ~ a)
    => (Declaration -> m Declaration) -> a -> m a
  preTraverseDecl = traverse . preTraverseDecl

instance TraverseDecl a => TraverseDecl [a]
instance TraverseDecl a => TraverseDecl (List1 a)
instance TraverseDecl a => TraverseDecl (List2 a)
instance TraverseDecl a => TraverseDecl (WhereClause' a)

instance TraverseDecl Declaration where
  preTraverseDecl f d0 = do
    d <- f d0
    case d of
      Private  r o        ds     -> Private r o             <$> preTraverseDecl f ds
      Abstract r          ds     -> Abstract r              <$> preTraverseDecl f ds
      InstanceB r         ds     -> InstanceB r             <$> preTraverseDecl f ds
      InterleavedMutual r ds     -> InterleavedMutual r     <$> preTraverseDecl f ds
      LoneConstructor r   ds     -> LoneConstructor r       <$> preTraverseDecl f ds
      Mutual r            ds     -> Mutual r                <$> preTraverseDecl f ds
      Module r er n tel   ds     -> Module r er n tel       <$> preTraverseDecl f ds
      Macro r             ds     -> Macro r                 <$> preTraverseDecl f ds
      Opaque r ds                -> Opaque r                <$> preTraverseDecl f ds
      Record r er n dir tel t ds -> Record r er n dir tel t <$> preTraverseDecl f ds
      RecordDef r n dir tel   ds -> RecordDef r n dir tel   <$> preTraverseDecl f ds
      TypeSig _ _ _ _            -> return d
      FieldSig _ _ _ _           -> return d
      Generalize _ _             -> return d
      Field _ _                  -> return d
      FunClause ai lhs rhs wh ca -> preTraverseDecl f wh <&> \ wh' -> FunClause ai lhs rhs wh' ca
      DataSig _ _ _ _ _          -> return d
      Data _ _ _ _ _ _           -> return d
      DataDef _ _ _ _            -> return d
      RecordSig _ _ _ _ _        -> return d
      Infix _ _                  -> return d
      Syntax _ _                 -> return d
      PatternSyn _ _ _ _         -> return d
      Postulate _ _              -> return d
      Primitive _ _              -> return d
      Open _ _ _                 -> return d
      Import _ _ _ _ _           -> return d
      ModuleMacro _ _ _ _ _ _    -> return d
      UnquoteDecl _ _ _          -> return d
      UnquoteDef _ _ _           -> return d
      UnquoteData _ _ _ _        -> return d
      Pragma _                   -> return d
      Unfolding _ _              -> return d
