module DListLowInd

open FStar
open FStar.List.Tot
open FStar.HyperStack.ST
open FStar.Ghost
open Gpointers
open FStar.Modifies

unopteq
(** Node of a doubly linked list *)
type dlist (t:Type0) = {
  (* forward link *)
  flink: gpointer_or_null (dlist t);
  (* backward link *)
  blink: gpointer_or_null (dlist t);
  (* payload *)
  p: t;
}

unopteq
(** Doubly linked list head *)
type dlisthead (t:Type0) ={
  lhead: gpointer_or_null (dlist t);
  ltail: gpointer_or_null (dlist t);
  nodes: erased (list (gpointer (dlist t)));
}

type nonempty_dlisthead t = (h:dlisthead t{is_not_null h.lhead /\ is_not_null h.ltail})

(** Initialize an element of a doubly linked list *)
val empty_entry: #t:Type -> payload:t -> dlist t
let empty_entry #t payload =
  { flink = null ; blink = null ; p = payload }

(** Initialize a doubly linked list head *)
val empty_list: #t:Type -> dlisthead t
let empty_list #t =
  { lhead = null ; ltail = null ; nodes = hide [] }

unfold let (.[]) (s:list 'a) (n:nat{n < length s}) = index s n

logic
let dlist_is_valid' (#t:Type) (h0:heap) (n:dlist t) : GTot Type0 =
  not_aliased n.flink n.blink

// logic
let dlist_is_valid (#t:Type) (h0:heap) (n:gpointer (dlist t)) : GTot Type0 =
  h0 `contains` n /\
  dlist_is_valid' h0 (n@h0)

logic
let ( |> ) (#t:Type) (a:dlist t) (b:gpointer (dlist t)) : GTot Type0 =
  a.flink ==$ b

logic
let ( <| ) (#t:Type) (a:gpointer (dlist t)) (b: dlist t) : GTot Type0 =
  b.blink ==$ a

irreducible
let ( =|> ) (#t:Type) (a:gpointer (dlist t)) (b:gpointer (dlist t)) : ST unit
    (requires (fun h0 ->
         h0 `contains` a /\ h0 `contains` b /\
         not_aliased00 a b /\
         not_aliased0 b (a@h0).blink))
    (ensures (fun h1 _ h2 ->
         modifies_1 a h1 h2 /\
         dlist_is_valid h2 a /\
         (a@h1).p == (a@h2).p /\
         (a@h1).blink == (a@h2).blink /\
         b@h1 == b@h2 /\
         (a@h2) |> b)) =
  a := { !a with flink = of_non_null b }

irreducible
let ( <|= ) (#t:Type) (a:gpointer (dlist t)) (b:gpointer (dlist t)) : ST unit
    (requires (fun h0 ->
         h0 `contains` a /\ h0 `contains` b /\
         not_aliased00 a b /\
         not_aliased0 a (b@h0).flink))
    (ensures (fun h1 _ h2 ->
         modifies_1 b h1 h2 /\
         dlist_is_valid h2 b /\
         a@h1 == a@h2 /\
         (b@h1).p == (b@h2).p /\
         (b@h1).flink == (b@h2).flink /\
         a <| (b@h2))) =
  b := { !b with blink = of_non_null a }

irreducible
let ( !=|> ) (#t:Type) (a:gpointer (dlist t)) : ST unit
    (requires (fun h0 -> h0 `contains` a))
    (ensures (fun h1 _ h2 ->
         modifies_1 a h1 h2 /\
         dlist_is_valid h2 a /\
         (a@h1).p == (a@h2).p /\
         (a@h1).blink == (a@h2).blink /\
         (a@h2).flink == null)) =
  a := { !a with flink = null }

irreducible
let ( !<|= ) (#t:Type) (a:gpointer (dlist t)) : ST unit
    (requires (fun h0 -> h0 `contains` a))
    (ensures (fun h1 _ h2 ->
         modifies_1 a h1 h2 /\
         dlist_is_valid h2 a /\
         (a@h1).p == (a@h2).p /\
         (a@h1).flink == (a@h2).flink /\
         (a@h2).blink == null)) =
  a := { !a with blink = null }

unfold let (~.) (#t:Type) (a:t) : Tot (erased (list t)) = hide ([a])
unfold let (^+) (#t:Type) (a:t) (b:erased (list t)) : Tot (erased (list t)) = elift2 Cons (hide a) b
unfold let (+^) (#t:Type) (a:erased (list t)) (b:t) : Tot (erased (list t)) = elift2 append a (hide [b])

/// A "fragment" is a list of "piece"s, such that each piece is an "almost valid" dlisthead
