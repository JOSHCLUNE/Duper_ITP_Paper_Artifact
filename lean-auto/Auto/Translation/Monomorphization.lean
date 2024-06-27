import Lean
import Auto.Embedding.Lift
import Auto.Translation.Assumptions
import Auto.Translation.ReifM
import Auto.Translation.Inhabitation
import Auto.Lib.LevelExtra
import Auto.Lib.ExprExtra
import Auto.Lib.MonadUtils
import Auto.Lib.Containers
import Auto.Lib.MetaState
import Auto.Lib.MetaExtra
open Lean

initialize
  registerTraceClass `auto.mono
  registerTraceClass `auto.mono.match
  registerTraceClass `auto.mono.printLemmaInst
  registerTraceClass `auto.mono.printConstInst
  registerTraceClass `auto.mono.printResult

register_option auto.mono.saturationThreshold : Nat := {
  defValue := 250
  descr := "Threshold for number of potentially new lemma" ++
    " instances generated during the saturation loop of monomorphization"
}

register_option auto.mono.recordInstInst : Bool := {
  defValue := false
  descr := "Whether to record instances of constants with the `instance` attribute"
}

namespace Auto.Monomorphization
open Embedding

inductive CiHead where
  | fvar  : FVarId → CiHead
  | mvar  : MVarId → CiHead
  | const : Name → Array Level → CiHead
  deriving Inhabited, Hashable, BEq

def CiHead.ofExpr? : Expr → Option CiHead
| .fvar id => .some (.fvar id)
| .mvar id => .some (.mvar id)
| .const name lvls => .some (.const name ⟨lvls⟩)
| _ => .none

def CiHead.toExpr : CiHead → Expr
| .fvar id => .fvar id
| .mvar id => .mvar id
| .const name lvls => .const name lvls.data

/-- Ignore constant's levels -/
def CiHead.fingerPrint : CiHead → Expr
| .fvar id => .fvar id
| .mvar id => .mvar id
| .const name _ => .const name []

def CiHead.isConst : CiHead → Bool
| .fvar _ => false
| .mvar _ => false
| .const _ _ => true

def CiHead.isNamedConst (name : Name) : CiHead → Bool
| .fvar _ => false
| .mvar _ => false
| .const name' _ => name == name'

instance : ToMessageData CiHead where
  toMessageData (ch : CiHead) := m!"{ch.toExpr}"

def CiHead.inferType (ci : CiHead) : MetaM Expr := Meta.inferType ci.toExpr

def CiHead.isInstanceQuick (ci : CiHead) : MetaM Bool := do
  if let .const name _ := ci then
    if ← Meta.isInstance name then
      return true
  if (← Meta.isClass? (← ci.inferType)).isSome then
    return true
  return false

/-- **Remark**: This function assigns level mvars if necessary -/
def CiHead.equiv (ch₁ ch₂ : CiHead) : MetaM Bool :=
  match ch₁, ch₂ with
  | .fvar id₁, .fvar id₂ => pure (id₁ == id₂)
  | .mvar id₁, .mvar id₂ => pure (id₁ == id₂)
  | .const name₁ lvls₁, .const name₂ lvls₂ => do
    if name₁ != name₂ then
      return false
    if lvls₁.size != lvls₂.size then
      return false
    for (lvl₁, lvl₂) in lvls₁.zip lvls₂ do
      if !(← Meta.isLevelDefEq lvl₁ lvl₂) then
        return false
    return true
  | _, _ => pure false

/--
  If a constant `c` is of type `∀ (xs : αs), t`,
    then its valid instance will be `c` with all of its
    universe levels, dependent arguments and instance
    arguments instantiated.  So, we record the instantiation
    of universe levels and dependent arguments.

  As to monomorphization, we will not record instances of
    constants with `instance` attribute or whose type is
    a class.
-/
structure ConstInst where
  head       : CiHead
  /-
    · Instantiation of dependent arguments and instance arguments.
    · Note that the same head may have different dependent arguments
      under different circumstances. For example,
      `Funlike.coe : {F : Sort u_3} → {α : Sort u_2} → {β : (α → Sort u_1)} → [self : FunLike F α β] → F → (a : α) → β a`
      · For `β = id`, the argument `(a : α)` is a dependent argument
      · For `β = fun _ => γ`, the argument `(a : α)` is non-dependent
  -/
  argsInst   : Array Expr
  argsIdx    : Array Nat
  deriving Inhabited, Hashable, BEq

def ConstInst.fingerPrint (ci : ConstInst) := ci.head.fingerPrint

private def ConstInst.toMessageDataAux (ci : ConstInst) : MessageData :=
  let nArgsIdx := ci.argsIdx.size
  match nArgsIdx with
  | 0 => m!""
  | .succ _ =>
    let narg := ci.argsIdx[nArgsIdx - 1]?.getD 0 + 1
    let arr : Array (Option Expr) := Array.mk ((List.range narg).map (fun _ => .none))
    let arr := (ci.argsInst.zip ci.argsIdx).foldl (fun acc (arg, idx) => acc.setD idx (.some arg)) arr
    let arr := arr.map (fun e? => match e? with | .some e => m!" ({e})" | .none => m!" _")
    MessageData.intercalate "" arr.data

instance : ToMessageData ConstInst where
  toMessageData ci := m!"ConstInst ⦗⦗ {ci.head}{ci.toMessageDataAux} ⦘⦘"

/--
  **Remark**: This function assigns metavariables if necessary,
    but its only usage in this file is under `Meta.withNewMCtxDepth`
  Note that since `ci₁, ci₂` are both `ConstInst`, they does not
    contain loose bound variables
-/
def ConstInst.equiv (ci₁ ci₂ : ConstInst) : MetaM Bool := do
  let ⟨head₁, argsInst₁, idx₁⟩ := ci₁
  let ⟨head₂, argsInst₂, idx₂⟩ := ci₂
  if head₁.fingerPrint != head₂.fingerPrint then
    throwError "ConstInst.equiv :: {ci₁.head} and {ci₂.head} have different fingerprints"
  if !(← head₁.equiv head₂) then
    return false
  if argsInst₁.size != argsInst₂.size || idx₁ != idx₂ then
    return false
  for (arg₁, arg₂) in argsInst₁.zip argsInst₂ do
    if !(← Meta.isDefEq arg₁ arg₂) then
      return false
  return true

/--
  **Remark**:
  · This function assigns metavariables if necessary
  · Runs in `MetaM`, so `e` should not have loose bound variables
-/
def ConstInst.matchExpr (e : Expr) (ci : ConstInst) : MetaM Bool := do
  let fn := e.getAppFn
  let .some ch := CiHead.ofExpr? fn
    | return false
  if !(← ch.equiv ci.head) then
    return false
  let argsIdx := ci.argsIdx
  if argsIdx.size != ci.argsInst.size then
    throwError "ConstInst.matchExpr :: Unexpected error"
  let args := e.getAppArgs
  for (idx, ciarg) in argsIdx.zip ci.argsInst do
    let .some arg := args[idx]?
      | return false
    if !(← Meta.isDefEq arg ciarg) then
      return false
  return true

/-
  Given an hypothesis `t`, we will traverse the hypothesis to find
    instances of polymorphic constants
  · Binders of the hypothesis are introduced as fvars, these fvars are
    recorded in `bvars`
  · `param` records universe level parameters of the hypothesis are
  So, the criterion that an expression `e` is a valid instance is that
  · All dependent arguments and instance arguments are applied
  · The head does not contain expressions in `bvars`
  · Dependent arguments does not contains expressions in `bvars`
  · The expression does not contain level parameters in `params`
-/
def ConstInst.ofExpr? (params : Array Name) (bvars : Array Expr) (e : Expr) : MetaM (Option ConstInst) := do
  let paramSet := HashSet.empty.insertMany params
  let bvarSet := HashSet.empty.insertMany bvars
  let fn := e.getAppFn
  -- If the head contains bound variable, then this is not
  --   a valid instance
  if let .some _ := fn.find? (fun e => bvarSet.contains e) then
    return .none
  let args := e.getAppArgs
  let .some head := CiHead.ofExpr? fn
    | return .none
  -- `e` should not have bound parameters
  if let .some _ := Expr.findParam? (fun n => paramSet.contains n) e then
    return .none
  -- Do not record instances of a constant with attribute `instance`
  if (← head.isInstanceQuick) && !(auto.mono.recordInstInst.get (← getOptions)) then
    return .none
  let mut headType ← head.inferType
  let mut argsIdx := #[]
  let mut argsInst := #[]
  -- Check that all dependent and instance arguments are instantiated
  for (arg, idx) in args.zipWithIndex do
    headType ← Core.betaReduce headType
    let .forallE _ ty body bi := headType
      | throwError "ConstInst.ofExpr? :: {headType} is not a `∀`"
    if let some _ := ty.find? (fun e => bvarSet.contains e) then
      return .none
    if body.hasLooseBVar 0 || bi == .instImplicit then
      if let some _ := arg.find? (fun e => bvarSet.contains e) then
        return .none
      argsIdx := argsIdx.push idx
      argsInst := argsInst.push arg
    headType := body.instantiate1 arg
  headType ← Core.betaReduce headType
  if (Expr.depArgs headType).size != 0 || (Expr.instArgs headType).size != 0 then
    return .none
  return .some ⟨head, argsInst, argsIdx⟩

private def ConstInst.toExprAux (args : List (Option Expr))
  (tys : List (Name × Expr × BinderInfo)) (e ty : Expr) : Option Expr :=
  match args with
  | .nil =>
    Option.some <| Prod.fst <| tys.foldl (fun (e, idx) (name, bty, bi) =>
      (Expr.lam name bty e bi, .succ idx)) (e, 0)
  | .none :: args' =>
    match ty with
    | .forallE name bty body bi =>
      let bvar := .bvar tys.length
      toExprAux args' ((name, bty, bi) :: tys) (.app e bvar) (body.instantiate1 bvar)
    | _ => .none
  | .some arg :: args' =>
    match ty with
    | .forallE _ _ body _ =>
      toExprAux args' tys (.app e arg) (body.instantiate1 arg)
    | _ => .none

def ConstInst.toExpr (ci : ConstInst) : MetaM Expr := do
  let type ← instantiateMVars (← ci.head.inferType)
  let nargs := (Nat.succ <$> ci.argsIdx[ci.argsIdx.size - 1]?).getD 0
  let mut args : Array (Option Expr) := (Array.mk (List.range nargs)).map (fun n => .none)
  for (arg, idx) in ci.argsInst.zip ci.argsIdx do
    args := args.setD idx (.some arg)
  let .some ret := ConstInst.toExprAux args.data [] ci.head.toExpr type
    | throwError "ConstInst.toExpr :: Unexpected error"
  return ret

/--
  Precondition : `.some ci == ← ConstInst.ofExpr? e`
  Returns the list of non-dependent arguments in `e.getAppArgs`
-/
def ConstInst.getOtherArgs (ci : ConstInst) (e : Expr) : CoreM (Array Expr) := do
  let mut args := e.getAppArgs.map Option.some
  for idx in ci.argsIdx do
    args := args.setD idx .none
  let mut ret := #[]
  for arg? in args do
    if let .some arg := arg? then
      ret := ret.push arg
  return ret

private partial def collectConstInsts (params : Array Name) (bvars : Array Expr) : Expr → MetaM (Array ConstInst)
| e@(.const _ _) => processOther params e
| e@(.fvar _) => processOther params e
| e@(.mvar _) => processOther params e
| e@(.app ..) => do
  let fn := e.getAppFn
  let args := e.getAppArgs
  let insts := (← (args.push fn).mapM (collectConstInsts params bvars)).concatMap id
  match ← ConstInst.ofExpr? params bvars e with
  | .some ci => return insts.push ci
  | .none => return insts
| .lam name ty body bi => Meta.withLocalDecl name bi ty fun x => do
  let insts ← collectConstInsts params (bvars.push x) (body.instantiate1 x)
  -- Do not look into instance binders
  if bi.isInstImplicit then
    return insts
  else
    return insts ++ (← collectConstInsts params bvars ty)
| .forallE name ty body bi => Meta.withLocalDecl name bi ty fun x => do
  let insts ← collectConstInsts params (bvars.push x) (body.instantiate1 x)
  -- Do not look into instance binders
  if bi.isInstImplicit then
    return insts
  else
    return insts ++ (← collectConstInsts params bvars ty)
| .letE .. => throwError "collectConstInsts :: Let-expressions should have been reduced"
| .mdata .. => throwError "collectConstInsts :: mdata should have been consumed"
| .proj .. => throwError "collectConstInsts :: Projections should have been turned into ordinary expressions"
| _ => return #[]
where processOther (params : Array Name) (e : Expr) : MetaM (Array ConstInst) := do
  match ← ConstInst.ofExpr? params bvars e with
  | .some ci => return #[ci]
  | .none => return #[]

/-- Array of instances of a polymorphic constant -/
abbrev ConstInsts := Array ConstInst

/--
  Given an array `cis` and a potentially new instance `ci`
  · If `ci` is new, add it to `ConstInsts` and return `true`
  · If `ci` is not new, return an element of the original `ConstInsts`
    which is definitionally equal to `ci`
-/
def ConstInsts.canonicalize? (cis : ConstInsts) (ci : ConstInst) : MetaM (Option ConstInst) := do
  for ci' in cis do
    if ← Meta.withNewMCtxDepth (ci'.equiv ci) then
      return .some ci'
  return .none

/--
  Given an MLemmaInst `mi` and a subexpressions `e` of `mi.type`,
    try to match `e` and the subexpressions of `e` against `ci`.
  This function is used by `LemmaInst.matchConstInst` only
-/
private partial def MLemmaInst.matchConstInst (ci : ConstInst) (mi : MLemmaInst) : Expr → MetaM (HashSet LemmaInst)
| .bvar _ => throwError "MLemmaInst.matchConstInst :: Loose bound variable"
| e@(.app ..) => do
  let fn := e.getAppFn
  let args := e.getAppArgs
  let mut ret ← MLemmaInst.matchConstInst ci mi fn
  for arg in args do
    ret := mergeHashSet ret (← MLemmaInst.matchConstInst ci mi arg)
  let s ← saveState
  if (← ci.matchExpr e) then
    ret := ret.insert (← LemmaInst.ofMLemmaInst mi)
  restoreState s
  return ret
| e@(.forallE ..) => Meta.forallTelescope e fun xs body => do
    let mut ret ← MLemmaInst.matchConstInst ci mi body
    for x in xs do
      let .fvar id := x
        | throwError "MLemmaInst.matchConstInst :: Unexpected error"
      let type ← id.getType
      ret := mergeHashSet ret (← MLemmaInst.matchConstInst ci mi type)
    return ret
| .lam name ty body bi => Meta.withLocalDecl name bi ty fun x => do
    let tyInst ← MLemmaInst.matchConstInst ci mi ty
    let bodyInst ← MLemmaInst.matchConstInst ci mi (body.instantiate1 x)
    return mergeHashSet tyInst bodyInst
| .letE .. => throwError "MLemmaInst.matchConstInst :: Let-expressions should have been reduced"
| .mdata .. => throwError "MLemmaInst.matchConstInst :: mdata should have been consumed"
| .proj .. => throwError "MLemmaInst.matchConstInst :: Projections should have been turned into ordinary expressions"
| _ => return HashSet.empty

/-- Given a LemmaInst `li` and a ConstInst `ci`, try to match all subexpressions of `li` against `ci` -/
def LemmaInst.matchConstInst (ci : ConstInst) (li : LemmaInst) : MetaM (HashSet LemmaInst) :=
  Meta.withNewMCtxDepth do
    let (lmvars, mvars, mi) ← MLemmaInst.ofLemmaInst li
    if lmvars.size == 0 && mvars.size == 0 then
      return HashSet.empty
    MLemmaInst.matchConstInst ci mi mi.type

/--
  Test whether a lemma is type monomorphic && universe monomorphic
    By universe monomorphic we mean `lem.params = #[]`
  We also require that all instance arguments (argument whose type
    is a class) are instantiated. If all dependent arguments are
    instantiated, but some instance arguments are not instantiated,
    we will try to synthesize the instance arguments
