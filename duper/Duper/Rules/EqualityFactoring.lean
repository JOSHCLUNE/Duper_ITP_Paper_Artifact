import Duper.RuleM
import Duper.MClause
import Duper.Clause
import Duper.Util.ProofReconstruction
import Duper.Selection

namespace Duper
open Lean
open Meta
open RuleM

initialize Lean.registerTraceClass `duper.rule.equalityFactoring

/-
  Notes on the equality_factoring_soundness proofs:
  1. s, t, u, and v should all have the same type (α) because if they didn't, then equalityFactoringWithAllConstraints would throw an error.
  2. The reason we require four soundness proofs is that from the literals s = t and u = v, we may have s unified with u, s unified with v,
     t unified with u, or t unified with v.
-/
theorem equality_factoring_soundness1 {α : Sort _} {s : α} {t : α} (v : α) (h : s = t) : t ≠ v ∨ s = v := by
  apply @Classical.byCases (s = v)
  . intro s_eq_v
    exact Or.intro_right _ s_eq_v
  . intro s_ne_v
    rw [← h]
    exact Or.intro_left _ s_ne_v

theorem equality_factoring_soundness2 {α : Sort _} {s : α} {t : α} (u : α) (h : s = t) : t ≠ u ∨ u = s := by
  apply @Classical.byCases (u = s)
  . intro u_eq_s
    exact Or.intro_right _ u_eq_s
  . intro u_ne_s
    rw [← h]
    exact Or.intro_left _ (Ne.symm u_ne_s)

theorem equality_factoring_soundness3 {α : Sort _} {s : α} {t : α} (v : α) (h : s = t) : s ≠ v ∨ t = v := by
  apply @Classical.byCases (t = v)
  . intro t_eq_v
    exact Or.intro_right _ t_eq_v
  . intro t_ne_v
    rw [h]
    exact Or.intro_left _ t_ne_v

theorem equality_factoring_soundness4 {α : Sort _} {s : α} {t : α} (u : α) (h : s = t) : s ≠ u ∨ u = t := by
  apply @Classical.byCases (u = t)
  . intro u_eq_t
    exact Or.intro_right _ u_eq_t
  . intro u_ne_t
    rw [h]
    exact Or.intro_left _ (Ne.symm u_ne_t)

def mkEqualityFactoringProof (i : Nat) (j : Nat) (litside_i : LitSide) (litside_j : LitSide) (premises : List Expr) (parents : List ProofParent)
  (transferExprs : Array Expr) (c : Clause) : MetaM Expr := do
  Meta.forallTelescope c.toForallExpr fun xs body => do
    let cLits := c.lits.map (fun l => l.map (fun e => e.instantiateRev xs))
    let (parentsLits, appliedPremises, transferExprs) ← instantiatePremises parents premises xs transferExprs
    let parentLits := parentsLits[0]!
    let appliedPremise := appliedPremises[0]!
    let mut proofCases : Array Expr := Array.mkEmpty parentLits.size
    for k in [:parentLits.size] do
      let lit := parentLits[k]!
      if k == i then
        let proofCase ← Meta.withLocalDeclD `h lit.toExpr fun h => do
          let proofCase ←
            match (litside_i, litside_j) with
            | (LitSide.lhs, LitSide.lhs) => Meta.mkAppM ``equality_factoring_soundness1 #[Lit.getOtherSide parentLits[j]! litside_j, h]
            | (LitSide.lhs, LitSide.rhs) => Meta.mkAppM ``equality_factoring_soundness2 #[Lit.getOtherSide parentLits[j]! litside_j, h]
            | (LitSide.rhs, LitSide.lhs) => Meta.mkAppM ``equality_factoring_soundness3 #[Lit.getOtherSide parentLits[j]! litside_j, h]
            | (LitSide.rhs, LitSide.rhs) => Meta.mkAppM ``equality_factoring_soundness4 #[Lit.getOtherSide parentLits[j]! litside_j, h]
          Meta.mkLambdaFVars #[h] $ ← orSubclause (cLits.map Lit.toExpr) 2 proofCase
        proofCases := proofCases.push proofCase
      else if k == j then
        let proofCase ← Meta.withLocalDeclD `h lit.toExpr fun h => do
          let idx := c.lits.size - 1
          Meta.mkLambdaFVars #[h] $ ← orIntro (cLits.map Lit.toExpr) idx h
        proofCases := proofCases.push proofCase
      else
        let proofCase ← Meta.withLocalDeclD `h lit.toExpr fun h => do
          let idx :=
            if k < j && k < i then k
            else if (i < k && k < j) || (j < k && k < i) then k - 1
            else k - 2
          Meta.mkLambdaFVars #[h] $ ← orIntro (cLits.map Lit.toExpr) idx h
        proofCases := proofCases.push proofCase
    let r ← orCases (parentLits.map Lit.toExpr) proofCases
    Meta.mkLambdaFVars xs $ mkApp r appliedPremise

