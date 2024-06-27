import Lean
import Auto.Lib.MonadUtils
open Lean

-- smt-lib 2

namespace Auto

namespace IR.SMT

-- <index>      ::= <numeral> | <symbol>
-- <identifier> ::= <symbol>  | (_ <symbol> <index>+)

private instance : Hashable (String ⊕ Nat) where
  hash : String ⊕ Nat → UInt64
  | .inl s => hash ("0" ++ s)
  | .inr n => hash ("1" ++ toString n)

inductive SIdent where
  | symb    : String → SIdent
  | indexed : String → Array (String ⊕ Nat) → SIdent
deriving BEq, Hashable, Inhabited

def SIdent.toString : SIdent → String
| .symb s => "|" ++ s ++ "|"
| .indexed s idx =>
  s!"(_ {s} " ++ String.intercalate " " (idx.data.map (fun idx =>
    match idx with
    | .inl idx => s!"{idx}"
    | .inr idx => s!"{idx}")) ++ ")"

instance : ToString SIdent where
  toString := SIdent.toString

inductive SSort where
  | bvar : Nat → SSort -- Only useful in sort declarations
  | app : SIdent → Array SSort → SSort
deriving BEq, Hashable, Inhabited

private def SSort.toStringAux : SSort → List SIdent → String
| .bvar i, binders =>
  if h : i < binders.length then
    s!"{binders[i]}"
  else
    panic!"SSort.toString :: Loose bound variable"
| .app i ⟨[]⟩, _ => s!"{i}"
| .app i ⟨a :: as⟩, binders =>
  let intro := s!"({i} "
  let head := SSort.toStringAux a binders ++ " "
  let tail := String.intercalate " " (go as binders)
  intro ++ head ++ tail ++ ")"
where go : List SSort → List SIdent →  List String
| [], _ => []
| a :: as, binders => SSort.toStringAux a binders :: go as binders

def SSort.toString (s : SSort) (binders : Array SIdent) : String :=
  SSort.toStringAux s binders.data

/-- Caution : Do not use this in define-sort, because sort there might contain bvars -/
instance : ToString SSort where
  toString s := SSort.toString s #[]

/--〈qual_identifier〉 ::= 〈identifier〉 | ( as 〈identifier〉 〈sort〉 ) -/
inductive QualIdent where
  | ident   : SIdent → QualIdent
  | qualed  : SIdent → SSort → QualIdent
deriving BEq, Hashable, Inhabited

def QualIdent.ofString (s : String) : QualIdent := .ident (.symb s)

instance : ToString QualIdent where
  toString : QualIdent → String
  | .ident i => toString i
  | .qualed i s => s!"(as {i} {s})"

structure MatchCase (α : Sort u) where
  constr : String
  args   : Array String
  body   : α

-- **TODO**: Float-point numbers?
inductive SpecConst where
  | str    : String → SpecConst
  -- `.binary [xₖ₋₁, ⋯, x₁, x₀]` represents `xₖ₋₁⋯x₁x₀`
  | binary : List Bool → SpecConst
  | num    : Nat → SpecConst

def SpecConst.toString : SpecConst → String
| .str s     => "\"" ++ String.join (s.toList.map specCharRepr) ++ "\""
| .binary bs => bs.foldl (fun acc b => acc.push (if b then '1' else '0')) "#b"
| .num n     => ToString.toString (repr n)
where specCharRepr (c : Char) : String :=
  "\\u{" ++ String.mk (Nat.toDigits 16 c.toNat) ++ "}"

