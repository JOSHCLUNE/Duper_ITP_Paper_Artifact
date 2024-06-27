import Auto.Tactic

-- Standard Preprocessing Configs
set_option auto.redMode "reducible"
-- Standard TPTP Configs
set_option trace.auto.tptp.printQuery true
set_option trace.auto.tptp.result true
set_option auto.tptp.solver.name "zeport-lams"
set_option auto.tptp.zeport.path "/home/indprinciple/Programs/zipperposition/portfolio"
-- Standard SMT Configs
set_option trace.auto.smt.printCommands true
set_option trace.auto.smt.result true
set_option auto.smt.solver.name "z3"

set_option auto.tptp true
set_option trace.auto.tptp.printProof true

-- Manual Check

section ManualCheck

  example : True := by (fail_if_success auto 👍); auto
  private def sorryChk : False := by auto 👎
  #print axioms sorryChk

  set_option auto.lamReif.prep.def false

  -- In `Checker Statistics`, check that the `assertions` field is `1`
  set_option auto.optimizeCheckerProof true in
  set_option trace.auto.buildChecker true in
  example (h₁ : False) (h₂ : a = b) : False := by auto [h₁, h₂]

  -- In `Checker Statistics`, check that the `assertions` field is `4`
  set_option auto.optimizeCheckerProof false in
  set_option trace.auto.buildChecker true in
  example (h₁ : False) (h₂ : a = b) : False := by auto [h₁, h₂]

  -- In `Checker Statistics`, check that the `assertions` field is `4`
  set_option auto.optimizeCheckerProof true in
  set_option trace.auto.buildChecker true in
  example (h₁ : a = b) (h₂ : b = c) (h₃ : c = d) : a = c := by
    auto [h₁, h₂, h₃]

  -- In `Checker Statistics`, check that the `assertions` field is `5`
  set_option auto.optimizeCheckerProof false in
  set_option trace.auto.buildChecker true in
  example (h₁ : a = b) (h₂ : b = c) (h₃ : c = d) : a = c := by
    auto [h₁, h₂, h₃]

end ManualCheck

-- Inhabitation Reasoning

section Inhabitation

  set_option trace.auto.lamReif.printProofs true
  set_option trace.auto.lamReif.printResult true

  example [Inhabited α] (h : ∀ (x : α), True) : ∃ (x : α), True := by
    auto

  example [Nonempty α] (h : ∀ (x : α), True) : ∃ (x : α), True := by
    auto

  example (h : ∀ (x : Nat), x = x) : ∃ (x : Nat), x = x := by
    auto

  example (x : α) (y : β) (h : ∀ (x : α) (y : β), x = x ∧ y = y) :
     ∃ (x : α) (y : β), x = x ∧ y = y := by
    auto

  example (a : α) (p : α → Prop) : (∃ x, p x → r) ↔ ((∀ x, p x) → r) := by
    auto

  set_option trace.auto.lamReif.printProofs true in
  example (a : α) (p : α → Prop) : (∃ x, r → p x) ↔ (r → ∃ x, p x) := by
    auto

  -- `OK Nat → OK Nat` should be blocked for being trivial
  example (OK : Type → Type)
    (inh : ∀ (α : Type), OK α → OK α)
    (h : ∀ (x : OK Nat), x = x) : 1 = 1 := by
    auto

  -- Either `inh₁` or `inh₂` should be blocked for being redundant
  example (OK₁ OK₂ : Type → Type)
    (inh₁ : ∀ (α : Type), OK₁ α → OK₂ α)
    (inh₂ : ∀ (α : Type), OK₁ α → OK₁ α → OK₂ α)
    (h : OK₁ Nat → ∀ (x : OK₂ Nat), x = x) : 1 = 1 := by
    auto

end Inhabitation

-- Monomorphization

set_option auto.redMode "instances" in
example (as bs cs : List α) (f : α → β) :
  ((as ++ bs) ++ cs).map f = as.map f ++ (bs.map f ++ cs.map f) := by
  intromono [List.append_assoc, List.map_append];
  apply monoLem_0
  rw [monoLem_1]; rw [monoLem_3]; rw [monoLem_3]

