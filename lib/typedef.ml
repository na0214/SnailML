type tycons = Tycon of string [@@deriving show]

type tyvar = Tyvar of string [@@deriving show]

type snail_type =
  | TyCons of tycons
  | TyVar of tyvar
  | TyApp of snail_type * snail_type
  | TyGen of int
[@@deriving show]

type scheme = Forall of snail_type [@@deriving show]

exception TypeError of string

let arrow_t = TyCons (Tycon "->")

let ( @-> ) t1 t2 = TyApp (TyApp (arrow_t, t1), t2)