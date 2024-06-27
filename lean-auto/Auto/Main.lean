
import Auto.Tactic
open Lean
open Auto

open IO.Process

/-- Remove comments from a TPTP/TSTP proof file -/
def cleanFile (file : String) : IO Output := do
  output ⟨⟨Stdio.inherit, Stdio.inherit, Stdio.inherit⟩, "/Users/jclune/Desktop/metis test folder/cleanup_single_problem.sh", #[file], none, #[], false⟩

def queryZipperposition (solverPath := "/Users/jclune/Desktop/zipperposition/portfolio/portfolio.lams.parallel.py")
  (problemFile : String) : IO Output := do
  let cmd := solverPath
  -- Using a 30 second timeout
  let args := #[problemFile, "30", "/Users/jclune/Desktop/tmp", "true", "-i=tptp", "-o=tptp"]
  output ⟨⟨Stdio.inherit, Stdio.inherit, Stdio.inherit⟩, cmd, args, none, #[], false⟩

def queryVampire (solverPath : String) (problemFile : String) : IO Output := do
  let cmd := solverPath
  let args :=
    #["--input_syntax", "tptp", "--output_mode", "szs", "--output_axiom_names", "on", "--time_limit", "30s",
      "--mode", "portfolio", "-sched", "casc_hol_2020", problemFile]
  output ⟨⟨Stdio.inherit, Stdio.inherit, Stdio.inherit⟩, cmd, args, none, #[], false⟩

def unsatCoreIds (cmds : Array Parser.TPTP.Command) : IO (Array String) := do
  let mut res := #[]
  for ⟨cmd, args⟩ in cmds do
    if args.length > 1 then
      if let ⟨.ident kind, []⟩ := args[1]! then
        if ["axiom", "hypothesis", "definition", "assumption", "conjecture", "type"].contains kind then
          if let ⟨.ident id, []⟩ := args[0]! then
            res := res.push id
  return res

/-- Returns `s` with only the commands from the original problem (i.e. of kind "axiom", "hypothesis", "assumption", etc.) -/
def getCoreProof (s : String) : IO String := do
  let cmds := ((s.splitOn ".\n").filter (fun cmd => cmd.data.any (fun c => !c.isWhitespace))).map (fun cmd => cmd ++ ".")
  let mut coreProof := ""
  for cmdString in cmds do
    let parsedCmdArr ← Parser.TPTP.parse cmdString
    if let #[⟨_, args⟩] := parsedCmdArr then
      if args.length > 1 then
        if let ⟨.ident kind, []⟩ := args[1]! then
          if ["axiom", "hypothesis", "definition", "assumption", "conjecture", "type"].contains kind then
            coreProof := coreProof ++ cmdString ++ "\n"
    else
      IO.println s!"Parsing error, parsedCmdArr: {parsedCmdArr}, cmdString: {cmdString}"
      return "" -- Return empty string to indicate an error occurred
  return coreProof