mutual

  inductive STerm where
    | sConst  : SpecConst → STerm
    | bvar    : Nat → STerm                      -- De bruijin index
    | qIdApp  : QualIdent → Array STerm → STerm  -- Application of function symbol to array of terms
    | letE    : (name : String) → (binding : STerm) → (body : STerm) → STerm
    | forallE : (name : String) → (binderType : SSort) → (body : STerm) → STerm
    | existE  : (name : String) → (binderType : SSort) → (body : STerm) → STerm
    | matchE  : (matchTerm : STerm) → Array (MatchCase STerm) → STerm
    | attr    : STerm → Array Attribute → STerm

  /--
   〈attribute_value〉 ::= 〈spec_constant〉 | 〈symbol〉 | (〈s_expr〉∗ )
   〈attribute〉 ::= 〈keyword〉 | 〈keyword〉〈attribute_value〉
  -/
  inductive Attribute where
    | none  : String → Attribute
    | spec  : String → SpecConst → Attribute
    | symb  : String → String → Attribute
    | sexpr : String → Array STerm → Attribute

end

def STerm.qStrApp (s : String) (arr : Array STerm) := STerm.qIdApp (.ofString s) arr

private partial def STerm.toStringAux : STerm → List SIdent → String
  | .sConst c, _         => SpecConst.toString c
  | .bvar i, binders   =>
    if let some si := binders.get? i then
      ToString.toString si
    else
      panic!"STerm.toString :: Loose bound variable"
  | .qIdApp si ⟨[]⟩, _   => ToString.toString si
  | .qIdApp si ⟨a :: as⟩, binders =>
    let intro := s!"({si} "
    let tail := String.intercalate " " (STerm.toStringAux a binders :: goQIdApp as binders)
    intro ++ tail ++ ")"
  | .letE name binding body, binders =>
    let binders := (SIdent.symb name) :: binders
    let intro := s!"(let ({SIdent.symb name} "
    let binding := STerm.toStringAux binding binders ++ ") "
    let body := STerm.toStringAux body binders ++ ")"
    intro ++ binding ++ body
  | .forallE name binderType body, binders =>
    let binders := (SIdent.symb name) :: binders
    let intro := s!"(forall (({SIdent.symb name} "
    let binderType := ToString.toString binderType ++ ")) "
    let body := STerm.toStringAux body binders ++ ")"
    intro ++ binderType ++ body
  | .existE name binderType body, binders =>
    let binders := (SIdent.symb name) :: binders
    let intro := s!"(exists (({SIdent.symb name} "
    let binderType := ToString.toString binderType ++ ")) "
    let body := STerm.toStringAux body binders ++ ")"
    intro ++ binderType ++ body
  | .matchE _ ⟨[]⟩, _ => panic!"STerm.toString :: Zero match branches"
  | .matchE matchTerm ⟨a :: as⟩, binders =>
    let intro := s!"(match " ++ STerm.toStringAux matchTerm binders ++ " ("
    let intro := intro ++ goMatchBranch a binders
    let body := String.join ((goMatchBody as binders).map (fun s => " " ++ s)) ++ "))"
    intro ++ body
  | .attr t attrs, binders =>
    let intro := "(! " ++ STerm.toStringAux t binders ++ " "
    let sattrs := String.intercalate " " (attrs.data.map (attrToStringAux · binders))
    intro ++ sattrs ++ ")"
where
  goQIdApp : List STerm → List SIdent → List String
    | [], _ => []
    | a :: as, binders => STerm.toStringAux a binders :: goQIdApp as binders
  goMatchBranch : MatchCase STerm → List SIdent → String
    | ⟨constr, args, body⟩, binders =>
      if args.size == 0 then
        let body := " " ++ STerm.toStringAux body binders ++ ")"
        let pattern := "(" ++ (ToString.toString (SIdent.symb constr))
        pattern ++ body
      else
        let binders := args.data.map .symb ++ binders
        let body := " " ++ STerm.toStringAux body binders ++ ")"
        let args := args.data.map (fun x => ToString.toString (SIdent.symb x))
        let pattern := "((" ++ String.intercalate " " (ToString.toString (SIdent.symb constr) :: args) ++ ")"
        pattern ++ body
  goMatchBody : List (MatchCase STerm) → List SIdent → List String
    | [], _ => []
    | a :: as, binders => goMatchBranch a binders :: goMatchBody as binders
  attrToStringAux : Attribute → List SIdent → String
    | .none s,     _ => ":" ++ s
    | .spec s sc,  _ => s!":{s} {sc.toString}"
    | .symb s s',  _ => s!":{s} {s'}"
    | .sexpr s ts, binders => s!":{s} (" ++ String.intercalate " " (ts.data.map (STerm.toStringAux · binders)) ++ ")"