-/
def LemmaInst.monomorphic? (li : LemmaInst) : MetaM (Option LemmaInst) := do
  if li.params.size != 0 then
    return .none
  if !(← Expr.isMonomorphicFact li.type) then
    return .none
  Meta.withNewMCtxDepth do
    let (_, mvars, mi) ← MLemmaInst.ofLemmaInst li
    for mvar in mvars do
      let mvarTy ← instantiateMVars (← Meta.inferType mvar)
      if let .some _ ← Meta.isClass? mvarTy then
        let .some inst ← Meta.trySynthInstance mvarTy
          | return .none
        match mvar with
        | .mvar id => id.assign inst
        | _ => throwError "LemmaInst.monomorphic? :: Unexpected error"
    LemmaInst.ofMLemmaInst mi

/-
  Monomorphization works as follows:
  (1) Compute the number of `∀` binders for each input assumption.
      They form the initial elements of `liArr`
  (2) Scan through all assumptions to find subterms that are
      valid instances of constants (dependent arguments fully
      instantiated). They form the initial elements of `ciMap`
      and `activeCi`
  (3) Repeat:
      · Dequeue an element `(name, n)` from `activeCi`
      · For each element `ais : LemmaInsts` in `liArr`,
        for each expression `e` in `ais`, traverse `e` to
        find applications `app := name ...` of constant `name`.
        Try unifying `app` with `ciMap[name][n].snd`.
        If we get a new instance `i` of an assumption (which means
        that its `type` is not defeq to any existing ones in `ais`)
        · We add `i` to `ais`.
        · We traverse `i` to collect instances of constants.
          If we find an instance `ci` of constant `name'`, we
          first look at `ciMap[name']` to see whether it's
          a new instance. If it's new, we add it to `ciMap`
          and `activeCi`.
