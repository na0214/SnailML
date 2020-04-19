open Syntax
open Typedef

type subst = (tyvar * snail_type) list

type context = (string * scheme) list

let rec get_unique_tyvar typ =
  match typ with
  | TyVar (Tyvar n) ->
      [Tyvar n]
  | TyApp (typ1, typ2) ->
      ExtList.List.unique (get_unique_tyvar typ1 @ get_unique_tyvar typ2)
  | _ ->
      []

let diff_list l1 l2 = List.filter (fun x -> List.mem x l2 |> not) l1

let rec unfold_right f init =
  match f init with None -> [] | Some (x, next) -> x :: unfold_right f next

let range n =
  let irange x = if x > n then None else Some (x, x + 1) in
  unfold_right irange 1

let rec apply_subst sb typ =
  match typ with
  | TyVar v -> (
    try List.assoc v sb with Not_found -> TyVar v )
  | TyApp (typ1, typ2) ->
      TyApp (apply_subst sb typ1, apply_subst sb typ2)
  | other_typ ->
      other_typ

let quantification typ ctx =
  let unique_tyvar =
    diff_list (get_unique_tyvar typ)
      (List.fold_left
         (fun acc ct -> match ct with _, Forall t -> acc @ get_unique_tyvar t)
         [] ctx)
  in
  let tyvar_with_gen =
    match
      Base.List.zip unique_tyvar
        (List.map (fun x -> TyGen x) (List.length unique_tyvar |> range))
    with
    | Base.List.Or_unequal_lengths.Ok zl ->
        zl
    | Base.List.Or_unequal_lengths.Unequal_lengths ->
        TypeError "not match length" |> raise
  in
  Forall (apply_subst tyvar_with_gen typ)

let find_context name ctx =
  try List.assoc name ctx
  with Not_found -> TypeError ("unbound identifier: " ^ name) |> raise

let append_subst sb1 sb2 =
  sb1 @ List.map (fun x -> match x with u, t -> (u, apply_subst sb1 t)) sb2

let var_bind v t =
  if t = TyVar v then []
  else if List.mem v (get_unique_tyvar t) then
    TypeError "occurs check fails" |> raise
  else [(v, t)]

let rec mgu typ1 typ2 =
  match (typ1, typ2) with
  | TyApp (tl1, tr1), TyApp (tl2, tr2) ->
      let s1 = mgu tl1 tl2 in
      let s2 = mgu (apply_subst s1 tr1) (apply_subst s1 tr2) in
      append_subst s2 s1
  | TyVar v, t ->
      var_bind v t
  | t, TyVar v ->
      var_bind v t
  | TyCons tc1, TyCons tc2 when tc1 = tc2 ->
      []
  | _ ->
      TypeError "types do not unify" |> raise

let unify typ1 typ2 sb =
  match !sb with
  | s, n ->
      let u = mgu (apply_subst s typ1) (apply_subst s typ2) in
      sb := (append_subst u s, n)

let new_tyvar sb =
  match !sb with
  | s, n ->
      sb := (s, n + 1) ;
      TyVar (Tyvar (string_of_int n))

let get_subst sb = match !sb with s, _ -> s

let rec instantiate typ tyvar_list =
  match typ with
  | TyApp (typ1, typ2) ->
      TyApp (instantiate typ1 tyvar_list, instantiate typ2 tyvar_list)
  | TyGen n ->
      List.assoc n tyvar_list
  | t ->
      t

let fresh_inst sc sb =
  match sc with
  | Forall t ->
      let new_tyvar_list =
        List.fold_left
          (fun acc n -> (n, new_tyvar sb) :: acc)
          []
          (List.length (get_subst sb) |> range)
      in
      instantiate t new_tyvar_list

let rec infer term typ (ctx : context) sb =
  match term with
  | IntLit (_, _) ->
      unify (TyCons (Tycon "Int")) typ sb
  | FloatLit (_, _) ->
      unify (TyCons (Tycon "Float")) typ sb
  | StringLit (_, _) ->
      unify (TyCons (Tycon "String")) typ sb
  | Fun (name, sub_term, _) ->
      let a = new_tyvar sb in
      let b = new_tyvar sb in
      unify (a @-> b) typ sb ;
      let new_ctx = (name, Forall a) :: ctx in
      infer sub_term b new_ctx sb
  | Var (name, _) ->
      let sc = find_context name ctx in
      let typ1 = fresh_inst sc sb in
      unify typ1 typ sb
  | _ ->
      TypeError "inference error" |> raise

let typeof term ctx =
  let sb = ref ([], 0) in
  let result_t = new_tyvar sb in
  infer term result_t ctx sb ;
  apply_subst (get_subst sb) result_t