def STerm.toString (t : STerm) (binders : Array SIdent) : String :=
  STerm.toStringAux t binders.data

instance : ToString STerm where
  toString t := STerm.toString t #[]

def Attribute.toString (attr : Attribute) (binders : Array SIdent) : String :=
  SMT.STerm.toStringAux.attrToStringAux attr binders.data

instance : ToString Attribute where
  toString attr := Attribute.toString attr #[]

/--
 〈selector_dec〉 ::= ( 〈symbol〉 〈sort〉 )
 〈constructor_dec〉 ::= ( 〈symbol〉 〈selector_dec〉∗ )
-/
structure ConstrDecl where
  name     : String
  selDecls : Array (String × SSort)

private def ConstrDecl.toString : ConstrDecl → Array SIdent → String
| ⟨name, selDecls⟩, binders =>
  let pre := s!"({SIdent.symb name}"
  let selDecls := selDecls.map (fun (name, sort) => s!"({SIdent.symb name} " ++ SSort.toString sort binders ++ ")")
  String.intercalate " " (pre :: selDecls.data) ++ ")"

/--
 〈datatype_dec〉 ::= ( 〈constructor_dec〉+ ) | ( par ( 〈symbol 〉+ ) ( 〈constructor_dec〉+ ) )
-/
structure DatatypeDecl where
  params : Array String
  cstrDecls : Array ConstrDecl

private def DatatypeDecl.toString : DatatypeDecl → String := fun ⟨params, cstrDecls⟩ =>
  let scstrDecls := cstrDecls.map (fun d => ConstrDecl.toString d (params.map SIdent.symb))
  let scstrDecls := "(" ++ String.intercalate " " scstrDecls.data ++ ")"
  if params.size == 0 then
    scstrDecls
  else
    "(par ("  ++ String.intercalate " " params.data ++ ") " ++ scstrDecls ++ ")"

inductive SMTOption where
  | diagnosticOC            : String → SMTOption
  | globalDecl              : Bool → SMTOption
  | interactiveMode         : Bool → SMTOption
  | printSuccess            : Bool → SMTOption
  | produceAssertions       : Bool → SMTOption
  | produceAssignments      : Bool → SMTOption
  | produceModels           : Bool → SMTOption
  | produceProofs           : Bool → SMTOption
  | produceUnsatAssumptions : Bool → SMTOption
  | produceUnsatCores       : Bool → SMTOption
  | randomSeed              : Nat → SMTOption
  | regularOutputChannel    : String → SMTOption
  | reproducibleResourceLim : Nat → SMTOption
  | verbosity               : Nat → SMTOption
  | attr                    : Attribute → SMTOption

def SMTOption.toString : SMTOption → String
| .diagnosticOC s            => s!":diagnostic-output-channel {s}"
| .globalDecl b              => s!":global-declarations {b}"
| .interactiveMode b         => s!":interactive-mode {b}"
| .printSuccess b            => s!":print-success {b}"
| .produceAssertions b       => s!":produce-assertions {b}"
| .produceAssignments b      => s!":produce-assignments {b}"
| .produceModels b           => s!":produce-models {b}"
| .produceProofs b           => s!":produce-proofs {b}"
| .produceUnsatAssumptions b => s!":produce-unsat-assumptions {b}"
| .produceUnsatCores b       => s!":produce-unsat-cores {b}"
| .randomSeed n              => s!":random-seed {n}"
| .regularOutputChannel s    => s!":regular-output-channel {s}"
| .reproducibleResourceLim n => s!":reproducible-resource-limit {n}"
| .verbosity n               => s!":verbosity {n}"
| .attr a                    => ToString.toString a