example
  (h : ∀ (α : Type u) (as bs cs : List α), (as ++ bs) ++ cs ≠ as ++ (bs ++ cs) → False)
  {α : Type u} (as bs cs : List α) : (as ++ bs) ++ cs = as ++ (bs ++ cs) := by
  auto

section MonomorphizationWierdExample

  def List.directZip : {α : Type u} → List α → {β : Type v} → List β → List (α × β)
    | _, [], _, []   => []
    | _, [], _, _::_ => []
    | _, _::_, _, [] => []
    | _, x::xs, _, y::ys => (x,y) :: directZip xs ys

  def prod_eq₁' : ∀ (x : α) (y : β), Prod.fst (x, y) = x := by auto
  def prod_eq₂' : ∀ (x : α) (y : β), Prod.snd (x, y) = y := by auto

  set_option auto.mono.saturationThreshold 800 in
  example
    (α : Type u)
    (as bs cs ds : List α)
    (hab : as.length = bs.length) (hbc : bs.length = cs.length) (hcd : cs.length = ds.length)
    (h : ∀ (δ : Type u) (f₁ f₂ f₃ f₄ : δ → α) (xs : List δ),
      xs.map f₁ = as ∧ xs.map f₂ = bs ∧ xs.map f₃ = cs ∧ xs.map f₄ = ds → False) : False := by
    intromono [h, hab, prod_eq₁', prod_eq₂'] d[List.length, List.directZip, List.map]; sorry

end MonomorphizationWierdExample

-- Data Structure Robustness

section DSRobust

  -- Duplicated reified fact
  example (h₁ : False) (h₂ : False) : False := by auto [h₁, h₂]
  example (α : Prop) (h₁ : α) (h₂ : α) (h₃ : α) : α := by auto
  example (h₁ : ¬ True) : True := by auto [h₁]

  -- Result of ChkStep coincides with input term
  example (h₁ : False → False) (h₂ : False) : True := by auto [h₁, h₂]

end DSRobust

-- Tactic elaboration

example : True := by auto d[]
example : True := by auto u[]
example : True := by auto [] u[] d[]
example : True := by first | auto 👍| exact True.intro
example : True := by auto 👎

-- Defeq Lemma collection

section CollectLemma

  set_option trace.auto.printLemmas true
  set_option auto.redMode "instances"
  example : (∀ (xs ys zs : List α), xs ++ ys ++ zs = xs ++ (ys ++ zs)) := by
    intro xs; induction xs <;> auto [*] d[List.append]

  set_option auto.redMode "instances" in
  example : (∀ (m n k : Nat), m + n + k = m + (n + k)) := by
    intros m n k; revert m n; induction k <;> auto [*] d[Nat.add]

end CollectLemma

-- Skolemization

section Skolemization

  set_option trace.auto.lamReif.printProofs true

  example (p : α → Prop) (h₁ : ∃ x, p x) : ∃ x, p x :=
    by auto

  example (p q : (α → β) → Prop) (h₁ : ∃ (f : _) (g : α), p f) (h₂ : ∀ f, p f → q f) : ∃ f, q f :=
    by auto

  example (p : α → Prop) (q : (β → γ) → Prop) (h₁ : ∃ f, p f) (h₂ : ∃ f, q f) : ∃ f g, p f ∧ q g :=
    by auto

  example (p : α → β → Prop) (h : ∀ (x : α), ∃ y, p x y) : ∃ (f : α → β), ∀ x, p x (f x) :=
    by auto

  example (p : α → β → γ → Prop) (h : ∀ (x : α) (y : β), ∃ z, p x y z) :
    ∃ (f : α → β → γ), ∀ x y, p x y (f x y) :=
    by auto

  example (p : α → β → γ → δ → Prop) (h : ∀ (x : α), ∃ (y : β), ∀ (z : γ), ∃ (t : δ), p x y z t) :
    ∃ (f : α → β) (g : α → γ → δ), ∀ x z, p x (f x) z (g x z) :=
    by auto

  example (p : α → (β → γ) → Prop) (h : ∀ x, ∃ y, p x y) : ∃ (f : _ → _), ∀ x, p x (f x) :=
    by auto

  example (p : α → Prop) (h₁ : ∃ (_ : α), p x) (h₂ : p x) : p x :=
    by auto

  example (p : α → Prop)
    (h₁ : ∃ (_ _ : β) (_ _ : γ), p x) (h₂ : ∃ (_ _ : β), p x) : p x :=
    by auto

