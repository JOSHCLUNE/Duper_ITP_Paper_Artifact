import Auto.Lib.BoolExtra
import Auto.Lib.HEqExtra
import Auto.Lib.NatExtra
import Auto.Lib.ListExtra
import Auto.Lib.HList
import Auto.Lib.BinTree
import Std.Data.List.Lemmas

namespace Auto.Embedding

section generic

  @[reducible] def mapAt (pos : Nat) (f : Nat → Nat) (n : Nat) :=
    match pos.ble n with
    | true => f (n - pos) + pos
    | false => n

  theorem mapAt_id_eq_id (pos : Nat) : mapAt pos id = id := by
    apply funext; intros n;
    dsimp [mapAt]
    match h : pos.ble n with
    | true =>
      dsimp
      rw [Nat.sub_add_cancel (Nat.le_of_ble_eq_true h)]
    | false => rfl
  
  theorem mapAt_id_eq_id' (pos : Nat) : mapAt pos (fun x => x) = id :=
    mapAt_id_eq_id pos

  theorem mapAt_zero (f : Nat → Nat) : mapAt 0 f = f :=
    funext (fun n => match n with | 0 => rfl | _ + 1 => rfl)

  theorem mapAt_succ_zero (pos : Nat) (f : Nat → Nat) :
    mapAt (.succ pos) f 0 = 0 := rfl

  theorem mapAt_succ_succ (pos : Nat) (f : Nat → Nat) (n : Nat) :
    mapAt (.succ pos) f (.succ n) = .succ (mapAt pos f n) := by
    dsimp [mapAt, Nat.ble]
    match Nat.ble pos n with
    | true => dsimp; rw [Nat.succ_sub_succ]; rfl
    | false => rfl

  theorem mapAt_comp (pos : Nat) (g f : Nat → Nat) (n : Nat) :
    mapAt pos (fun x => g (f x)) n = mapAt pos g (mapAt pos f n) := by
    dsimp [mapAt]
    match h : Nat.ble pos n with
    | true =>
      dsimp;
      have hble : ∀ t, Nat.ble pos (t + pos) = true := by
        intro t; apply Nat.ble_eq_true_of_le;
        apply Nat.le_add_left
      rw [hble]; dsimp; rw [Nat.add_sub_cancel]
    | false =>
      dsimp; rw [h]
  
  @[reducible] def restoreAt {α} (pos : Nat) (restore : (Nat → α) → (Nat → α)) :=
    fun (lctx : Nat → α) (n : Nat) =>
      match pos.ble n with
      | true => restore (fun i => lctx (i + pos)) (n - pos)
      | false => lctx n

  theorem restoreAt_zero {α} (restore : (Nat → α) → (Nat → α)) :
    restoreAt 0 restore = restore := by
    apply funext; intro lctx; apply funext; intro n;
    cases n <;> rfl

  theorem restoreAt_succ_succ {α} (pos : Nat) (restore : (Nat → α) → (Nat → α))
    (lctx : Nat → α) (n : Nat) :
    restoreAt (.succ pos) restore lctx (.succ n) = restoreAt pos restore (fun n => lctx (.succ n)) n := by
    dsimp [restoreAt, Nat.ble]; rw [Nat.succ_sub_succ]; rfl

  theorem restoreAt_succ_succ_Fn {α} (pos : Nat)
    (restore : (Nat → α) → (Nat → α)) (lctx : Nat → α) :
    (fun n => restoreAt (.succ pos) restore lctx (.succ n)) = restoreAt pos restore (fun n => lctx (.succ n)) :=
    funext (fun n => restoreAt_succ_succ pos restore lctx n)

  def coPair {α} (f : Nat → Nat) (restore : (Nat → α) → (Nat → α)) :=
    ∀ (lctx : Nat → α) (n : Nat), (restore lctx) (f n) = lctx n
  
  def coPairAt {α} (f : Nat → Nat) (restore : (Nat → α) → (Nat → α)) :=
    ∀ (pos : Nat) (lctx : Nat → α) (n : Nat),
      (restoreAt pos restore lctx) (mapAt pos f n) = lctx n
  
  theorem coPairAt.ofcoPair (cp : coPair f restore) : coPairAt f restore := by
    intros pos lctx n;
    dsimp [restoreAt, mapAt]
    match h : pos.ble n with
    | true =>
      dsimp;
      have heq : Nat.ble pos (f (n - pos) + pos) = true := by
        apply Nat.ble_eq_true_of_le;
        apply Nat.le_add_left
      rw [heq]; dsimp
      rw [Nat.add_sub_assoc]; rw [Nat.sub_self]; dsimp
      rw [cp]; rw [Nat.sub_add_cancel (Nat.le_of_ble_eq_true h)]
      constructor
    | false => dsimp; rw [h]

  def contraPair {α} (f : Nat → Nat) (cstr : (Nat → α) → Prop) (restore : (Nat → α) → (Nat → α)) :=
    ∀ (lctx : Nat → α), cstr lctx → restore (lctx ∘ f) = lctx

  def contraPairAt {α} (f : Nat → Nat) (cstr : (Nat → α) → Prop) (restore : (Nat → α) → (Nat → α)) :=
    ∀ (pos : Nat) (lctx : Nat → α), cstr (fun n => lctx (n + pos)) → restoreAt pos restore (lctx ∘ (mapAt pos f)) = lctx

  theorem contraPairAt.ofContraPair (cp : contraPair f cstr restore) : contraPairAt f cstr restore := by
    intros pos lctx hcstr; apply funext; intro n
    dsimp [restoreAt, mapAt]
    match h : pos.ble n with
    | true =>
      dsimp;
      have hle : pos ≤ n := Nat.ble_eq ▸ h
      apply Eq.trans ?left (Eq.trans (congrFun (cp (fun n => lctx (n + pos)) hcstr) (n - pos)) ?right)
      case left =>
        apply congrFun; apply congrArg; apply funext; intro n
        have heq : Nat.ble pos (n + pos) = true := by
          apply Nat.ble_eq_true_of_le;
          apply Nat.le_add_left
        rw [heq]; dsimp; rw [Nat.add_sub_cancel]
      case right =>
        rw [Nat.sub_add_cancel hle]
    | false => rfl

  def restoreAtDep {α} {lctxty : α → Sort u}
    (pos : Nat) {restore : (Nat → α) → (Nat → α)}
    (restoreDep : ∀ {rty : Nat → α}, (∀ n, lctxty (rty n)) → ∀ n, lctxty (restore rty n))
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) (n : Nat) : lctxty (restoreAt pos restore rty n) := by
    dsimp [restoreAt]
    match Nat.ble pos n with
    | true  => exact (restoreDep (fun i => lctx (i + pos)) (n - pos))
    | false => exact (lctx n)

  theorem restoreAtDep_zero {α} {lctxty : α → Sort u}
    {restore : (Nat → α) → (Nat → α)}
    (restoreDep : ∀ {rty : Nat → α}, (∀ n, lctxty (rty n)) → ∀ n, lctxty (restore rty n))
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) :
    HEq (restoreAtDep 0 restoreDep lctx) (restoreDep (rty:=rty) lctx) := by
    apply HEq.funext; intros n; cases n <;> rfl

  theorem restoreAtDep_succ_succ {α} {lctxty : α → Sort u}
    (pos : Nat) {restore : (Nat → α) → (Nat → α)}
    (restoreDep : ∀ {rty : Nat → α}, (∀ n, lctxty (rty n)) → ∀ n, lctxty (restore rty n))
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) (n : Nat) :
    HEq (restoreAtDep (.succ pos) restoreDep lctx (.succ n)) (restoreAtDep pos restoreDep (fun n => lctx (.succ n)) n) := by
    dsimp [restoreAt, restoreAtDep, Nat.ble]; rw [Nat.succ_sub_succ]; rfl

  theorem restoreAtDep_succ_succ_Fn {α} {lctxty : α → Sort u}
    (pos : Nat) {restore : (Nat → α) → (Nat → α)}
    (restoreDep : ∀ {rty : Nat → α}, (∀ n, lctxty (rty n)) → ∀ n, lctxty (restore rty n))
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) :
    HEq (fun n => restoreAtDep (.succ pos) restoreDep lctx (.succ n)) (restoreAtDep pos restoreDep (fun n => lctx (.succ n))) :=
    HEq.funext _ _ (fun n => restoreAtDep_succ_succ pos restoreDep lctx n)

  def coPairDep {α} (lctxty : α → Sort u)
    (f : Nat → Nat) (restore : (Nat → α) → (Nat → α))
    (restoreDep : ∀ {rty : Nat → α}, (∀ n, lctxty (rty n)) → ∀ n, lctxty ((restore rty) n)) :=
    coPair f restore ∧
      ∀ {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) (n : Nat),
        HEq (@restoreDep rty lctx (f n)) (lctx n)

  def coPairDepAt {α} (lctxty : α → Sort u)
    (f : Nat → Nat) (restore : (Nat → α) → (Nat → α))
    (restoreDep : ∀ {rty : Nat → α}, (∀ n, lctxty (rty n)) → ∀ n, lctxty ((restore rty) n)) :=
    coPairAt f restore ∧
      ∀ (pos : Nat) {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) (n : Nat),
        HEq (restoreAtDep pos restoreDep (rty:=rty) lctx (mapAt pos f n)) (lctx n)

  theorem coPairDepAt.ofCoPairDep (cpd : coPairDep lctxty f restore restoreDep) :
    coPairDepAt lctxty f restore restoreDep := by
    apply And.intro
    case left => exact coPairAt.ofcoPair cpd.left
    case right =>
      intros pos rty lctx n
      dsimp [restoreAt, restoreAtDep, mapAt]
      match h : pos.ble n with
      | true =>
        dsimp;
        have heq : Nat.ble pos (f (n - pos) + pos) = true := by
          apply Nat.ble_eq_true_of_le;
          apply Nat.le_add_left
        have hle := Nat.le_of_ble_eq_true h
        rw [heq]; dsimp
        rw [Nat.add_sub_assoc .refl]; rw [Nat.sub_self]; dsimp
        apply HEq.trans (b:=lctx (n - pos + pos))
        case h₁ => apply cpd.right
        case h₂ => rw [Nat.sub_add_cancel hle]
      | false => dsimp; rw [h]

  def contraPairDep {α} (lctxty : α → Sort u)
    (f : Nat → Nat) (cstr : (Nat → α) → Prop) (restore : (Nat → α) → (Nat → α))
    (cstrDep : ∀ {rty : Nat → α}, (∀ n, lctxty (rty n)) → Prop)
    (restoreDep : ∀ {rty : Nat → α}, (∀ n, lctxty (rty n)) → ∀ n, lctxty ((restore rty) n)) :=
    contraPair f cstr restore ∧
      ∀ {rty : Nat → α}, cstr rty → ∀ (lctx : ∀ n, lctxty (rty n)), cstrDep lctx → HEq (@restoreDep (rty ∘ f) (fun n => lctx (f n))) lctx

  def contraPairDepAt {α} (lctxty : α → Sort u)
  (f : Nat → Nat) (cstr : (Nat → α) → Prop) (restore : (Nat → α) → (Nat → α))
  (cstrDep : ∀ {rty : Nat → α}, (∀ n, lctxty (rty n)) → Prop)
  (restoreDep : ∀ {rty : Nat → α}, (∀ n, lctxty (rty n)) → ∀ n, lctxty ((restore rty) n)) :=
    contraPairAt f cstr restore ∧
      ∀ (pos : Nat) {rty : Nat → α}, cstr (fun n => rty (n + pos)) → ∀ (lctx : ∀ n, lctxty (rty n)),
        cstrDep (fun n => lctx (n + pos)) → HEq (restoreAtDep pos restoreDep (rty:=rty ∘ (mapAt pos f)) (fun n => lctx (mapAt pos f n))) lctx

  theorem contraPairDep.ofContraPairDep (cpd : contraPairDep lctxty f cstr restore cstrDep restoreDep) :
    contraPairDepAt lctxty f cstr restore cstrDep restoreDep := by
    apply And.intro
    case left => exact contraPairAt.ofContraPair cpd.left
    case right =>
      intros pos rty hcstr lctx hcstrDep; apply HEq.funext; intro n
      dsimp [restoreAt, restoreAtDep, mapAt]
      match h : pos.ble n with
      | true =>
        dsimp;
        have hle : pos ≤ n := Nat.ble_eq ▸ h
        have hheq := cpd.right hcstr (fun n => lctx (n + pos)) hcstrDep
        have hheq := congr_fun_heq (x₁:=n-pos) (x₂:=n-pos) (by rw [cpd.left _ hcstr]) hheq rfl
        apply HEq.trans ?left (HEq.trans hheq ?right)
        case left =>
          have bleEq : ∀ n, Nat.ble pos (n + pos) = true := by
            intro n; apply Nat.ble_eq_true_of_le;
            apply Nat.le_add_left
          apply congr_hd_heq;
          case Hβ =>
            apply HEq.funext; intro n; apply heq_of_eq
            apply congrArg; apply congrFun; apply congrArg;
            apply funext; intro n; rw [bleEq]; dsimp; rw [Nat.add_sub_cancel]
          case h₁ =>
            apply congr_arg₂_heq (f:=@restoreDep);
            case H₁ =>
              apply funext; intro n; rw [bleEq]; dsimp; rw [Nat.add_sub_cancel]
            case H₂ =>
              apply HEq.funext; intro n; rw [bleEq]; dsimp; rw [Nat.add_sub_cancel]
          case h₂ => apply HEq.rfl
        case right =>
          rw [Nat.sub_add_cancel hle]
      | false => rfl

