open Syntax

type eval_object =
  | Eval_Int of int
  | Eval_Float of float
  | Eval_String of string
  | Eval_Pair of eval_object * eval_object
  | Eval_Func of string * term
  | Eval_Data of string * eval_object
  | Eval_Cons of string
[@@deriving show]

exception RuntimeError of string

type eval_context = (string * eval_object) list [@@deriving show]

let find_eval_context name ctx =
  try List.assoc name ctx
  with Not_found -> RuntimeError ("unbound identifier:" ^ name) |> raise

let rec replace_variable name base_term term =
  match base_term with
  | Let (rec_flag, n, uname, arguments, sub_term1, sub_term2, pos) ->
      Let
        ( rec_flag
        , n
        , uname
        , arguments
        , replace_variable name sub_term1 term
        , replace_variable name sub_term2 term
        , pos )
  | Fun (arguments, n, subterm, pos) ->
      Fun (arguments, n, replace_variable name subterm term, pos)
  | App (sub_term1, sub_term2) ->
      App
        ( replace_variable name sub_term1 term
        , replace_variable name sub_term2 term )
  | Prod (sub_term1, sub_term2, pos) ->
      Prod
        ( replace_variable name sub_term1 term
        , replace_variable name sub_term2 term
        , pos )
  | Var (n, uname, pos) ->
      if name = n then term else Var (n, uname, pos)
  | s ->
      s

let rec apply_term term1 term2 ctx =
  match term1 with
  | Eval_Func (argument, subterm) ->
      eval_term (replace_variable argument subterm term2) ctx
  | Eval_Cons cons_name ->
      Eval_Data (cons_name, eval_term term2 ctx)
  | _ ->
      RuntimeError "cannot apply" |> raise

and eval_term term eval_ctx =
  match term with
  | IntLit (n, _) ->
      Eval_Int n
  | FloatLit (f, _) ->
      Eval_Float f
  | StringLit (s, _) ->
      Eval_String s
  | Prod (sub_term1, sub_term2, _) ->
      let fst_obj = eval_term sub_term1 eval_ctx in
      let snd_obj = eval_term sub_term2 eval_ctx in
      Eval_Data ("(,)", Eval_Pair (fst_obj, snd_obj))
  | Fun ([name], _, sub_term, _) ->
      Eval_Func (name, sub_term)
  | App (sub_term1, sub_term2) ->
      apply_term (eval_term sub_term1 eval_ctx) sub_term2 eval_ctx
  | Var (name, uname, _) ->
      if uname = "" then find_eval_context name eval_ctx
      else find_eval_context uname eval_ctx
  | Cons (name, _) ->
      Eval_Cons name
  | Let (rec_flag, _, uname, _, sub_term1, sub_term2, pos) ->
      let sub_term_result =
        if rec_flag then
          eval_term sub_term1
            ( (uname, eval_term (Fun ([uname], "", sub_term1, pos)) eval_ctx)
            :: eval_ctx )
        else eval_term sub_term1 eval_ctx
      in
      eval_term sub_term2 ((uname, sub_term_result) :: eval_ctx)
  | _ ->
      Eval_String "None"

let eval =
  List.fold_left
    (fun acc x ->
      match x with
      | LetDec (name, _, term, _) ->
          let result = eval_term term acc in
          (name, result) :: acc
      | _ ->
          acc)
    []