/--
  Attempts to perform equality factoring on clause c with c.lits[i] as the literal to be transformed subject to the following constraints:
  1. c.lits[i].litside_i can be unified with c.lits[j].litside_j
  2. c.lits[i].litside_i is not less than c.lits[i].(LitSide.toggleSide litside_i) by the ground reduction ordering after the unification from (1)
  3. c.lits[i] is maximal and nothing is selected

  If any of these constraints fail to hold, then equalityFactoringWithAllConstraints should not do anything
-/
def equalityFactoringWithAllConstraints (given : Clause) (c : MClause) (i : Nat) (j : Nat) (litside_i : LitSide) (litside_j : LitSide) : RuleM ClauseStream :=
  withoutModifyingMCtx $ do
    let lit_i := c.lits[i]!
    let lit_j := c.lits[j]!
    let loaded ← getLoadedClauses
    let ug ← unifierGenerator #[(Lit.getSide lit_i litside_i, Lit.getSide lit_j litside_j)]
    let yC := do
      setLoadedClauses loaded
      match ← compare (Lit.getSide lit_i litside_i) (Lit.getOtherSide lit_i litside_i) (alreadyReduced := false) with
      | Comparison.LessThan => return none
      | _ =>
        if (← getSelections c (alreadyReduced := false)).isEmpty && (← c.isMaximalLit (← getOrder) (alreadyReduced := false) i) then
          let new_lit : Lit :=
            { sign := false,
              lvl := lit_i.lvl -- lit_i.lvl = lit_j.lvl
              ty := lit_i.ty -- lit_i.ty = lit_j.ty
              lhs := Lit.getOtherSide lit_i litside_i
              rhs := Lit.getOtherSide lit_j litside_j
            }
          let modified_clause :=
            if (j < i) then -- erase i first so that c.lits[j] is still at the same index after the erasure
              ((c.eraseLit i).eraseLit j).appendLits #[new_lit, c.lits[j]!]
            else -- i < j because i cannot equal j
              ((c.eraseLit j).eraseLit i).appendLits #[new_lit, c.lits[j]!]
          trace[duper.rule.equalityFactoring] "Successfully calling equality factoring on {c.lits} to yield {modified_clause.lits}"
          some <$> yieldClause modified_clause "equality factoring" (mkProof := some (mkEqualityFactoringProof i j litside_i litside_j))
        else
          return none
    return ClauseStream.mk ug given yC "equality factoring"

/--
  Attempts to perform equality factoring with c.lits[i] as the literal to be transformed