/-- Returns `s` with only the commands whose ids are in `ids`. This is helpful distinct from `getCoreProof` because this
    function can be used to get the original FOF format (rather than just Zipperposition's output format) -/
def getCoreProofFromIds (s : String) (ids : Array String) : IO String := do
  let cmds := ((s.splitOn ".\n").filter (fun cmd => cmd.data.any (fun c => !c.isWhitespace))).map (fun cmd => cmd ++ ".")
  let mut coreProof := ""
  for cmdString in cmds do
    let parsedCmdArr ← Parser.TPTP.parse cmdString
    if let #[⟨_, args⟩] := parsedCmdArr then
      if args.length > 1 then
        if let ⟨.ident id, []⟩ := args[0]! then
          if ids.contains id then
            coreProof := coreProof ++ cmdString ++ "\n"
          -- In adiition to the ids, we also need to make sure we copy the goal and any types and definitions
          else if let ⟨.ident kind, []⟩ := args[1]! then
            if ["type", "definition", "conjecture"].contains kind then
              coreProof := coreProof ++ cmdString ++ "\n"
    else
      IO.println s!"Parsing error, parsedCmdArr: {parsedCmdArr}, cmdString: {cmdString}"
      return "" -- Return empty string to indicate an error occurred
  return coreProof

-- This main is for running Vampire and without outputting its solution anywhere
def main : List String → IO UInt32 := fun args => do
  if args.length != 1 then
    println! "Please provide just the problem file"
    return 1
  else
    let originalProblemFile := args[0]!

    let vampireOutput ← queryVampire "/Users/jclune/Desktop/Vampire/vampire_build/bin/vampire_rel_master_6069" originalProblemFile
    let vampireProof := vampireOutput.stdout

    if (vampireProof.splitOn "SZS status Theorem").length = 1 then
      IO.println s!"Vampire did not yield SZS status Theorem for {originalProblemFile}"
      return 0
    else
      IO.println s!"Vampire solved {originalProblemFile}"
      return 0

/-
-- This main is for running Vampire and outputting its solution to the solution file (but not doing anything else)
def main : List String → IO UInt32 := fun args => do
  if args.length != 2 then
    println! "Please provide problem file and solution file"
    return 1
  else
    let originalProblemFile := args[0]!
    let solutionFile := args[1]!
    IO.FS.writeFile solutionFile "" -- Ensure that the solutionFile is overwritten even if timeout terminates main before vampire finishes

    let vampireOutput ← queryVampire "/Users/jclune/Desktop/Vampire/vampire_build/bin/vampire_rel_master_6069" originalProblemFile
    let vampireProof := vampireOutput.stdout

    if (vampireProof.splitOn "SZS status Theorem").length = 1 then
      IO.println s!"Vampire did not yield SZS status Theorem for {originalProblemFile}"
      IO.FS.writeFile solutionFile ""
      return 0
    else
      IO.println s!"Vampire solved {originalProblemFile}"
      IO.FS.writeFile solutionFile vampireProof
      -- This script just outputs the solution to the solution file. We do not construct the bushy file here
      return 0
-/

/-
-- This main is for running Zipperposition and generating the bushy problem
def main : List String → IO UInt32 := fun args => do
  if args.length != 3 then
    println! "Please provide problem file, solution file, and reduce problem file"
    return 1
  else
    let originalProblemFile := args[0]!
    let solutionFile := args[1]!
    let reducedProblemFile := args[2]!

    let zipOutput ← queryZipperposition "/Users/jclune/Desktop/zipperposition/portfolio/portfolio.lams.parallel.py" originalProblemFile
    let zipProof := zipOutput.stdout

    if (zipProof.splitOn "SZS status Theorem").length = 1 then
      IO.println s!"Zipperposition did not yield SZS status Theorem for {originalProblemFile}"
      IO.FS.writeFile solutionFile ""
      IO.FS.writeFile reducedProblemFile ""
      return 0
    else
      IO.println s!"Zipperposition solved {originalProblemFile}, creating bushy problem"
      IO.FS.writeFile solutionFile zipProof

      let cleanZipProofOutput ← cleanFile solutionFile
      let cleanZipProof := cleanZipProofOutput.stdout
      let cleanZipProofCommands ← Parser.TPTP.parse cleanZipProof
      let coreProofIds ← unsatCoreIds cleanZipProofCommands
      -- Note: This assumes that the originalProblemFile has already been cleaned of comments
      let originalProblem ← IO.FS.readFile originalProblemFile
      let coreZipProof ← getCoreProofFromIds originalProblem coreProofIds
      IO.FS.writeFile reducedProblemFile coreZipProof

      return 0
-/

/-
-- This main is for just generating bushy problems from lists of Vampire hypotheses. It does not actually call Zipperposition or Vampire
def main : List String → IO UInt32 := fun args => do
  if args.length != 3 then
    println! "Please provide problem file, solution file, and reduce problem file"
    return 1
  else
    let originalProblemFile := args[0]!
    let vampireHypsFile := args[1]!
    let reducedProblemFile := args[2]!
    IO.FS.writeFile reducedProblemFile "" -- Ensure that the solutionFile is overwritten even if timeout terminates main before vampire finishes

    let vampireHyps ← IO.FS.readFile vampireHypsFile
    if vampireHyps = "\n" || vampireHyps = "" then
      IO.println s!"Vampire did not yield SZS status Theorem for {originalProblemFile}"
      return 0
    else
      IO.println s!"Vampire solved {originalProblemFile}, creating vampire_bushy problem"
      /-
      let cleanZipProofOutput ← cleanFile solutionFile
      let cleanZipProof := cleanZipProofOutput.stdout
      let cleanZipProofCommands ← Parser.TPTP.parse cleanZipProof
      let coreProofIds ← unsatCoreIds cleanZipProofCommands
      -/
      let coreProofIds := (vampireHyps.split Char.isWhitespace).toArray

      -- Note: This assumes that the originalProblemFile has already been cleaned of comments
      let originalProblem ← IO.FS.readFile originalProblemFile
      let coreZipProof ← getCoreProofFromIds originalProblem coreProofIds
      IO.FS.writeFile reducedProblemFile coreZipProof

      return 0
-/
