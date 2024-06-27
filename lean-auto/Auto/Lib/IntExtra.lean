import Auto.Lib.NatExtra
import Std.Data.Int.Lemmas
namespace Auto

def Int.beq : Int → Int → Bool
| .ofNat n₁,   .ofNat n₂   => n₁.beq n₂
| .negSucc n₁, .negSucc n₂ => n₁.beq n₂
| _,           _           => false

instance : BEq Int where
  beq := Int.beq

theorem Int.beq_def {a b : Int} : (a == b) = Int.beq a b := rfl

def Int.beq_refl : {i : Int} → (Int.beq i i) = true
| .ofNat n => Nat.beq_refl' n
| .negSucc n => Nat.beq_refl' n

def Int.eq_of_beq_eq_true {i₁ i₂ : Int} : Int.beq i₁ i₂ → i₁ = i₂ :=
  match i₁, i₂ with
  | .ofNat n₁, .ofNat n₂ => fun H => congrArg _ (Nat.eq_of_beq_eq_true H)
  | .negSucc n₁, .negSucc n₂ => fun H => congrArg _ (Nat.eq_of_beq_eq_true H)
  | .ofNat n₁, .negSucc n₂ => fun H => by cases H
  | .negSucc n₁, .ofNat n₂ => fun H => by cases H

instance : LawfulBEq Int where
  eq_of_beq := Int.eq_of_beq_eq_true
  rfl := Int.beq_refl

def Int.abs (x : Int) := ite (x ≤ (-x)) (-x) x

theorem Int.shiftRight_def (i : Int) (s : Nat) : i >>> s =
  match i with
  | Int.ofNat n => Int.ofNat (n >>> s)
  | Int.negSucc n => Int.negSucc (n >>> s) := by
  cases i <;> rfl

end Auto