instance : ToString SMTOption where
  toString := SMTOption.toString

/--
 〈sorted_var〉   ::= ( 〈symbol〉 〈sort〉 )
 〈datatype_dec〉 ::= ( 〈constructor_dec〉+ ) | ( par ( 〈symbol〉+ ) ( 〈constructor_dec〉+ ) )
 〈function_dec〉 ::= ( 〈symbol〉 ( 〈sorted_var〉∗ ) 〈sort〉 )
 〈function_def〉 ::= 〈symbol〉 ( 〈sorted_var〉∗ ) 〈sort〉 〈term〉
  command   ::= ( assert 〈term〉 )
                ( check-sat )
                ...
                ( declare-fun 〈symbol〉 ( 〈sort〉∗ ) 〈sort〉 )
                ( declare-sort 〈symbol〉 〈numeral〉 )
                ( define-fun 〈function_def〉 )
                ( define-fun-rec 〈function_def〉 )
                ( define-sort 〈symbol〉 ( 〈symbol〉∗ ) 〈sort〉 )
                ( declare-datatype 〈symbol〉 〈datatype_dec〉)
                ...
                ( get-model )
                ( get-option 〈keyword〉 )
                ( get-proof )
                ( get-unsat-assumptions )
                ( get-unsat-core )
                ...
                ( set-option 〈option〉 )
                ( set-logic 〈symbol 〉 )
-/
inductive Command where
  | assert     : (prop : STerm) → Command
  | setLogic   : String → Command
  | setOption  : SMTOption → Command
  | getModel   : Command
  | getOption  : String → Command
  | getProof   : Command
  | getUnsatAssumptions : Command
  | getUnsatCore        : Command
  | checkSat   : Command
  | declFun    : (name : String) → (argSorts : Array SSort) → (resSort : SSort) → Command
  | declSort   : (name : String) → (arity : Nat) → Command
  | defFun     : (isRec : Bool) → (name : String) → (args : Array (String × SSort)) →
                   (resTy : SSort) → (body : STerm) → Command
  | defSort    : (name : String) → (args : Array String) → (body : SSort) → Command
  | declDtype  : (name : String) → DatatypeDecl → Command
  -- String × Nat : sort_dec
  -- String : Name of datatype
  -- Nat    : Number of parameters of the datatype
  | declDtypes : Array (String × Nat × DatatypeDecl) → Command
  | exit       : Command

def Command.toString : Command → String
| .assert prop                         => s!"(assert {prop})"
| .setLogic l                          => "(set-logic " ++ l ++ ")"
| .setOption o                         => s!"(set-option {o})"
| .getModel                            => "(get-model)"
| .getOption s                         => s!"(get-option {s})"
| .getProof                            => "(get-proof)"
| .getUnsatAssumptions                 => "(get-unsat-assumptions)"
| .getUnsatCore                        => "(get-unsat-core)"
| .checkSat                            => "(check-sat)"
| .declFun name argSorts resSort       =>
  let pre := s!"(declare-fun {SIdent.symb name} ("
  let argSorts := String.intercalate " " (argSorts.map ToString.toString).data ++ ") "
  let trail := s!"{resSort})"
  pre ++ argSorts ++ trail
| .declSort name arity                 => s!"(declare-sort {SIdent.symb name} {arity})"
| .defFun isRec name args resTy body =>
  let pre := if isRec then "(define-fun-rec " else "(define-fun "
  let pre := pre ++ ToString.toString (SIdent.symb name) ++ " "
  let binders := "(" ++ String.intercalate " " (args.map (fun (name, sort) => s!"({SIdent.symb name} {sort})")).data ++ ") "
  let trail := s!"{resTy} " ++ STerm.toString body (args.map (fun (name, _) => SIdent.symb name)) ++ ")"
  pre ++ binders ++ trail