-/
structure State where
  -- The `Expr` is the fingerprint of the `ConstInst`
  ciMap    : HashMap Expr ConstInsts := {}
  -- The `Expr` is the fingerprint of the `ConstInst`
  activeCi : Std.Queue (Expr × Nat)  := Std.Queue.empty
  -- During initialization, we supply an array `lemmas` of lemmas
  --   `liArr[i]` are instances of `lemmas[i]`.
  lisArr    : Array LemmaInsts       := #[]

abbrev MonoM := StateRefT State MetaM

#genMonadState MonoM

/-
  Returns:
  1. Whether canonicalization is successful / Whether the constant is not new
  2. `(ciMap.find? ci.name).getD #[]`
  3. Canonicalized ConstInst
-/
def CiMap.canonicalize? (ciMap : HashMap Expr ConstInsts) (ci : ConstInst) :
  MetaM (Bool × ConstInsts × ConstInst) := do
  match ciMap.find? ci.fingerPrint with
  | .some insts =>
    match ← insts.canonicalize? ci with
    | .some ci' => return (true, insts, ci')
    | .none => return (false, insts, ci)
  | .none => return (false, #[], ci)

/--
  Process a potentially new ConstInst. If it's new, return its index
    in the corresponding `ConstInsts` array. If it's not new, return `.none`.
-/
def processConstInst (ci : ConstInst) : MonoM Unit := do
  let (old?, insts, ci) ← CiMap.canonicalize? (← getCiMap) ci
  if old? then
    return
  trace[auto.mono.printConstInst] "New {ci}"
  setCiMap ((← getCiMap).insert ci.fingerPrint (insts.push ci))
  -- Do not match against ConstInsts that do not have dependent or
  --   instance arguments
  if ci.argsIdx.size == 0 then
    return
  -- Do not match against `=` and `∃`
  -- If some polymorphic argument of the a theorem only occurs
  --   as the first argument of `=` or `∃`, the theorem is probably
  --   implied by the axioms of higher order logic, e.g.
  -- `Eq.trans : ∀ {α} (x y z : α), x = y → y = z → x = z`
  if ci.head.isNamedConst ``Exists || ci.head.isNamedConst ``Eq then
    return
  -- Insert `ci` into `activeCi` so that we can later match on it
  setActiveCi ((← getActiveCi).enqueue (ci.fingerPrint, insts.size))

def initializeMonoM (lemmas : Array Lemma) : MonoM Unit := do
  let lemmaInsts ← liftM <| lemmas.mapM (fun lem => do
    let li ← LemmaInst.ofLemmaHOL lem
    trace[auto.mono.printLemmaInst] "New {li}"
    return li)
  let lemmaInsts := lemmaInsts.map (fun x => #[x])
  setLisArr lemmaInsts
  for lem in lemmas do
    let cis ← collectConstInsts lem.params #[] lem.type
    for ci in cis do
      processConstInst ci

def dequeueActiveCi? : MonoM (Option (Expr × Nat)) := do
  match (← getActiveCi).dequeue? with
  | .some (elem, ci') =>
    setActiveCi ci'
    return .some elem
  | .none => return .none

def lookupActiveCi! (fgp : Expr) (idx : Nat) : MonoM ConstInst := do
  let .some cis := (← getCiMap).find? fgp
    | throwError "lookupActiveCi :: Unknown CiHead {fgp}"
  let .some ci := cis[idx]?
    | throwError "lookupActiveCi :: Index {idx} out of bound"
  return ci

def saturationThresholdReached? (cnt : Nat) : CoreM Bool := do
  let threshold := auto.mono.saturationThreshold.get (← getOptions)
  if cnt > threshold then
    trace[auto.mono] "Monomorphization saturation :: Threshold {threshold} reached"
    return true
  else
    return false

def saturate : MonoM Unit := do
  let mut cnt := 0
  while true do
    cnt := cnt + 1
    if (← saturationThresholdReached? cnt) then
      return
    match ← dequeueActiveCi? with
    | .some (name, cisIdx) =>
      let ci ← lookupActiveCi! name cisIdx
      let lisArr ← getLisArr
      trace[auto.mono.match] "Matching against {ci}"
      for (lis, idx) in lisArr.zipWithIndex do
        cnt := cnt + 1
        let mut newLis := lis
        for li in lis do
          cnt := cnt + 1
          let matchLis := (← LemmaInst.matchConstInst ci li).toArray
          for matchLi in matchLis do
            -- `matchLi` is a result of matching a subterm of `li` against `ci`
            cnt := cnt + 1
            if (← saturationThresholdReached? cnt) then
              return
            let new? ← newLis.newInst? matchLi
            -- A new instance of an assumption
            if new? then
              trace[auto.mono.printLemmaInst] "New {matchLi}"
              newLis := newLis.push matchLi
              let newCis ← collectConstInsts matchLi.params #[] matchLi.type
              for newCi in newCis do
                processConstInst newCi
        setLisArr ((← getLisArr).set! idx newLis)
    | .none =>
      trace[auto.mono] "Monomorphization Saturated after {cnt} small steps"
      return

/-- Remove non-monomorphic lemma instances -/
def postprocessSaturate : MonoM Unit := do
  let lisArr ← getLisArr
  let lisArr ← liftM <| lisArr.mapM (fun lis => lis.filterMapM LemmaInst.monomorphic?)
  -- Since typeclasses might have been instantiated, we need to collectConstInst again
  for li in lisArr.concatMap id do
    let newCis ← collectConstInsts li.params #[] li.type
    for newCi in newCis do
      processConstInst newCi
  setLisArr lisArr

/-- Collect inductive types -/
def collectMonoMutInds : MonoM (Array (Array SimpleIndVal)) := do
  let cis := (Array.mk ((← getCiMap).toList.map Prod.snd)).concatMap id
  let citys ← cis.mapM (fun ci => do
    let cie ← ci.toExpr
    let ty ← Meta.inferType cie
    return Expr.eraseMData ty)
  let minds ← collectExprsSimpleInduct citys
  let cis ← (minds.concatMap id).mapM (fun ⟨_, type, ctors, projs⟩ => do
    let cis₁ ← collectConstInsts #[] #[] type
    let cis₂ ← ctors.mapM (fun (val, ty) => do
      let cis₁ ← collectConstInsts #[] #[] val
      let cis₂ ← collectConstInsts #[] #[] ty
      return cis₁ ++ cis₂)
    let projs := (match projs with | .some projs => projs | .none => #[])
    let cis₃ ← projs.mapM (fun e => collectConstInsts #[] #[] e)
    return cis₁ ++ cis₂.concatMap id ++ cis₃.concatMap id)
  let _ ← (cis.concatMap id).mapM processConstInst
  return minds

namespace FVarRep

  structure State where
    bfvars   : Array FVarId             := #[]
    ffvars   : Array FVarId             := #[]
    exprMap  : HashMap Expr FVarId      := {}
    ciMap    : HashMap Expr ConstInsts
    ciIdMap  : HashMap ConstInst FVarId := {}
    -- Canonicalization map for types
    tyCanMap : HashMap Expr Expr        := {}

  abbrev FVarRepM := StateRefT State MetaState.MetaStateM

  #genMonadState FVarRepM

  /-- Similar to `Monomorphization.processConstInst` -/
  def processConstInst (ci : ConstInst) : FVarRepM Unit := do
    let (old?, insts, ci) ← MetaState.runMetaM <| CiMap.canonicalize? (← getCiMap) ci
    if old? then
      return
    trace[auto.mono.printConstInst] "New {ci}"
    setCiMap ((← getCiMap).insert ci.fingerPrint (insts.push ci))

  def processTypeAux : Expr → FVarRepM Unit
  | .forallE _ ty body _ => do
    if body.hasLooseBVar 0 then
      return
    processTypeAux ty
    processTypeAux body
  | e => do
    let e := Expr.eraseMData e
    if (← getTyCanMap).contains e then
      return
    for (e', ec) in (← getTyCanMap).toList do
      if ← MetaState.isDefEqRigid e e' then
        setTyCanMap ((← getTyCanMap).insert e ec)
        return
    setTyCanMap ((← getTyCanMap).insert e e)

  def processType (e : Expr) : FVarRepM Unit := do
    let e ← MetaState.runMetaM <| prepReduceExpr e
    processTypeAux e

  def ConstInst2FVarId (ci : ConstInst) : FVarRepM FVarId := do
    let ciMap ← FVarRep.getCiMap
    let ci ← MetaState.runMetaM (do
      match ← CiMap.canonicalize? ciMap ci with
      | (true, _, ci') => return ci'
      | _ => throwError "ConstInst2FVarId :: Cannot find canonicalized instance of {ci}")
    let ciIdMap ← FVarRep.getCiIdMap
    match ciIdMap.find? ci with
    | .some fid => return fid
    | .none => do
      let userName := (`cifvar).appendIndexAfter (← getCiIdMap).size
      let cie ← MetaState.runMetaM ci.toExpr
      let city ← instantiateMVars (← MetaState.inferType cie)
      processType city
      let fvarId ← MetaState.withLetDecl userName city cie .default
      setCiIdMap ((← getCiIdMap).insert ci fvarId)
      setFfvars ((← getFfvars).push fvarId)
      return fvarId

  def UnknownExpr2FVarId (e : Expr) : FVarRepM FVarId := do
    trace[auto.mono] "Do not know how to deal with expression {e}. Turning it into free variable ..."
    for (e', fid) in (← getExprMap).toList do
      if ← MetaState.isDefEqRigid e e' then
        return fid
    let userName := (`exfvar).appendIndexAfter (← getExprMap).size
    let ety ← instantiateMVars (← MetaState.inferType e)
    processType ety
    let fvarId ← MetaState.withLetDecl userName ety e .default
    setExprMap ((← getExprMap).insert e fvarId)
    setFfvars ((← getFfvars).push fvarId)
    return fvarId

  /-- Since we're now dealing with monomorphized lemmas, there are no bound level parameters -/
  partial def replacePolyWithFVar : Expr → FVarRepM Expr
  | .lam name ty body binfo => do
    processType ty
    let fvarId ← MetaState.withLocalDecl name binfo ty .default
    setBfvars ((← getBfvars).push fvarId)
    let b' ← replacePolyWithFVar (body.instantiate1 (.fvar fvarId))
    MetaState.runMetaM <| Meta.mkLambdaFVars #[.fvar fvarId] b'
  -- Turns `∀` into `Embedding.forallF`, `→` into `Embedding.ImpF`
  | .forallE name ty body binfo => do
    let tysort ← MetaState.runMetaM (do Expr.normalizeType (← Meta.inferType ty))
    let .sort tylvl := tysort
      | throwError "replacePolyWithFVar :: {tysort} is not a sort"
    processType ty
    let fvarId ← MetaState.withLocalDecl name binfo ty .default
    setBfvars ((← getBfvars).push fvarId)
    let body' := body.instantiate1 (.fvar fvarId)
    let bodysort ← MetaState.runMetaM <| do Expr.normalizeType (← Meta.inferType body')
    let .sort bodylvl := bodysort
      | throwError "replacePolyWithFVars :: Unexpected error"
    let bodyrep ← replacePolyWithFVar body'
    if body.hasLooseBVar 0 ∨
        !(← MetaState.isLevelDefEqRigid tylvl .zero) ∨
        !(← MetaState.isLevelDefEqRigid bodylvl .zero) then
      let forallFun := Expr.app (.const ``forallF [tylvl, bodylvl]) ty
      addForallImpFInst forallFun
      let forallFunId ← replacePolyWithFVar forallFun
      return .app forallFunId (← MetaState.runMetaM <| Meta.mkLambdaFVars #[.fvar fvarId] bodyrep)
    else
      let impFun := Expr.const ``ImpF [.zero, .zero]
      addForallImpFInst impFun
      return .app (.app impFun (← replacePolyWithFVar ty)) bodyrep
  | e@(.app ..) => do
    -- Head is bvar
    if let .fvar id := e.getAppFn then
      if ((← getBfvars).contains id) then
        let ciArgs ← e.getAppArgs.mapM replacePolyWithFVar
        return mkAppN (.fvar id) ciArgs
    -- Head is fvar/mvar/const
    let bfexprs := (← getBfvars).map Expr.fvar
    if let .some ci ← MetaState.runMetaM (ConstInst.ofExpr? #[] bfexprs e) then
      let ciId ← ConstInst2FVarId ci
      let ciArgs ← ConstInst.getOtherArgs ci e
      let ciArgs ← ciArgs.mapM replacePolyWithFVar
      return mkAppN (.fvar ciId) ciArgs
    Expr.fvar <$> UnknownExpr2FVarId e
  | e@(.sort _) => return e
  | e@(.lit _) => return e
  | e => do
    if let .fvar id := e then
      if (← getBfvars).contains id then
        return .fvar id
    let bfexprs := (← getBfvars).map Expr.fvar
    if let .some ci ← MetaState.runMetaM (ConstInst.ofExpr? #[] bfexprs e) then
      let ciId ← ConstInst2FVarId ci
      return .fvar ciId
    Expr.fvar <$> UnknownExpr2FVarId e
  where addForallImpFInst (e : Expr) : FVarRepM Unit := do
    let bfexprs := (← getBfvars).map Expr.fvar
    match ← MetaState.runMetaM (ConstInst.ofExpr? #[] bfexprs e) with
    | .some ci => processConstInst ci
    | .none => trace[auto.mono] "Warning, {e} is not a valid instance of `forallF` or `ImpF`"

end FVarRep

/--
  Given `mvarId : ty`, create a fresh mvar `m` of type
    `monofact₁ → monofact₂ → ⋯ → monofactₙ → ty`
  and return `(m proof₁ proof₂ ⋯ proofₙ, m)`
-/
def intromono (lemmas : Array Lemma) (mvarId : MVarId) : MetaM MVarId := do
  let startTime ← IO.monoMsNow
  let monoMAction : MonoM Unit := (do
    initializeMonoM lemmas
    saturate
    postprocessSaturate
    trace[auto.mono] "Monomorphization took {(← IO.monoMsNow) - startTime}ms")
  let (_, monoSt) ← monoMAction.run {}
  let monoLemmas := monoSt.lisArr.concatMap id
  MetaState.runAtMetaM' (do
    let mut fids := #[]
    for ml in monoLemmas do
      let userName := (`monoLem).appendIndexAfter fids.size
      let fid ← MetaState.withLocalDecl userName .default ml.type .default
      fids := fids.push fid
    let type ← MetaState.runMetaM <| mvarId.getType
    let tag ← MetaState.runMetaM <| mvarId.getTag
    let mvar ← MetaState.runMetaM <| Meta.mkFreshExprSyntheticOpaqueMVar type.headBeta tag
    let newVal ← MetaState.runMetaM <| Meta.mkLambdaFVars (fids.map Expr.fvar) mvar
    let newVal := Lean.mkAppN newVal (monoLemmas.map (·.proof))
    mvarId.assign newVal
    return mvar.mvarId!)

def monomorphize (lemmas : Array Lemma) (inhFacts : Array Lemma) (k : Reif.State → MetaM α) : MetaM α := do
  let monoMAction : MonoM (Array (Array SimpleIndVal)) := (do
    let startTime ← IO.monoMsNow
    initializeMonoM lemmas
    saturate
    postprocessSaturate
    trace[auto.mono] "Monomorphization took {(← IO.monoMsNow) - startTime}ms"
    collectMonoMutInds)
  let (inductiveVals, monoSt) ← monoMAction.run {}
  -- Lemma instances
  let lis := monoSt.lisArr.concatMap id
  let fvarRepMFactAction : FVarRep.FVarRepM (Array UMonoFact) :=
    lis.mapM (fun li => do return ⟨li.proof, ← FVarRep.replacePolyWithFVar li.type⟩)
  let fvarRepMInductAction (ivals : Array (Array SimpleIndVal)) : FVarRep.FVarRepM (Array (Array SimpleIndVal)) :=
    ivals.mapM (fun svals => svals.mapM (fun ⟨name, type, ctors, projs⟩ => do
      FVarRep.processType type
      let ctors ← ctors.mapM (fun (val, ty) => do
        FVarRep.processType ty
        let val' ← FVarRep.replacePolyWithFVar val
        return (val', ty))
      let projs ← projs.mapM (fun arr => arr.mapM (fun e => do
        FVarRep.replacePolyWithFVar e))
      return ⟨name, type, ctors, projs⟩))
  let metaStateMAction : MetaState.MetaStateM (Array FVarId × Reif.State) := (do
    let (uvalids, s) ← fvarRepMFactAction.run { ciMap := monoSt.ciMap }
    for (proof, ty) in uvalids do
      trace[auto.mono.printResult] "Monomorphized :: {proof} : {ty}"
    let exlis := s.exprMap.toList.map (fun (e, id) => (id, e))
    let cilis ← s.ciIdMap.toList.mapM (fun (ci, id) => do return (id, ← MetaState.runMetaM ci.toExpr))
    let polyVal := HashMap.ofList (exlis ++ cilis)
    let tyCans := s.tyCanMap.toArray.map Prod.snd
    -- Inhabited types
    let startTime ← IO.monoMsNow
    let mut tyCanInhs := #[]
    for e in tyCans do
      if let .some inh ← MetaState.runMetaM <| Meta.withNewMCtxDepth <| Meta.trySynthInhabited e then
        tyCanInhs := tyCanInhs.push ⟨inh, e⟩
    let inhMatches ← MetaState.runMetaM (Inhabitation.inhFactMatchAtomTys inhFacts tyCans)
    let inhs := tyCanInhs ++ inhMatches
    trace[auto.mono] "Monomorphizing inhabitation facts took {(← IO.monoMsNow) - startTime}ms"
    -- Inductive types
    let startTime ← IO.monoMsNow
    trace[auto.mono] "Monomorphizing inductive types took {(← IO.monoMsNow) - startTime}ms"
    let (inductiveVals, s) ← (fvarRepMInductAction inductiveVals).run s
    return (s.ffvars, Reif.State.mk s.ffvars uvalids polyVal s.tyCanMap inhs inductiveVals none))
  MetaState.runWithIntroducedFVars metaStateMAction k

end Auto.Monomorphization