end generic


section push
  
  @[reducible] def pushLCtx (x : α) (lctx : Nat → α) (n : Nat) : α :=
    match n with
    | 0 => x
    | n' + 1 => lctx n'

  @[reducible] def pushLCtxAt (x : α) (pos : Nat) := restoreAt pos (pushLCtx x)

  theorem pushLCtxAt_zero (x : α) : pushLCtxAt x 0 = pushLCtx x := restoreAt_zero _

  theorem pushLCtxAt_lt (x : α) (pos : Nat) (n : Nat) (hlt : n < pos) : pushLCtxAt x pos lctx n = lctx n := by
    dsimp [pushLCtxAt, restoreAt]
    rw [show (pos.ble n = false) by (apply Nat.ble_eq_false_of_lt _ hlt)]

  theorem pushLCtxAt_eq (x : α) (pos : Nat) : pushLCtxAt x pos lctx pos = x := by
    dsimp [pushLCtxAt, restoreAt]
    rw [show (pos.ble pos = true) by (apply Nat.ble_eq_true_of_le; apply Nat.le_refl)]
    rw [Nat.sub_self]
  
  theorem pushLCtxAt_gt (x : α) (pos : Nat) (n : Nat) (hle : n > pos) : pushLCtxAt x pos lctx n = lctx n.pred := by
    dsimp [pushLCtxAt, restoreAt]
    rw [show (pos.ble n = true) by (apply Nat.ble_eq_true_of_le; apply Nat.le_of_lt hle)]
    dsimp [pushLCtx]; cases h : n - pos
    case zero =>
      have hge : pos ≥ n := Nat.le_of_sub_eq_zero h
      apply False.elim (Nat.not_le_of_lt hle hge)
    case succ _ =>
      dsimp; cases n
      case zero => cases hle
      case succ n =>
        have hle' := Nat.le_of_succ_le_succ hle
        rw [Nat.succ_sub hle'] at h; cases h
        rw [Nat.sub_add_cancel hle']; rfl

  theorem pushLCtxAt_succ_zero (x : α) (pos : Nat) (lctx : Nat → α) :
    pushLCtxAt x (.succ pos) lctx 0 = lctx 0 := rfl
  
  theorem pushLCtxAt_succ_succ (x : α) (pos : Nat) (lctx : Nat → α) (n : Nat) :
    pushLCtxAt x (.succ pos) lctx (.succ n) = pushLCtxAt x pos (fun n => lctx (.succ n)) n :=
    restoreAt_succ_succ _ _ _ _
  
  theorem pushLCtxAt_succ_succ_Fn (x : α) (pos : Nat) (lctx : Nat → α) :
    (fun n => pushLCtxAt x (.succ pos) lctx (.succ n)) = pushLCtxAt x pos (fun n => lctx (.succ n)) :=
    restoreAt_succ_succ_Fn _ _ _
  
  theorem pushLCtxAt_comm (f : α → β) (x : α) (pos : Nat) (lctx : Nat → α) (n : Nat) :
    f (pushLCtxAt x pos lctx n) = pushLCtxAt (f x) pos (f ∘ lctx) n := by
    dsimp [pushLCtxAt, restoreAt]
    match pos.ble n with
    | true =>
      match (n - pos) with
      | 0 => rfl
      | _ + 1 => rfl
    | false => rfl
  
  theorem pushLCtxAt_commFn (f : α → β) (x : α) (pos : Nat) (lctx : Nat → α) :
    (fun n => f (pushLCtxAt x pos lctx n)) = (fun n => pushLCtxAt (f x) pos (fun n => f (lctx n)) n) :=
    funext (pushLCtxAt_comm f x pos lctx)
  
  @[reducible] def pushLCtxDep {lctxty : α → Sort u} {xty : α} (x : lctxty xty)
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) (n : Nat) : lctxty (pushLCtx xty rty n) := by
    dsimp [pushLCtx]
    match n with
    | 0 => exact x
    | n' + 1 => exact (lctx n')

  theorem pushLCtxDep_heq
    {lctxty₁ : α₁ → Sort u} {ty₁ : α₁} (x₁ : lctxty₁ ty₁)
    (rty₁ : Nat → α₁) (lctx₁ : ∀ n, lctxty₁ (rty₁ n))
    {lctxty₂ : α₂ → Sort u} {ty₂ : α₂} (x₂ : lctxty₂ ty₂)
    (rty₂ : Nat → α₂) (lctx₂ : ∀ n, lctxty₂ (rty₂ n))
    (h₁ : α₁ = α₂) (h₂ : HEq lctxty₁ lctxty₂) (h₃ : HEq ty₁ ty₂)
    (h₄ : HEq x₁ x₂) (h₅ : HEq rty₁ rty₂) (h₆ : HEq lctx₁ lctx₂) :
    HEq (pushLCtxDep x₁ lctx₁) (pushLCtxDep x₂ lctx₂) := by
    cases h₁; cases h₂; cases h₃; cases h₄; cases h₅; cases h₆; apply HEq.refl

  theorem pushLCtxDep_substLCtx
    {lctxty : α → Sort u} {ty : α} (x : lctxty ty) 
    {rty₁ : Nat → α} (lctx₁ : ∀ n, lctxty (rty₁ n))
    {rty₂ : Nat → α} (lctx₂ : ∀ n, lctxty (rty₂ n))
    (h₁ : rty₁ = rty₂) (h₂ : HEq lctx₁ lctx₂) :
    HEq (pushLCtxDep x lctx₁) (pushLCtxDep x lctx₂) := by
    cases h₁; cases h₂; rfl

  theorem pushLCtxDep_substx
    {lctxty : α → Sort u}
    {ty₁ : α} (x₁ : lctxty ty₁) {ty₂ : α} (x₂ : lctxty ty₂)
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n))
    (h₁ : ty₁ = ty₂) (h₂ : HEq x₁ x₂) :
    HEq (pushLCtxDep x₁ lctx) (pushLCtxDep x₂ lctx) := by
    cases h₁; cases h₂; rfl

  def pushLCtxAtDep {lctxty : α → Sort u} {xty : α} (x : lctxty xty) (pos : Nat)
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) (n : Nat) : lctxty (pushLCtxAt xty pos rty n) :=
    restoreAtDep pos (pushLCtxDep x) lctx n
  
  theorem pushLCtxAtDep_heq
    {lctxty₁ : α₁ → Sort u} {ty₁ : α₁} (x₁ : lctxty₁ ty₁) (pos₁ : Nat)
    (rty₁ : Nat → α₁) (lctx₁ : ∀ n, lctxty₁ (rty₁ n))
    {lctxty₂ : α₂ → Sort u} {ty₂ : α₂} (x₂ : lctxty₂ ty₂) (pos₂ : Nat)
    (rty₂ : Nat → α₂) (lctx₂ : ∀ n, lctxty₂ (rty₂ n))
    (h₁ : α₁ = α₂) (h₂ : HEq lctxty₁ lctxty₂) (h₃ : HEq ty₁ ty₂) (h₄ : HEq x₁ x₂)
    (h₅ : pos₁ = pos₂) (h₆ : HEq rty₁ rty₂) (h₇ : HEq lctx₁ lctx₂) :
    HEq (pushLCtxAtDep x₁ pos₁ lctx₁) (pushLCtxAtDep x₂ pos₂ lctx₂) := by
    cases h₁; cases h₂; cases h₃; cases h₄; cases h₅; cases h₆; cases h₇; apply HEq.refl

  theorem pushLCtxAtDep_substLCtx
    {lctxty : α → Sort u} {ty : α} (x : lctxty ty) (pos : Nat)
    {rty₁ : Nat → α} (lctx₁ : ∀ n, lctxty (rty₁ n))
    {rty₂ : Nat → α} (lctx₂ : ∀ n, lctxty (rty₂ n))
    (h₁ : rty₁ = rty₂) (h₂ : HEq lctx₁ lctx₂) :
    HEq (pushLCtxAtDep x pos lctx₁) (pushLCtxAtDep x pos lctx₂) := by
    cases h₁; cases h₂; rfl

  theorem pushLCtxAtDep_substx
    {lctxty : α → Sort u}
    {ty₁ : α} (x₁ : lctxty ty₁) {ty₂ : α} (x₂ : lctxty ty₂) (pos : Nat)
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n))
    (h₁ : ty₁ = ty₂) (h₂ : HEq x₁ x₂) :
    HEq (pushLCtxAtDep x₁ pos lctx) (pushLCtxAtDep x₂ pos lctx) := by
    cases h₁; cases h₂; rfl

  theorem pushLCtxAtDep_zero {lctxty : α → Sort u} {xty : α} (x : lctxty xty)
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) :
    HEq (pushLCtxAtDep x 0 lctx) (pushLCtxDep x lctx) := restoreAtDep_zero _ _

  theorem pushLCtxAtDep_succ_zero {rty : Nat → α} {lctxty : α → Sort u}
    {xty : α} (x : lctxty xty) (pos : Nat) (lctx : ∀ n, lctxty (rty n)) :
    pushLCtxAtDep x (.succ pos) lctx 0 = lctx 0 := rfl
  
  theorem pushLCtxAtDep_succ_succ {rty : Nat → α} {lctxty : α → Sort u} {xty : α}
    (x : lctxty xty) (pos : Nat) (lctx : ∀ n, lctxty (rty n)) (n : Nat) :
    HEq (pushLCtxAtDep x (.succ pos) lctx (.succ n)) (pushLCtxAtDep x pos (fun n => lctx (.succ n)) n) :=
    restoreAtDep_succ_succ _ _ _ _
  
  theorem pushLCtxAtDep_succ_succ_Fn {rty : Nat → α} {lctxty : α → Sort u}
    {xty : α} (x : lctxty xty) (pos : Nat) (lctx : ∀ n, lctxty (rty n)) :
    HEq (fun n => pushLCtxAtDep x (.succ pos) lctx (.succ n)) (pushLCtxAtDep x pos (fun n => lctx (.succ n))) :=
    restoreAtDep_succ_succ_Fn _ _ _
  
  def pushLCtxAtDep_comm {α : Sort w} {β : α → Sort x} {rty : Nat → α} {lctxty : α → Sort u}
    (f : ∀ (x : α), lctxty x → β x) {xty : α} (x : lctxty xty) (pos : Nat)
    (lctx : ∀ n, lctxty (rty n)) (n : Nat) :
      f _ (pushLCtxAtDep x pos lctx n) = pushLCtxAtDep (lctxty:=β) (f xty x) pos (fun n => f _ (lctx n)) n := by
    dsimp [pushLCtxAt, pushLCtxAtDep, restoreAt, restoreAtDep]
    match pos.ble n with
    | true =>
      match (n - pos) with
      | 0 => rfl
      | _ + 1 => rfl
    | false => rfl
  
  def pushLCtxAtDep.nonDep {rty : Nat → α} {lctxty : Sort u}
    {xty : α} (x : lctxty) (pos : Nat) (lctx : Nat → lctxty) (n : Nat) :
    @pushLCtxAtDep _ (fun _ => lctxty) xty x pos rty lctx n = pushLCtxAt x pos lctx n := rfl
  
  def pushLCtxAtDep_absorbAux {rty : Nat → α} {lctxty : α → Sort u}
    {xty : α} (x : lctxty xty) (pos : Nat) (lctx : ∀ n, lctxty (rty n)) (n : Nat) :
    HEq
      (@pushLCtxAtDep _ lctxty _ x pos rty lctx n)
      (@pushLCtxAtDep _ id _ x pos (lctxty ∘ rty) lctx n) := by
    dsimp [pushLCtxAt, pushLCtxAtDep]
    dsimp [pushLCtxAt, pushLCtxAtDep, restoreAt, restoreAtDep]
    match pos.ble n with
    | true =>
      match (n - pos) with
      | 0 => rfl
      | _ + 1 => rfl
    | false => rfl
  
  theorem pushLCtxAtDep_absorb {rty : Nat → α} {lctxty : α → Sort u}
    {xty : α} (x : lctxty xty) (pos : Nat) (lctx : ∀ n, lctxty (rty n)) :
    HEq (@pushLCtxAtDep _ lctxty _ x pos rty lctx) (@pushLCtxAtDep _ id _ x pos (lctxty ∘ rty) lctx) :=
    HEq.funext _ _ (pushLCtxAtDep_absorbAux _ _ _)
  
  theorem pushLCtx_zero (x : α) (lctx : Nat → α) : pushLCtx x lctx 0 = x := rfl

  theorem pushLCtx_succ (x : α) (lctx : Nat → α) (n : Nat) : pushLCtx x lctx (.succ n) = lctx n := rfl
  
  theorem pushLCtx_succ_Fn (x : α) (lctx : Nat → α) :
    (fun n => pushLCtx x lctx (.succ n)) = lctx := rfl
  
  theorem pushLCtx_comm (f : α → β) (x : α) (lctx : Nat → α) (n : Nat) :
    f (pushLCtx x lctx n) = pushLCtx (f x) (fun n => f (lctx n)) n := by
    rw [← pushLCtxAt_zero]; rw [← pushLCtxAt_zero]
    apply pushLCtxAt_comm f x 0 lctx n
  
  theorem pushLCtx_commFn (f : α → β) (x : α) (lctx : Nat → α) :
    (fun n => f (pushLCtx x lctx n)) = (fun n => pushLCtx (f x) (fun n => f (lctx n)) n) :=
    funext (pushLCtx_comm f x lctx)
  
  theorem pushLCtx_pushLCtxAt (x y : α) (pos : Nat) (lctx : Nat → α) :
    pushLCtx y (pushLCtxAt x pos lctx) = pushLCtxAt x (Nat.succ pos) (pushLCtx y lctx) := by
    apply funext; intro n; cases n; rfl; rw [pushLCtxAt_succ_succ];
  
  theorem pushLCtxDep_zero {lctxty : α → Sort u} {xty : α} (x : lctxty xty)
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) :
    pushLCtxDep x lctx 0 = x := rfl
  
  theorem pushLCtxDep_succ {lctxty : α → Sort u}
    {xty : α} (x : lctxty xty) {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) (n : Nat) :
    pushLCtxDep x lctx (.succ n) = lctx n := rfl

  theorem pushLCtxDep_succ_Fn {lctxty : α → Sort u}
    {xty : α} (x : lctxty xty) {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) :
    (fun n => pushLCtxDep x lctx (.succ n)) = lctx := rfl
  
  theorem pushLCtxDep_comm {α : Sort w} {β : α → Sort x} {rty : Nat → α} {lctxty : α → Sort u}
    (f : ∀ (x : α), lctxty x → β x) (lctx : ∀ n, lctxty (rty n))
    {xty : α} (x : lctxty xty) (n : Nat) :
    f _ (pushLCtxDep x lctx n) = pushLCtxDep (lctxty:=β) (f xty x) (fun n => f _ (lctx n)) n := by
    dsimp [pushLCtx, pushLCtxDep]
    cases n <;> rfl

  theorem pushLCtx_commDep {β : α → Sort x} {x : α} {lctx : Nat → α} (f : ∀ (x : α), β x) :
    HEq (f (pushLCtx x lctx n)) (pushLCtxDep (f x) (fun n => f (lctx n)) n) := by
    cases n <;> rfl
  
  theorem pushLCtxDep_absorbAux {rty : Nat → α} {lctxty : α → Sort u}
    (lctx : ∀ n, lctxty (rty n)) {xty : α} (x : lctxty xty) (n : Nat) :
    HEq
      (@pushLCtxDep _ lctxty _ x rty lctx n)
      (@pushLCtxDep _ id _ x (lctxty ∘ rty) lctx n) := by
    dsimp [pushLCtx, pushLCtxDep]
    cases n <;> rfl
  
  theorem pushLCtxDep_absorb {rty : Nat → α} {lctxty : α → Sort u}
    (lctx : ∀ n, lctxty (rty n)) {xty : α} (x : lctxty xty) :
    HEq (@pushLCtxDep _ lctxty _ x rty lctx) (@pushLCtxDep _ id _ x (lctxty ∘ rty) lctx) :=
    HEq.funext _ _ (fun n => pushLCtxDep_absorbAux lctx x n)
  
  theorem pushLCtxDep_pushLCtxAtDep {rty : Nat → α} {lctxty : α → Sort u}
    (lctx : ∀ n, lctxty (rty n)) {xty : α} (x : lctxty xty) {yty : α} (y : lctxty yty) (pos : Nat) :
    HEq (pushLCtxDep y (pushLCtxAtDep x pos lctx)) (pushLCtxAtDep x (Nat.succ pos) (pushLCtxDep y lctx)) := by
    apply HEq.funext; intro n; cases n; rfl;
    apply HEq.trans _ (HEq.symm (pushLCtxAtDep_succ_succ _ _ _ _)); apply HEq.rfl

  @[reducible] def pushLCtxs (xs : List α) (lctx : Nat → α) (n : Nat) : α :=
    match Nat.blt n xs.length with
    | true  => xs.getD n (lctx 0)
    | false => lctx (n - xs.length)

  theorem pushLCtxs_lt (h : n < xs.length) : pushLCtxs xs lctx n = xs.getD n (lctx 0) := by
    dsimp [pushLCtxs]; rw [@id (Nat.blt n (List.length xs) = true) (Nat.ble_eq_true_of_le h)]

  theorem pushLCtxs_ge (h : n ≥ xs.length) : pushLCtxs xs lctx n = lctx (n - xs.length) := by
    dsimp [pushLCtxs];
    have h : Nat.blt n (List.length xs) = false :=
      Nat.ble_eq_false_of_lt _ (Nat.succ_le_succ h)
    rw [h]

  theorem pushLCtxs_nil (lctx : Nat → α) :
    pushLCtxs .nil lctx = lctx := rfl

  theorem pushLCtxs_cons (xs : List α) (lctx : Nat → α) :
    pushLCtxs (x :: xs) lctx = pushLCtx x (pushLCtxs xs lctx) := by
    apply funext; intros n; cases n
    case h.zero =>
      dsimp [pushLCtxs, pushLCtx, Nat.blt, Nat.ble]; rw [Nat.zero_ble]
    case h.succ n =>
      dsimp [pushLCtxs, pushLCtx, Nat.blt, Nat.ble]; rw [Nat.succ_sub_succ]

  theorem pushLCtxs_append (xs ys : List α) (lctx : Nat → α) :
    pushLCtxs (xs ++ ys) lctx = pushLCtxs xs (pushLCtxs ys lctx) := by
    induction xs;
    case nil => rfl
    case cons x xs IH =>
      dsimp; rw [pushLCtxs_cons]; rw [pushLCtxs_cons]; rw [IH]

  theorem pushLCtxs_singleton (x : α) (lctx : Nat → α) :
    pushLCtxs [x] lctx = pushLCtx x lctx := pushLCtxs_cons [] lctx

  theorem pushLCtxs_append_singleton (xs : List α) (x : α) (lctx : Nat → α) :
    pushLCtxs (xs ++ [x]) lctx = pushLCtxs xs (pushLCtx x lctx) := by
    rw [pushLCtxs_append]; rw [pushLCtxs_singleton]

  theorem pushLCtxs_cons_zero (xs : List α) (lctx : Nat → α) :
    pushLCtxs (x :: xs) lctx 0 = x := by
    dsimp [pushLCtxs, Nat.blt, Nat.ble]; rw [Nat.zero_ble]

  theorem pushLCtxs_cons_succ (xs : List α) (lctx : Nat → α) (n : Nat) :
    pushLCtxs (x :: xs) lctx (.succ n) = pushLCtxs xs lctx n := by
    dsimp [pushLCtxs]; rw [Nat.succ_sub_succ]; rfl

  theorem pushLCtxs_cons_succ_Fn (xs : List α) (lctx : Nat → α) :
    (fun n => pushLCtxs (x :: xs) lctx (.succ n)) = pushLCtxs xs lctx :=
    funext (fun n => pushLCtxs_cons_succ xs lctx n)

  theorem pushLCtxs_comm (f : α → β) (xs : List α) (lctx : Nat → α) (n : Nat) :
    f (pushLCtxs xs lctx n) = pushLCtxs (xs.map f) (fun n => f (lctx n)) n := by
    induction xs generalizing n
    case nil => rfl
    case cons x xs IH =>
      cases n
      case zero =>
        dsimp [List.map]; rw [pushLCtxs_cons_zero, pushLCtxs_cons_zero]
      case succ n =>
        dsimp [List.map]; rw [pushLCtxs_cons_succ, pushLCtxs_cons_succ, ← IH]

  @[reducible] def pushLCtxsAt (xs : List α) (pos : Nat) :=
    restoreAt pos (pushLCtxs xs)

  theorem pushLCtxsAt_zero (xs : List α) : pushLCtxsAt xs 0 = pushLCtxs xs :=
    restoreAt_zero _

  theorem pushLCtxsAt_succ_zero (xs : List α) (pos : Nat) (lctx : Nat → α) :
    pushLCtxsAt xs (.succ pos) lctx 0 = lctx 0 := rfl

  theorem pushLCtxsAt_succ_succ (xs : List α) (pos : Nat) (lctx : Nat → α) (n : Nat) :
    pushLCtxsAt xs (.succ pos) lctx (.succ n) = pushLCtxsAt xs pos (fun n => lctx (.succ n)) n := by
    dsimp [pushLCtxsAt]; rw [restoreAt_succ_succ]

  theorem pushLCtxsAt_succ_succ_Fn (xs : List α) (pos : Nat) (lctx : Nat → α) :
    (fun n => pushLCtxsAt xs (.succ pos) lctx (.succ n)) = pushLCtxsAt xs pos (fun n => lctx (.succ n)) := by
    dsimp [pushLCtxsAt]; rw [restoreAt_succ_succ_Fn]

  @[reducible] def pushLCtxsDep
    {lctxty : α → Sort u} {tys : List α} (xs : HList lctxty tys)
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) (n : Nat) :
    lctxty (pushLCtxs tys rty n) := by
    dsimp [pushLCtxs]
    match Nat.blt n tys.length with
    | true  => exact (xs.getD (α:=α) (lctx 0) n)
    | false => exact (lctx (n - tys.length))

  theorem pushLCtxsDep_lt
    {lctxty : α → Sort u} {tys : List α} {xs : HList lctxty tys}
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) {n : Nat}
    (h : n < tys.length) : HEq (pushLCtxsDep xs lctx n) (xs.getD (lctx 0) n) := by
    dsimp [pushLCtxs]; rw [@id (Nat.blt n (List.length tys) = true) (Nat.ble_eq_true_of_le h)]

  theorem pushLCtxsDep_ge
    {lctxty : α → Sort u} {tys : List α} {xs : HList lctxty tys}
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) {n : Nat}
    (h : n ≥ tys.length) : HEq (pushLCtxsDep xs lctx n) (lctx (n - tys.length)) := by
    dsimp [pushLCtxs]; rw [@id (Nat.blt n (List.length tys) = false)
      (Nat.ble_eq_false_of_lt _ (Nat.succ_le_succ h))]

  theorem pushLCtxsDep_heq
    {lctxty₁ : α₁ → Sort u} {tys₁ : List α₁} (xs₁ : HList lctxty₁ tys₁)
    (rty₁ : Nat → α₁) (lctx₁ : ∀ n, lctxty₁ (rty₁ n))
    {lctxty₂ : α₂ → Sort u} {tys₂ : List α₂} (xs₂ : HList lctxty₂ tys₂)
    (rty₂ : Nat → α₂) (lctx₂ : ∀ n, lctxty₂ (rty₂ n))
    (h₁ : α₁ = α₂) (h₂ : HEq lctxty₁ lctxty₂) (h₃ : HEq tys₁ tys₂)
    (h₄ : HEq xs₁ xs₂) (h₅ : HEq rty₁ rty₂) (h₆ : HEq lctx₁ lctx₂) :
    HEq (pushLCtxsDep xs₁ lctx₁) (pushLCtxsDep xs₂ lctx₂) := by
    cases h₁; cases h₂; cases h₃; cases h₄; cases h₅; cases h₆; apply HEq.rfl

  theorem pushLCtxsDep_substLCtx
    {tys : List α} {lctxty : _} (xs : HList lctxty tys) 
    {rty₁ : Nat → α} (lctx₁ : ∀ n, lctxty (rty₁ n))
    {rty₂ : Nat → α} (lctx₂ : ∀ n, lctxty (rty₂ n))
    (h₁ : rty₁ = rty₂) (h₂ : HEq lctx₁ lctx₂) :
    HEq (pushLCtxsDep xs lctx₁) (pushLCtxsDep xs lctx₂) := by
    cases h₁; cases h₂; rfl

  theorem pushLCtxsDep_substxs {lctxty : _}
    {tys₁ : List α} (xs₁ : HList lctxty tys₁)
    {tys₂ : List α} (xs₂ : HList lctxty tys₂)
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n))
    (h₁ : tys₁ = tys₂) (h₂ : HEq xs₁ xs₂) :
    HEq (pushLCtxsDep xs₁ lctx) (pushLCtxsDep xs₂ lctx) := by
    cases h₁; cases h₂; rfl

  theorem pushLCtxsDep_nil
    {lctxty : α → Sort u} {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) :
    pushLCtxsDep .nil lctx = lctx := rfl

  theorem pushLCtxsDep_cons
    {lctxty : α → Sort u} {ty : α} (x : lctxty ty) {tys : List α}
    (xs : HList lctxty tys) {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) :
    HEq (pushLCtxsDep (.cons x xs) lctx) (pushLCtxDep x (pushLCtxsDep xs lctx)) := by
    apply HEq.funext; intros n; cases n
    case zero =>
      dsimp [pushLCtxs, pushLCtx, Nat.blt, Nat.ble]
      rw [Nat.ble_eq_true_of_le]; rfl
      apply Nat.zero_le
    case succ n =>
      dsimp [pushLCtxs, pushLCtx, Nat.blt, Nat.ble]
      rw [Nat.succ_sub_succ]; rfl

  theorem pushLCtxsDep_cons_zero
    {lctxty : α → Sort u} {ty : α} (x : lctxty ty) {tys : List α}
    (xs : HList lctxty tys) {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) :
    HEq (pushLCtxsDep (.cons x xs) lctx 0) x := by
    dsimp [pushLCtxs, Nat.blt, Nat.ble];
    rw [Nat.ble_eq_true_of_le]; rfl
    apply Nat.zero_le

  theorem pushLCtxsDep_cons_succ
    {lctxty : α → Sort u} {ty : α} (x : lctxty ty) {tys : List α}
    (xs : HList lctxty tys) {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) (n : Nat) :
    HEq (pushLCtxsDep (.cons x xs) lctx (.succ n)) (pushLCtxsDep xs lctx n) := by
    dsimp [pushLCtxs]; rw [Nat.succ_sub_succ]; rfl

  theorem pushLCtxsDep_cons_succ_Fn
    {lctxty : α → Sort u} {ty : α} (x : lctxty ty) {tys : List α}
    (xs : HList lctxty tys) {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) :
    HEq (fun n => pushLCtxsDep (.cons x xs) lctx (.succ n)) (pushLCtxsDep xs lctx) :=
    HEq.funext _ _ (fun n => pushLCtxsDep_cons_succ x xs lctx n)
  
  theorem pushLCtxsDep_append {lctxty : α → Sort u}
    {as bs : List α} (xs : HList lctxty as) (ys : HList lctxty bs)
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) :
    HEq (pushLCtxsDep (xs.append ys) lctx) (pushLCtxsDep xs (pushLCtxsDep ys lctx)) := by
    induction xs
    case nil => rfl
    case cons a as x xs IH =>
      dsimp [HList.append];
      apply HEq.trans (pushLCtxsDep_cons _ _ _)
      apply HEq.trans _ (HEq.symm (pushLCtxsDep_cons _ _ _))
      apply pushLCtxDep_heq <;> try rfl
      case h₅ =>
        apply heq_of_eq; apply pushLCtxs_append
      case h₆ =>
        apply IH

  theorem pushLCtxsDep_singleton
    {lctxty : α → Sort u} {ty : α} (x : lctxty ty)
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) :
    HEq (pushLCtxsDep (.cons x .nil) lctx) (pushLCtxDep x lctx) := pushLCtxsDep_cons x .nil lctx

  theorem pushLCtxsDep_append_singleton
    {lctxty : α → Sort u}
    {as : List α} {a : α} (xs : HList lctxty as) (x : lctxty a)
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) :
    HEq (pushLCtxsDep (xs.append (.cons x .nil)) lctx) (pushLCtxsDep xs (pushLCtxDep x lctx)) := by
    apply HEq.trans (pushLCtxsDep_append _ _ _)
    apply pushLCtxsDep_substLCtx;
    case h₁ => apply pushLCtxs_singleton
    case h₂ => apply pushLCtxsDep_singleton

  @[reducible] def pushLCtxsAtDep
    {lctxty : α → Sort u} {tys : List α} (xs : HList lctxty tys) (pos : Nat)
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) :=
    restoreAtDep pos (pushLCtxsDep xs) lctx

  theorem pushLCtxsAtDep_heq
    {lctxty₁ : α₁ → Sort u} {tys₁ : List α₁} (xs₁ : HList lctxty₁ tys₁) (pos₁ : Nat)
    (rty₁ : Nat → α₁) (lctx₁ : ∀ n, lctxty₁ (rty₁ n))
    {lctxty₂ : α₂ → Sort u} {tys₂ : List α₂} (xs₂ : HList lctxty₂ tys₂) (pos₂ : Nat)
    (rty₂ : Nat → α₂) (lctx₂ : ∀ n, lctxty₂ (rty₂ n))
    (h₁ : α₁ = α₂) (h₂ : HEq lctxty₁ lctxty₂) (h₃ : HEq tys₁ tys₂) (h₄ : HEq xs₁ xs₂)
    (h₅ : pos₁ = pos₂) (h₆ : HEq rty₁ rty₂) (h₇ : HEq lctx₁ lctx₂) :
    HEq (pushLCtxsAtDep xs₁ pos₁ lctx₁) (pushLCtxsAtDep xs₂ pos₂ lctx₂) := by
    cases h₁; cases h₂; cases h₃; cases h₄; cases h₅; cases h₆; cases h₇; apply HEq.rfl

  theorem pushLCtxsAtDep_substLCtx
    {tys : List α} {lctxty : _} (xs : HList lctxty tys) (pos : Nat)
    {rty₁ : Nat → α} (lctx₁ : ∀ n, lctxty (rty₁ n))
    {rty₂ : Nat → α} (lctx₂ : ∀ n, lctxty (rty₂ n))
    (h₁ : rty₁ = rty₂) (h₂ : HEq lctx₁ lctx₂) :
    HEq (pushLCtxsAtDep xs pos lctx₁) (pushLCtxsAtDep xs pos lctx₂) := by
    cases h₁; cases h₂; rfl

  theorem pushLCtxsAtDep_substxs {lctxty : _}
    {tys₁ : List α} (xs₁ : HList lctxty tys₁)
    {tys₂ : List α} (xs₂ : HList lctxty tys₂)
    (pos : Nat) {rty : Nat → α} (lctx : ∀ n, lctxty (rty n))
    (h₁ : tys₁ = tys₂) (h₂ : HEq xs₁ xs₂) :
    HEq (pushLCtxsAtDep xs₁ pos lctx) (pushLCtxsAtDep xs₂ pos lctx) := by
    cases h₁; cases h₂; rfl

  theorem pushLCtxsAtDep_zero
    {lctxty : α → Sort u} {tys : List α} (xs : HList lctxty tys)
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) :
    HEq (pushLCtxsAtDep xs 0 lctx) (pushLCtxsDep xs lctx) := restoreAtDep_zero _ _

  theorem pushLCtxsAtDep_succ_zero
    {lctxty : α → Sort u} {tys : List α} (xs : HList lctxty tys)
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) :
    pushLCtxsAtDep xs (.succ pos) lctx 0 = lctx 0 := rfl

  theorem pushLCtxsAtDep_succ_succ 
    {lctxty : α → Sort u} {tys : List α} (xs : HList lctxty tys) (pos : Nat)
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) (n : Nat) :
    HEq (pushLCtxsAtDep xs (.succ pos) lctx (.succ n)) (pushLCtxsAtDep xs pos (fun n => lctx (.succ n)) n) := by
    dsimp [pushLCtxsAtDep]; apply restoreAtDep_succ_succ

  theorem pushLCtxsAtDep_succ_succ_Fn 
    {lctxty : α → Sort u} {tys : List α} (xs : HList lctxty tys) (pos : Nat)
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) :
    HEq (fun n => pushLCtxsAtDep xs (.succ pos) lctx (.succ n)) (pushLCtxsAtDep xs pos (fun n => lctx (.succ n))) := by
    dsimp [pushLCtxsAtDep]; apply restoreAtDep_succ_succ_Fn

  theorem List.ofFun_get?_eq_none (f : Nat → α) (n m : Nat) (h : n ≤ m) :
    (List.ofFun f n).get? m = .none := by
    induction m generalizing f n
    case zero =>
      cases n
      case zero => rfl
      case succ n => cases h
    case succ m IH =>
      cases n
      case zero => rfl
      case succ n =>
        let h' := Nat.le_of_succ_le_succ h
        dsimp [List.ofFun]; rw [IH (fun n => f (.succ n)) _ h']

  theorem List.ofFun_ofPushLCtx
    (xs : List α) (heq : xs.length = n) (lctx : Nat → α) :
    List.ofFun (pushLCtxs xs lctx) n = xs :=
    match xs, n with
    | .nil, n => by
      dsimp at heq; rw [← heq]; rfl
    | .cons x xs, _ => by
      dsimp at heq; rw [← heq];
      dsimp [List.ofFun]; rw [pushLCtxs_cons_zero]; apply congrArg
      rw [pushLCtxs_cons_succ_Fn]
      exact List.ofFun_ofPushLCtx xs rfl lctx

  def HList.ofFun {tyf : Nat → α} {β : α → Sort _} (f : ∀ n, β (tyf n)) (n : Nat) :
    HList β (List.ofFun tyf n) :=
    match n with
    | 0 => .nil
    | .succ n' => .cons (f 0) (ofFun (fun n => f (.succ n)) n')

  theorem HList.ofFun_zero {tyf : Nat → α} {β : α → Sort _} (f : ∀ n, β (tyf n)) :
    HList.ofFun f 0 = .nil := rfl

  theorem HList.ofFun_succ {tyf : Nat → α} {β : α → Sort _} (f : ∀ n, β (tyf n)) (n : Nat) :
    HList.ofFun f (.succ n) = .cons (f 0) (ofFun (fun n => f (.succ n)) n) := rfl

  theorem HList.ofFun_ofPushLCtxDep
    {lctxty : α → Sort u} {tys : List α} (heq : tys.length = n)
    (xs : HList lctxty tys) {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) :
    HEq (HList.ofFun (pushLCtxsDep xs lctx) n) xs :=
    match xs, n with
    | .nil, n => by
      dsimp at heq; rw [← heq]; rfl
    | .cons (ty:=ty) (tys:=tys) x xs, _ => by
      dsimp at heq; rw [← heq]
      rw [HList.ofFun_succ];
      congr
      case e_3.h => dsimp; rw [pushLCtxs_cons_zero]
      case e_4.h => dsimp; rw [pushLCtxs_cons_succ_Fn]; apply List.ofFun_ofPushLCtx; rfl
      case e_5 => apply pushLCtxsDep_cons_zero
      case e_6 =>
        apply HEq.trans _ (ofFun_ofPushLCtxDep rfl xs lctx)
        congr
        case e_2.h => apply pushLCtxs_cons_succ_Fn
        case e_4 => apply pushLCtxsDep_cons_succ_Fn

  theorem HList.ofFun_getD_eq_some
    {tyf : Nat → α} {β : α → Sort _} (f : ∀ n, β (tyf n)) (n m : Nat)
    (h : n > m) {ty : α} (default : β ty) :
    HEq ((HList.ofFun f n).getD default m) (f m) := by
    induction m generalizing tyf n
    case zero =>
      cases n
      case zero => cases h
      case succ n => rfl
    case succ m IH =>
      cases n
      case zero => cases h
      case succ n =>
        let h' := Nat.le_of_succ_le_succ h
        dsimp [ofFun]; apply (IH (fun n => f (.succ n)) _ h')

  theorem HList.ofFun_getD_eq_none
    {tyf : Nat → α} {β : α → Sort _} (f : ∀ n, β (tyf n)) (n m : Nat)
    (h : n ≤ m) {ty : α} (default : β ty) :
    HEq ((HList.ofFun f n).getD default m) default := by
    induction m generalizing tyf n
    case zero =>
      cases n
      case zero => rfl
      case succ n => cases h
    case succ m IH =>
      cases n
      case zero => rfl
      case succ n =>
        let h' := Nat.le_of_succ_le_succ h
        dsimp [ofFun]; apply (IH (fun n => f (.succ n)) _ h')

end push


section replace

  def replaceAt (x : α) (pos : Nat) (lctx : Nat → α) (n : Nat) : α :=
    match n.beq pos with
    | true => x
    | false => lctx n

  def replaceAtDep {lctxty : α → Sort u} {xty : α} (x : lctxty xty) (pos : Nat)
    {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) (n : Nat) : lctxty (replaceAt xty pos rty n) := by
    dsimp [replaceAt]
    match n.beq pos with
    | true => exact x
    | false => exact lctx n

  theorem BinTree.get?_insert_eq_replaceAt_get? {bt : BinTree α} :
    (BinTree.get? (BinTree.insert bt m x) n).getD d = replaceAt x m (fun n => (bt.get? n).getD d) n := by
    dsimp [replaceAt]
    match h : Nat.beq n m with
    | true =>
      dsimp; cases (Nat.eq_of_beq_eq_true h); rw [BinTree.insert.correct₁]; rfl
    | false =>
      dsimp; rw [BinTree.insert.correct₂];
      have hne := Nat.ne_of_beq_eq_false h; intro h; cases h; apply hne rfl

  theorem BinTree.get?_insert_eq_replaceAt_get?_Fn {bt : BinTree α} :
    (fun n => (BinTree.get? (BinTree.insert bt m x) n).getD d) = replaceAt x m (fun n => (bt.get? n).getD d) :=
    funext (fun _ => get?_insert_eq_replaceAt_get?)

end replace


section pushs_pops

  theorem push_pop_eq (lctx : Nat → α) :
    pushLCtx (lctx 0) (fun n => lctx (.succ n)) = lctx := by
    apply funext
    intro n; cases n <;> rfl
  
  theorem pushs_pops_eq (lctx : Nat → α) :
    pushLCtxs (List.ofFun lctx lvl) (fun n => lctx (n + lvl)) = lctx := by
    apply funext; intro n; dsimp [pushLCtxs, List.getD]
    rw [List.ofFun_length]
    match h : Nat.blt n lvl with
    | true =>
      rw [List.ofFun_get?_eq_some]; rfl
      dsimp [Nat.blt] at h;
      exact Nat.le_of_ble_eq_true h
    | false =>
      rw [Nat.sub_add_cancel]
      dsimp [Nat.blt] at h;
      let h' := Nat.lt_of_ble_eq_false h
      exact Nat.le_of_succ_le_succ h'
  
  theorem ofFun_pushs (heq : xs.length = n) :
    List.ofFun (pushLCtxs xs lctx) n = xs := by
    cases heq; induction xs generalizing lctx
    case nil => rfl
    case cons x xs IH =>
      rw [pushLCtxs_cons]; dsimp [List.ofFun]; rw [IH]

  theorem pushDep_popDep_eq
    {lctxty : α → Sort u} {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) :
    HEq (pushLCtxDep (lctx 0) (fun n => lctx (.succ n))) lctx := by
    apply HEq.funext;
    intro n; cases n <;> rfl

  theorem pushsDep_popsDep_eq
    {lctxty : α → Sort u} {rty : Nat → α} (lctx : ∀ n, lctxty (rty n)) :
    HEq (pushLCtxsDep (HList.ofFun lctx lvl) (fun n => lctx (n + lvl))) lctx := by
    apply HEq.funext; intro n; dsimp [pushLCtxs, List.getD]
    rw [List.ofFun_length]
    match h : Nat.blt n lvl with
    | true =>
      dsimp;
      apply HList.ofFun_getD_eq_some;
      dsimp [Nat.blt] at h;
      exact Nat.le_of_ble_eq_true h
    | false =>
      rw [Nat.sub_add_cancel]
      dsimp [Nat.blt] at h;
      let h' := Nat.lt_of_ble_eq_false h
      exact Nat.le_of_succ_le_succ h'

end pushs_pops


section add_nat
  
  @[reducible] def addAt (lvl pos : Nat) := mapAt pos (fun x => x + lvl)

  @[reducible] def succAt := addAt 1

  theorem addAt_succ_zero (lvl pos : Nat) :
    addAt lvl (.succ pos) 0 = 0 := rfl
  
  theorem addAt_succ_succ (lvl pos : Nat) (n : Nat) :
    addAt lvl (.succ pos) (.succ n) = .succ (addAt lvl pos n) := by
    dsimp [addAt]; rw [mapAt_succ_succ]

  def addAt_succ_l (lvl pos : Nat) (n : Nat) :
    addAt (.succ lvl) pos n = succAt pos (addAt lvl pos n) := by
    dsimp [addAt, Nat.add_succ]
    rw [mapAt_comp pos Nat.succ (fun x => x + lvl) n]
  
  def addAt_succ_r (lvl pos : Nat) (n : Nat) :
    addAt (.succ lvl) pos n = addAt lvl pos (succAt pos n) := by
    dsimp [addAt];
    have heq : (fun x => x + Nat.succ lvl) = (fun x => (Nat.succ x) + lvl) := by
      apply funext; intros x; rw [Nat.succ_add]; rfl
    rw [heq]; rw [mapAt_comp pos (fun x => x + lvl) Nat.succ n]
  
  def addAt_zero (pos : Nat) : addAt 0 pos = id := by
    apply funext; intro n;
    dsimp [addAt];
    rw [mapAt_id_eq_id']; rfl

  def add.one (pos : Nat) : addAt 1 pos = succAt pos:= rfl

end add_nat


section generic

  theorem restoreAt_succ_pushLCtx {α} (restore : (Nat → α) → (Nat → α))
    (x : α) (pos : Nat) (lctx : Nat → α) (n : Nat) :
    restoreAt (.succ pos) restore (pushLCtx x lctx) n = pushLCtx x (restoreAt pos restore lctx) n :=
    match pos, n with
    | 0,       0        => rfl
    | 0,       .succ _  => rfl
    | .succ _, 0        => rfl
    | .succ _, .succ _ => restoreAt_succ_succ _ _ _ _

  theorem restoreAt_succ_pushLCtx_Fn {α} (restore : (Nat → α) → (Nat → α))
    (x : α) (pos : Nat) (lctx : Nat → α) :
    restoreAt (.succ pos) restore (pushLCtx x lctx) = pushLCtx x (restoreAt pos restore lctx) :=
    funext (fun n => restoreAt_succ_pushLCtx restore x pos lctx n)

  theorem restoreAtDep_succ_pushLCtxDep {α} {lctxty : α → Sort u}
    (restore : (Nat → α) → (Nat → α))
    (restoreDep : ∀ {rty : Nat → α}, (∀ n, lctxty (rty n)) → ∀ n, lctxty ((restore rty) n))
    {rty : Nat → α} {xty : α} (x : lctxty xty) (pos : Nat)
    (lctx : ∀ n, lctxty (rty n)) (n : Nat) :
    HEq (restoreAtDep (.succ pos) restoreDep (pushLCtxDep x lctx) n) (pushLCtxDep x (restoreAtDep pos restoreDep lctx) n) :=
    match pos, n with
    | 0,          0        => HEq.rfl
    | 0,          .succ _  => HEq.rfl
    | .succ _,    0        => HEq.rfl
    | .succ pos', .succ n' => by
      apply HEq.trans (restoreAtDep_succ_succ (Nat.succ pos') restoreDep (pushLCtxDep x lctx) n')
      rw [pushLCtxDep_succ]; rw [pushLCtxDep_succ_Fn]

  theorem restoreAtDep_succ_pushLCtxDep_Fn {α} {lctxty : α → Sort u}
    (restore : (Nat → α) → (Nat → α))
    (restoreDep : ∀ {rty : Nat → α}, (∀ n, lctxty (rty n)) → ∀ n, lctxty ((restore rty) n))
    {rty : Nat → α} {xty : α} (x : lctxty xty) (pos : Nat)
    (lctx : ∀ n, lctxty (rty n)) :
    HEq (restoreAtDep (.succ pos) restoreDep (pushLCtxDep x lctx)) (pushLCtxDep x (restoreAtDep pos restoreDep lctx)) :=
    HEq.funext _ _ (fun n => restoreAtDep_succ_pushLCtxDep restore restoreDep x pos lctx n)

end generic

section genericInst

  theorem coPair.ofPushPop (x : α) :
    coPair Nat.succ (pushLCtx x) := fun _ _ => rfl

  theorem contraPair.ofPushPop (x : α) :
    contraPair Nat.succ (fun lctx => lctx 0 = x) (pushLCtx x) := by
    intro lctx hcstr; rw [← hcstr]; apply funext; intro n
    cases n <;> rfl

  theorem coPairDep.ofPushDepPopDep
    {lctxty : α → Sort u} {xty : α} (x : lctxty xty) :
    coPairDep lctxty Nat.succ (pushLCtx xty) (pushLCtxDep x) :=
    And.intro (coPair.ofPushPop xty) (fun {_} _ _ => HEq.rfl)

  theorem contraPairDep.ofPushDepPopDep
    {lctxty : α → Sort u} {xty : α} (x : lctxty xty) :
    contraPairDep lctxty Nat.succ (fun lctxty => lctxty 0 = xty) (pushLCtx xty)
      (fun lctx => HEq (lctx 0) x) (pushLCtxDep x) := by
    apply And.intro
    case left => apply contraPair.ofPushPop
    case right =>
      intro rty hcstr lctx hcstrDep; apply HEq.funext; intro n
      cases hcstr; cases hcstrDep; cases n <;> rfl

  theorem coPair.ofPushsPops
    (lvl : Nat) (xs : List α) (heq : xs.length = lvl) :
    coPair (fun x => x + lvl) (pushLCtxs xs) := by
    induction lvl generalizing xs <;> intro lctx n
    case zero =>
      dsimp [pushLCtxs]; cases xs;
      case nil => rfl
      case cons _ _ => cases heq
    case succ lvl IH =>
      dsimp [pushLCtxs]; cases xs;
      case nil => cases heq
      case cons x xs =>
        simp at heq
        rw [← IH xs heq lctx n]
        dsimp [pushLCtxs, Nat.blt, Nat.ble, Nat.add_succ]
        rw [Nat.succ_sub_succ]
  
  theorem contraPair.ofPushsPops (lvl : Nat) (xs : List α) (heq : xs.length = lvl) :
    contraPair (fun n => n + lvl) (fun lctx => List.ofFun lctx lvl = xs) (pushLCtxs xs) := by
    intro lctx hcstr; cases hcstr; apply pushs_pops_eq
  
  theorem coPairDep.ofPushsDepPopsDep
    {lctxty : α → Sort u} (lvl : Nat) {tys : List α}
    (xs : HList lctxty tys) (heq : tys.length = lvl) :
    coPairDep lctxty (fun x => x + lvl) (pushLCtxs tys) (pushLCtxsDep xs) :=
    And.intro (coPair.ofPushsPops lvl tys heq) (fun {rty} lctx n => by
      dsimp [pushLCtxsDep, pushLCtxs]; 
      induction lvl generalizing tys lctx n
      case zero =>
        cases xs;
        case nil => rfl
        case cons _ _ => cases heq
      case succ lvl IH =>
        cases xs;
        case nil => cases heq
        case cons ty tys x xs =>
          simp at heq
          apply HEq.trans _ (IH xs heq lctx n)
          dsimp [Nat.blt, Nat.ble, Nat.add_succ]
          rw [Nat.succ_sub_succ]; rfl)

  theorem contraPairDep.ofPushsDepPopsDep
    {lctxty : α → Sort u} (lvl : Nat) {tys : List α}
    (xs : HList lctxty tys) (heq : tys.length = lvl) :
    contraPairDep lctxty (fun n => n + lvl) (fun lctxty => List.ofFun lctxty lvl = tys)
      (pushLCtxs tys) (fun lctx => HEq (HList.ofFun lctx lvl) xs) (pushLCtxsDep xs) :=
    And.intro (contraPair.ofPushsPops lvl tys heq) (fun {rty} hcstr lctx hcstrDep => by
      cases hcstr; cases hcstrDep; apply pushsDep_popsDep_eq)

end genericInst