| .defSort name args body              =>
  let pre := s!"(define-sort {SIdent.symb name} ("
  let sargs := String.intercalate " " args.data ++ ") "
  let trail := SSort.toString body (args.map SIdent.symb) ++ ")"
  pre ++ sargs ++ trail
| .declDtype name ddecl                =>
  s!"(declare-datatype {SIdent.symb name} {ddecl.toString})"
| .declDtypes infos               =>
  let sort_decs := String.intercalate " " (infos.data.map (fun (name, args, _) => s!"({name} {args})"))
  let datatype_decs := String.intercalate " " (infos.data.map (fun (_, _, ddecl) => ddecl.toString))
  s!"(declare-datatypes ({sort_decs}) ({datatype_decs}))"
| .exit                                => "(exit)"

instance : ToString Command where
  toString := Command.toString

section

  -- Type of (identifiers in higher-level logic)
  variable (ω : Type) [BEq ω] [Hashable ω]

  /--
    The main purpose of this state is for name generation
      and symbol declaration/definition, so we do not distinguish
      between sort identifiers, datatype identifiers
      and function identifiers
  -/
  structure State where
    -- Map from high-level construct to symbol
    h2lMap   : HashMap ω String := {}
    -- Inverse of `h2lMap`
    -- Map from symbol to high-level construct
    l2hMap   : HashMap String ω := {}
    -- State of low-level name generator
    --   To avoid collision with keywords, we only
    --   generate non-annotated identifiers `smti_<idx>`
    idx      : Nat              := 0
    -- List of commands
    commands : Array Command    := #[]

  abbrev TransM := StateRefT (State ω) MetaM

  variable {ω : Type} [BEq ω] [Hashable ω]

  @[always_inline]
  instance : Monad (TransM ω) :=
    let i := inferInstanceAs (Monad (TransM ω));
    { pure := i.pure, bind := i.bind }

  instance : Inhabited (TransM ω α) where
    default := fun _ => throw default

  variable {ω : Type} [BEq ω] [Hashable ω]

  @[inline] def TransM.run (x : TransM ω α) (s : State ω := {}) : MetaM (α × State ω) :=
    StateRefT'.run x s

  @[inline] def TransM.run' (x : TransM ω α) (s : State ω := {}) : MetaM α :=
    Prod.fst <$> StateRefT'.run x s

  #genMonadState (TransM ω)

  def getMapSize : TransM ω Nat := do
    let size := (← getH2lMap).size
    assert! ((← getL2hMap).size == size)
    return size

  def hIn (e : ω) : TransM ω Bool := do
    return (← getH2lMap).contains e

  /-- Used for e.g. bound variables -/
  partial def disposableName : TransM ω String := do
    let l2hMap ← getL2hMap
    let idx ← getIdx
    let currName := s!"smtd_{idx}"
    if l2hMap.contains currName then
      throwError "disposableName :: Unexpected error"
    setIdx (idx + 1)
    return currName

  /--
    Turn high-level construct into low-level symbol
    Note that this function is idempotent
  -/
  partial def h2Symb (cstr : ω) : TransM ω String := do
    let l2hMap ← getL2hMap
    let h2lMap ← getH2lMap
    if let .some name := h2lMap.find? cstr then
      return name
    let idx ← getIdx
    let currName : String := s!"smti_{idx}"
    if l2hMap.contains currName then
      throwError "h2Symb :: Unexpected error"
    setL2hMap (l2hMap.insert currName cstr)
    setH2lMap (h2lMap.insert cstr currName)
    setIdx (idx + 1)
    return currName

  def addCommand (c : Command) : TransM ω Unit := do
    let commands ← getCommands
    setCommands (commands.push c)

end

end IR.SMT

end Auto