-/
def equalityFactoringAtLit (given : Clause) (c : MClause) (i : Nat) (j : Nat) : RuleM (Array ClauseStream) := do
  /-
  Note: In the Schulz paper, it states that a side condition for EqualityFactoring is that if:
  1. s and t are the terms in c.lits[i]
  2. u and v are the terms in c.lits[j]
  3. σ = mgu(s, u)
  Then σ(s) can't be less than σ(t) by the ground reduction ordering.

  Technically, the only way to check whether this is the case is to try unifying s and u for every possible combination of s and u where
  s ∈ {c.lits[i].lhs, c.lits[i].rhs} and u ∈ {c.lits[j].lhs, c.lits[j].rhs}, and then confirming whether σ(s) is greater than or equal to
  σ(t) by the ground reduction ordering.

  However, unification is expensive, and we have the convenient property that if s < t, then σ(s) < σ(t) for all σ. So in order to successfully
  carry out the inference, we will still have to check whether σ(s) < σ(t) after the unification. But in some instances, we can know that the
  inference cannot be performed for certain choices of s ∈ {c.lits[i].lhs, c.lits[i].rhs} if we can see before unification that s < t. For
  instance, if c.lits[i].lhs < c.lits[i].rhs before unification, σ(c.lits[i].lhs) < σ(c.lits[i].rhs) after unification, so we know the inference
  will be excluded regardless, and so we don't need to bother attempting to call equalityFactoringWithAllConstraints with litside_i = LitSide.lhs.

  All this to say, though its counterintuitive, it is intentional that c.lits[i].lhs and c.lits[i].rhs are compared before unification in this function
  and after unification in equalityFactoringWithAllConstraints
  -/
  match ← compare c.lits[i]!.lhs c.lits[i]!.rhs (alreadyReduced := true) with
  | Comparison.LessThan =>
    trace[duper.rule.equalityFactoring] "{c.lits[i]!.lhs} < {c.lits[i]!.rhs} by the ground reduction ordering"
    let str1 ← equalityFactoringWithAllConstraints given c i j LitSide.rhs LitSide.lhs -- Attempt to perform inference unifying c.lits[i].rhs with c.lits[j].lhs
    let str2 ← equalityFactoringWithAllConstraints given c i j LitSide.rhs LitSide.rhs -- Attempt to perform inference unifying c.lits[i].rhs with c.lits[j].rhs
    return #[str1, str2]
  | Comparison.GreaterThan =>
    trace[duper.rule.equalityFactoring] "{c.lits[i]!.lhs} > {c.lits[i]!.rhs} by the ground reduction ordering"
    let str1 ← equalityFactoringWithAllConstraints given c i j LitSide.lhs LitSide.lhs -- Attempt to perform inference unifying c.lits[i].lhs with c.lits[j].lhs
    let str2 ← equalityFactoringWithAllConstraints given c i j LitSide.lhs LitSide.rhs -- Attempt to perform inference unifying c.lits[i].lhs with c.lits[j].rhs
    return #[str1, str2]
  | _ => -- If the Comparison is Equal or Incomparable, we unfortunately have to just try all possibilities
    trace[duper.rule.equalityFactoring] "{c.lits[i]!.lhs} equal to or incomparable to {c.lits[i]!.rhs} by the ground reduction ordering"
    let str1 ← equalityFactoringWithAllConstraints given c i j LitSide.rhs LitSide.lhs -- Attempt to perform inference unifying c.lits[i].rhs with c.lits[j].lhs
    let str2 ← equalityFactoringWithAllConstraints given c i j LitSide.rhs LitSide.rhs -- Attempt to perform inference unifying c.lits[i].rhs with c.lits[j].rhs
    let str3 ← equalityFactoringWithAllConstraints given c i j LitSide.lhs LitSide.lhs -- Attempt to perform inference unifying c.lits[i].lhs with c.lits[j].lhs
    let str4 ← equalityFactoringWithAllConstraints given c i j LitSide.lhs LitSide.rhs -- Attempt to perform inference unifying c.lits[i].lhs with c.lits[j].rhs
    return #[str1, str2, str3, str4]

def equalityFactoring (given : Clause) (c : MClause) (cNum : Nat) : RuleM (Array ClauseStream) := do
  trace[duper.rule.equalityFactoring] "EqFact inferences with {c.lits}"
  let mut streams := #[]
  for i in [:c.lits.size] do
    if(c.lits[i]!.sign) then
      for j in [i+1:c.lits.size] do -- Since we call equalityFactoringAtLit c i j and equalityFactoringAtLit c j i, we can always have j > i
        if(c.lits[j]!.sign) then
          -- Attempt to perform equalityFactoring with c.lits[i] as the literal to be transformed
          trace[duper.rule.equalityFactoring] "Attempting to call equalityFactoring on {c.lits} using {c.lits[i]!} and {c.lits[j]!}"
          let str ← equalityFactoringAtLit given c i j
          streams := streams.append str
          -- Attempt to perform equalityFactoring with c.lits[j] as the literal to be transformed
          let str ← equalityFactoringAtLit given c j i
          streams := streams.append str
  return streams

end Duper
