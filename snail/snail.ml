open Snailml

let _ =
  let input_files = ref [] in
  let arguments_spec =
    []
  in
  Arg.parse_argv Sys.argv arguments_spec
    (fun str -> input_files := str :: !input_files)
    "" ;
  Processing.processing !input_files