end Skolemization

-- Extensionalization

section Extensionalization

  set_option trace.auto.lamReif.printProofs true

  example (f g : Nat → Nat) (H : ∀ x, f x = g x) : f = g := by
    auto

  example (f g : (α → α) → β → α) (H : ∀ x, f x = g x) : f = g := by
    auto

  example (f g : α → α → α → α → α → α → α → α → α → α → α → α → α → α → α → α → α) :
    (f = g) = (g = f) := by auto

  example : (fun f g => @Eq (α → α → α) f g) = (fun f g => ∀ x, f x = g x) :=
    by auto

end Extensionalization

-- Constant unfolding

section UnfoldConst

  def c₁ := 2
  def c₂ := c₁

  example : c₁ = 2 := by auto u[c₁]
  example : c₂ = 2 := by
    auto u[c₁, c₂]
  example : c₂ = 2 := by
    auto u[c₂, c₁]
  example : c₂ = 2 := by auto u[c₁] d[c₂]
  example : c₂ = 2 := by auto u[c₂] d[c₁]
  example (h : c₃ = c₁) : c₃ = 2 := by auto [h] u[c₁]
  example : let c := 2; c = 2 := by
    try auto u[c];
    auto

  example : True := by auto d[Nat.rec]

  def not' (b : Bool) :=
    match b with
    | true => false
    | false => true

  example : ∀ b, (not' b) = true ↔ b = false := by
    auto u[not', not'.match_1] d[Bool.rec]

end UnfoldConst

-- First Order

example : True := by
  auto [True.intro];

example (a b : Prop) : a ∨ b ∨ ¬ a := by
  auto

example (a b : Nat) (f : Nat → Nat)
 (eqNat : Nat → Nat → Prop) (H : eqNat (f a) (f b)) : True := by
  auto [H]

example {α β : Type} (a : α) (b : β) (H : b = b) : a = a := by
  auto [H]

example (a : Nat) (f : Nat → Nat) (H : ∀ x, f x = x) :
  f x = f (f (f (f (f (f (f (f (f x)))))))) := by
  auto [H]

example (x y : Nat) (f₁ f₂ f₃ f₄ f₅ f₆ f₇ f₈ f₉ f₁₀ f₁₁ f₁₂ f₁₃ f₁₄ : Nat → Nat → Nat)
  (H : ∀ x₁ x₂ x₃ x₄ x₅ x₆ x₇ x₈,
    f₁ (f₂ (f₃ x₁ x₂) (f₄ x₃ x₄)) (f₅ (f₆ x₅ x₆) (f₇ x₇ x₈)) =
    f₈ (f₉ (f₁₀ x₈ x₇) (f₁₁ x₆ x₅)) (f₁₂ (f₁₃ x₄ x₃) (f₁₄ x₂ x₁))) :
  True := by
  auto [H]

-- Basic examples

example (a b c d : Nat) :
  a + b + d + c = (d + a) + (c + b) := by
  auto [Nat.add_comm, Nat.add_assoc]

example (a b c : Nat) :
  a * (b + c) = b * a + a * c := by
  auto [Nat.add_comm, Nat.mul_comm, Nat.add_mul]

set_option auto.tptp true in
set_option auto.native false in
example (f : (Nat → Nat → Prop) → Prop)
  (h : ∀ (p : Nat → Nat → Prop), (∀ x, p x x) → f p) : f (fun x y => x = y) := by
  try auto [h]
  apply h; intro; rfl

-- Binders in the goal

example : 2 = 3 → 2 = 3 := by auto

-- Higher Order

example (H : (fun x : Nat => x) = (fun x => x)) : True := by
  auto [H]

example (H : (fun (x y z t : Nat) => x) = (fun x y z t => x)) : True := by
  auto [H]

example
  {α : Sort u}
  (add : ((α → α) → (α → α)) → ((α → α) → (α → α)) → ((α → α) → (α → α)))
  (Hadd : ∀ x y f n, add x y f n = (x f) ((y f) n))
  (mul : ((α → α) → (α → α)) → ((α → α) → (α → α)) → ((α → α) → (α → α)))
  (Hmul : ∀ x y f, mul x y f = x (y f))
  (w₁ w₂ : ((α → α) → (α → α)) → ((α → α) → (α → α)) → ((α → α) → (α → α)))
  (Hw₁₂ : (w₁ = w₂) = (w₂ = w₁)) : True := by
  auto [Hadd, Hmul, Hw₁₂]

example
  (f : ((Nat → Prop) → Prop) → Prop) (h : f (@Auto.Embedding.forallF Nat)):
  f (@Auto.Embedding.forallF Nat) := by
  auto

example : @Auto.Embedding.forallF Nat = @Auto.Embedding.forallF Nat := by
  auto

-- Polymorphic Constant

set_option auto.redMode "instances" in
example (as bs cs ds : List β) : (as ++ bs) ++ (cs ++ ds) = as ++ (bs ++ (cs ++ ds)) := by
  auto [List.append_assoc]

set_option auto.redMode "instances" in
example (as bs cs : List α) (f : α → β) :
  ((as ++ bs) ++ cs).map f = as.map f ++ (bs.map f ++ cs.map f) := by
  auto [List.append_assoc, List.map_append]

example (as bs cs ds : List β) :
  (as ++ bs) ++ (cs ++ ds) = as ++ (bs ++ (cs ++ ds)) := by
  auto [List.append_assoc]

example (as bs cs : List α) (f : α → β) :
  ((as ++ bs) ++ cs).map f = as.map f ++ (bs.map f ++ cs.map f) := by
  auto [List.append_assoc, List.map_append]

-- Polymorphic free variable

example
  (ap : ∀ {α : Type v}, List α → List α → List α)
  (ap_assoc : ∀ (α : Type v) (as bs cs : List α), ap (ap as bs) cs = ap as (ap bs cs)) :
  ap (ap as bs) (ap cs ds) = ap as (ap bs (ap cs ds)) := by
  auto [ap_assoc]

example
  (hap : ∀ {α β γ : Type u} [self : HAppend α β γ], α → β → γ)
  (ap_assoc : ∀ (α : Type u) (as bs cs : List α),
    @hap (List α) (List α) (List α) instHAppend (@hap (List α) (List α) (List α) instHAppend as bs) cs =
    @hap (List α) (List α) (List α) instHAppend as (@hap (List α) (List α) (List α) instHAppend bs cs)) :
  @hap (List α) (List α) (List α) instHAppend (@hap (List α) (List α) (List α) instHAppend as bs) (@hap (List α) (List α) (List α) instHAppend cs ds) =
  @hap (List α) (List α) (List α) instHAppend as (@hap (List α) (List α) (List α) instHAppend bs (@hap (List α) (List α) (List α) instHAppend cs ds)) := by
  auto [ap_assoc]

-- Metavariable

example (u : α) (h : ∀ (z : α), x = z ∧ z = y) : x = y := by
  have g : ∀ z, x = z ∧ z = y → x = y := by
    intros z hlr; have ⟨hl, hr⟩ := hlr; exact Eq.trans hl hr
  -- Notably, this example fails if we use "duper"
  apply g; auto [h]; exact u

example (α : Type u) : True := by
  have g : (∀ (ap : ∀ {α : Type u}, List α → List α → List α)
    (ap_assoc_imp : (∀ (as bs cs : List α), ap (ap as bs) cs = ap as (ap bs cs)) →
      (∀ (as bs cs ds : List α), ap (ap as bs) (ap cs ds) = ap as (ap bs (ap cs ds)))), True) := by
    intros; exact True.intro
  apply g;
  case ap_assoc_imp => intro hassoc; auto [hassoc]
  case ap => exact List.append

-- A head expression may have different dependent arguments under
--   different circumstances. This is first observed in `FunLike.coe`

section FluidDep

  variable (fundep : ∀ {α : Type u} (β : α → Type) (a : α), β a)

  example (h : @fundep α (fun _ => Nat) = fun (_ : α) => x) :
    @fundep α (fun _ => Nat) y = x := by
    auto [h]

end FluidDep

-- Defeq Problem in Types

section TypeDefeq

  class Foo where
    foo : Nat

  def inst₁ : Foo := ⟨2⟩

  def inst₂ : Foo := ⟨2⟩

  variable (fun₁ : [Foo] → Type)

  example (f : @fun₁ inst₁ → Nat) (g : @fun₁ inst₂ → Nat) (H : f = g) : g = f := by
    auto [H]

end TypeDefeq

-- Definition Recognition

section DefinitionRecognition

  set_option trace.auto.lamReif.prep.def true

  example (a b : α) (f : α → α) (H : f b = a) : True := by
    auto

  example (f g : α → β) (h : α → α) (H : ∀ x, f x = g (h x)) : True := by
    auto

  example (f : α → α → α) (g : α → α → α → α → α) (H : ∀ x y z, f x y = g x y z z) : True := by
    auto

  example (f : α → α → α) (g : α → α → α) (H : ∀ x y, f y x = g x x) : True := by
    auto

  example (f : α → α → α) (g : α → α → α) (H : (fun x y => f y x) = (fun x y => f x y)) : True := by
    auto

  example (f : α → α → α) (g : α → α → α) (H : (fun x y => f y x) = (fun x y => g x x)) : True := by
    auto

  example (f : α → α → α) (g : α → α → α) (H : (fun x y => g x x) = (fun x y => f y x)) : True := by
    auto

  example (f : α → β → γ → δ → ε) (g : α → α → ε) (H : ∀ x t z y, f x y z t = g x x) : True := by
    auto

  set_option trace.auto.lamReif.printProofs true

  example (a b : α) (f : α → α) (H : f b = a) : f (f b) = f a := by
    auto

  example (a : α) (f : α → α) (H : f a = a) : f (f a) = a := by
    auto

  example (f : α → α → α) (g : α → α → α) (H : (fun x y => f y x) = (fun x y => g x x)) :
    f b a = f c a := by
    auto

  example (H : α ↔ β) : α = β := by
    auto

  example {α : Type} (f : α → Nat → Nat → α → Nat) :
    ∀ a b c, f a 1 b c = f a 1 b c := by auto

end DefinitionRecognition

-- Ad-hoc support

section Adhoc

  -- If-then-else
  example (h₁ : if 2 < 3 then False else True) (h₂ : 2 < 3) : False := by
    auto

  example (h₁ : if 2 > 3 then True else False) (h₂ : ¬ 2 > 3) : False := by
    auto

  example {α : Sort u} {β : Sort v} (x y : α) (z t : β) :
    (if True then x else y) = x ∧ (if False then z else t) = t := by
    auto

  -- Boolean
  example : true ≠ false := by
    auto

  example : (!a && !b) = !(a || b) := by
    auto

  example
    (a b : α) [inst : Decidable (a = b)]
    (h : if (a = b) then True else a = b) : a = b := by
    auto

  -- Decide
  example : ∀ b, !(b = true) ↔ b = false := by auto

  example : ∀ b, !(b = false) ↔ b = true := by auto

  example (h : ¬ (∀ b, !(b = true) ↔ b = false)) : False := by
    auto

  -- Nat
  example (_ : ∃ b, !(!b) ≠ b) : False := by auto

  example (a b : Nat) : max a b = max a b ∧ min a b = min a b := by auto

  example (a b c : Nat) : Nat.zero = 0 ∧ 3 = nat_lit 3 ∧ (a = b ↔ b = a) ∧ Nat.succ c = c + 1 := by auto

  example : Nat.succ x = x + 1 := by auto

  example (a b : Nat) : a % b + a - b + (a / b) * b = a % b + a - b + (a / b) * b := by auto

  example (a b c d : Nat) (h₁ : a < b) (h₂ : c > d) : b > a ∧ d < c := by auto

  example (a b c d : Nat) (h₁ : a ≤ b) (h₂ : c ≥ d) : b ≥ a ∧ d ≤ c := by auto

  -- Integer
  example
    (a b : Int)
    (mul_comm : ∀ (a b : Int), a * b = b * a) : a * b + 1 = b * a + 1 := by auto

  example
    (a b : Int)
    : a * b - a % (Int.mod b a) = a * b - a % (Int.mod b a) := by auto

  example (a : Int)
    (h₁ : a ≥ 0) (h₂ : -a ≤ 0) (h₃ : 0 < 1) (h₄ : 2 > 0)
    : (a ≥ 0) ∧ (-a ≤ 0) ∧ (0 < 1) ∧ (2 > 0) := by auto

  example (a b : Int) : max a b = max a b ∧ min a b = min a b := by auto

  example : (3 : Int) = ((nat_lit 3) : Int) := by auto

  example : (-3 : Int) = (-(nat_lit 3) : Int) := by auto

  -- String
  example (a b : String)
    : "asdf" = "asdf" ∧ a ++ b = a ++ b ∧ (a < b) = (a < b) ∧
      (a > b) = (a > b) ∧ a.length = a.length := by auto

  example (a b : String)
    : String.isPrefixOf a b = String.isPrefixOf a b ∧
      String.replace a b a = String.replace a b a := by auto

  -- BitVec
  example (a : Std.BitVec k) (b : Std.BitVec 2) : a = a ∧ b = b := by auto

  example (a : Std.BitVec u) (b : Std.BitVec v) (c : Std.BitVec 2) :
    a ++ b = a ++ b ∧ b ++ c = b ++ c := by auto

  open Std.BitVec in
  example :
    0b10#3 + 0b101#3 = 0b10#3 + 0b101#3 ∧
    0b10#(3+0) * 0b101#(1+2) = 0b10#3 * 0b101#3 := by auto

  open Std.BitVec in
  #check (4+5)#(3+2)

  open Std.BitVec in
  example (a b : Nat) : (a + b)#16 = a#16 + b#16 ∧ (a * b)#16 = a#16 * b#16 := by auto

  example (a : Std.BitVec 5) (b : Std.BitVec k) :
    a.msb = a.msb ∧ b.msb = b.msb ∧
    a.rotateLeft w = a.rotateLeft w ∧
    a.rotateRight w = a.rotateRight w := by auto

  -- TPTP/SMT support for `Empty`
  set_option auto.tptp true in
  example (f : ((Empty → Prop) → Prop) → Prop) :
    f Auto.Embedding.forallF = f Auto.Embedding.forallF := by auto

  set_option auto.tptp true in
  example (f : ((Empty → Prop) → Prop) → Prop) :
    f Exists = f Exists := by auto

end Adhoc

-- Issues
section Issues

  set_option trace.auto.mono true
  set_option trace.auto.mono.printConstInst true
  set_option trace.auto.lamReif.printResult true

  -- Do not know how to deal with expression ∃ i_1, dvd i x
  -- Non-dependent ∃, but whose domain type is a `Prop`
  example (x : Nat) (primeset : Nat → Prop) (dvd : Nat → Nat → Prop) :
    ((∃ (i : _) (i_1 : primeset i), dvd i x) ↔ (∃ p, primeset p ∧ dvd p x)) := by
    auto

  -- Brute force example
  -- This must be fixed
  set_option auto.redMode "instances" in
  example : (∀ (m n k : Nat), m + n + k = m + (n + k)) := by
    intros m n k; revert m n; induction k
    case zero => auto u[Nat.add] d[Nat.rec]

end Issues
