module DList

open FStar
open FStar.Ghost
open FStar.Seq
open FStar.HyperStack
open FStar.HyperStack.ST
open FStar.Buffer
open FStar.Int
open C
open C.Nullity
module U64 = FStar.UInt64
module U32 = FStar.UInt32
module U16 = FStar.UInt16
module U8 = FStar.UInt8
module Seq = FStar.Seq
module Ghost = FStar.Ghost
module ST = FStar.HyperStack.ST

(** Type of a network buffer *)
type buffer_t = Buffer.buffer(UInt8.t)

unopteq
(** A doubly-linked list of a type*)
type dlist (t:Type0) = {
(* Forward link *)
  flink: pointer_or_null (dlist t);
(* Backward link *)
  blink: pointer_or_null (dlist t);
(* payload *)
  p: t;
}

unopteq
(** Head of a doubly linked list *)
type dlisthead (t:Type) = {
  (* head forward link *)
  lhead: pointer_or_null (dlist t);
  (* head backward link *)
  ltail: pointer_or_null (dlist t);
  (* all nodes in this dlist *)
  nodes: erased (seq (dlist t))
}

(** Be able to use [null] very very easily *)
inline_for_extraction private unfold
let null #t = null t

(** Initialze an element of a doubly linked list *)
let empty_entry (#t:Type) (payload:t): dlist(t) =
  { flink = null; blink = null; p = payload; }

(** Initialize a doubly-linked list head *)
let empty_list (#t:Type) : dlisthead t =
  { lhead = null; ltail = null; nodes = hide createEmpty}

unfold let op_At_Bang (#t:Type) (h0:mem) (p:pointer t) = Buffer.get h0 p 0
unfold let op_String_Access = Seq.index
unfold let not_null (#t:Type) (a:pointer_or_null t) = Buffer.length a <> 0

let test_1 () = assert (forall (t:Type) (p:pointer_or_null t). is_null p \/ not_null p)

let dlist_is_valid (#t:Type) (d:dlist t) =
  disjoint_1 d.flink d.blink

let test_2 () = assert (forall t p. dlist_is_valid (empty_entry #t p))

let dlisthead_nullness (#t:Type) (h0:mem) (h:dlisthead t) =
  let nodes = Ghost.reveal h.nodes in
  let l : nat = Seq.length nodes in
  (l > 0 ==> (not_null h.ltail /\ not_null h.lhead /\
              is_null (h0@! h.lhead).blink /\
              is_null (h0@! h.ltail).flink)) /\
  (l = 0 ==> (is_null h.ltail /\ is_null h.lhead))

let dlisthead_liveness (#t:Type) (h0:mem) (h:dlisthead t) =
  let nodes = Ghost.reveal h.nodes in
  let l = Seq.length nodes in
    live h0 h.lhead /\ live h0 h.ltail

let non_empty_dlisthead_connect_to_nodes (#t:Type) (h0:mem) (h:dlisthead t) =
  let nodes = Ghost.reveal h.nodes in
  let l : nat = Seq.length nodes in
  dlisthead_nullness h0 h /\
  (l > 0 ==> (h0@! h.ltail == nodes.[l-1] /\
              h0@! h.lhead == nodes.[0]))

let non_empty_dlisthead_is_valid (#t:Type) (h0:mem) (h:dlisthead t) =
  let nodes = Ghost.reveal h.nodes in
  let l = Seq.length nodes in
  let nonempty = l > 0 in
  non_empty_dlisthead_connect_to_nodes h0 h /\
  (nonempty ==> (forall i. {:pattern (nodes.[i]).blink}
                   ((1 <= i /\ i < l) ==>
                    not_null (nodes.[i]).blink /\
                    h0@! (nodes.[i]).blink == nodes.[i-1])) /\
                (forall i. {:pattern (nodes.[i]).flink}
                   ((0 <= i /\ i < l - 1) ==>
                    not_null (nodes.[i]).flink /\
                    h0@! (nodes.[i]).flink == nodes.[i+1])))

let dlisthead_has_valid_dlists (#t:Type) (h0:mem) (h:dlisthead t) =
  let nodes = Ghost.reveal h.nodes in
  (forall i. {:pattern dlist_is_valid nodes.[i]} dlist_is_valid nodes.[i])

let dlisthead_is_valid (#t:Type) (h0:mem) (h:dlisthead t) =
  dlisthead_liveness h0 h /\
  dlisthead_has_valid_dlists h0 h /\
  non_empty_dlisthead_is_valid h0 h

let test_3 () = assert (forall t. forall h0. dlisthead_nullness #t h0 empty_list)

unfold
let dlist_is_member_of (#t:eqtype) (h0:mem) (e:pointer (dlist t)) (h:dlisthead t) =
  Seq.mem (h0@! e) (Ghost.reveal h.nodes)

unfold inline_for_extraction
let (<&) (#t:Type) (p:pointer t) (x:t) =
  p.(0ul) <- x

unfold
let erased_single_node (#t:eqtype) (e:pointer (dlist t)) =
  hide (Seq.create 1 !*e)

// #set-options "--z3rlimit 1" // Forces it to quickly hit resource bounds and then --detail_errors seems to get it through ¯\_(ツ)_/¯

// #set-options "--z3rlimit 40"

let createSingletonList (#t:eqtype) (e:pointer (dlist t)): Stack (dlisthead t)
    (requires (fun h0 -> live h0 e))
    (ensures (fun h1 y h2 -> modifies_1 e h1 h2 /\ live h2 e /\ dlisthead_is_valid h2 y)) =
  e <& { !*e with flink=null; blink = null }; // isn't this inefficient?
  { lhead = e; ltail = e; nodes = erased_single_node e }

let rec replace_in_seq (#t:eqtype) (s:seq t) (x:t) (x_new:t) :
  Pure (seq t)
    (requires True)
    (ensures (fun y ->
         (Seq.mem x s ==> Seq.mem x_new y) /\
         (forall v. {:pattern Seq.mem v y} (Seq.mem v s /\ v <> x) ==> Seq.mem v y)))
    (decreases (Seq.length s)) =
  let open Seq in
  match Seq.length s with
  | 0 -> s
  | _ ->
    if s.[0] = x
    then (Seq.Properties.mem_cons x_new (tail s); cons x_new (tail s))
    else
      let h = head s in
      let t = replace_in_seq (tail s) x x_new in
      mem_cons h t; cons h t

let update_node (#t:eqtype) (h:dlisthead t) (n: pointer (dlist t)) (n': dlist t) :
  Stack (dlisthead t)
  (requires (fun h0 -> live h0 n /\ Seq.mem (h0@! n) (Ghost.reveal h.nodes)))
  (ensures (fun h1 y h2 ->
       modifies_1 n h1 h2 /\
       Seq.mem n' (Ghost.reveal y.nodes) /\
       (forall x. {:pattern (Seq.mem x (Ghost.reveal y.nodes))}
          (Seq.mem x (Ghost.reveal h.nodes) /\ x <> h1@! n) ==> Seq.mem x (Ghost.reveal y.nodes)) /\
       h2@!n = n' /\
       (h.lhead =!= n ==> y.lhead == h.lhead) /\
       (h.ltail =!= n ==> y.ltail == h.ltail)))
  =
  let n0 = !*n in
  let upd_nodes (s:seq (dlist t)) : GTot (seq (dlist t)) =
    replace_in_seq s n0 n' in
  let a = elift1 upd_nodes h.nodes in
  n <& n';
  { h with nodes = a }

unfold let (.()<-) = update_node

#set-options "--detail_errors --z3rlimit 1"

let insertHeadSingletonList (#t:eqtype) (h:dlisthead t) (e:pointer (dlist t)): ST (dlisthead t)
    (requires (fun h0 -> dlisthead_is_valid h0 h /\ live h0 e /\ ~(dlist_is_member_of h0 e h) /\ Seq.length (Ghost.reveal h.nodes) = 1))
    (ensures (fun _ y h2 -> live h2 e /\ dlisthead_is_valid h2 y)) =
  let h1 = ST.get () in
  let n = h.lhead in
  assert ( is_null (h1@!n).blink /\ is_null (h1@!n).flink );
  let n' = { !*n with blink = e } in
  assert ( is_null n'.flink );
  // admit ();
  n <& n';
  let h_now = ST.get () in
  assert ( is_null (h_now@!n).flink );
  // admit ();
  e <& { !*e with flink = n; blink = null };
  assert ( is_null (h_now@!n).flink );
  admit ();
  let n', e' = !*n, !*e in
  let y = { lhead = e ; ltail = n ; nodes = Ghost.hide (Seq.of_list [n'; e']) } in
  let h2 = ST.get () in
  assert ( dlisthead_liveness h2 y );
  assert ( is_null n'.flink );
  assert ( is_null e'.blink );
  admit ();
  assert ( dlist_is_valid n' );
  assert ( dlist_is_valid e' );
  assert ( (Seq.length (Ghost.reveal y.nodes) == 2) /\
           ((Ghost.reveal y.nodes).[0] == n') /\
           ((Ghost.reveal y.nodes).[1] == e') );
  assert ( dlisthead_has_valid_dlists h2 y );
  admit ();
  y

(** Insert an element e as the first element in a doubly linked list *)
let insertHeadList (#t:eqtype) (h:dlisthead t) (e:pointer (dlist t)): ST (dlisthead t)
   (requires (fun h0 -> dlisthead_is_valid h0 h /\ live h0 e /\ ~(dlist_is_member_of h0 e h)))
   (ensures (fun _ y h2 -> live h2 e /\ dlisthead_is_valid h2 y))
=
  if is_null h.lhead then ( // the list is empty
    createSingletonList e
  ) else (
    // assume (h.ltail =!= h.lhead);
    assert (e =!= h.ltail);
    // admit ();
    let next = h.lhead in
    let foo = h.ltail in
    assert (next =!= h.ltail);
    let h' = h.(next) <- ({ !*next with blink = e; }) in
    assert (foo == h.ltail);
    assert (h.ltail =!= e);
    assert (foo == h'.ltail);
    admit ();
    let h = h' in
    e <& { !*e with flink = next; blink = null };
    let ghoste = hide !*e in
    let y = { lhead = e; ltail = h.ltail; nodes = elift2 Seq.cons ghoste h.nodes } in
    // admit ();
    let h2 = ST.get () in
    assert (Seq.length (Ghost.reveal y.nodes) > 0);
    assert (not_null y.ltail);
    assert (not_null y.lhead);
    // assert ( dlisthead_liveness h2 y );
    // assert (dlisthead_has_valid_dlists h2 y);
    // assert (dlisthead_nullness h2 y);
    // assert (non_empty_dlisthead_connect_to_nodes h2 y);
    // assert (non_empty_dlisthead_is_valid h2 y);
    // let valid_dlist () =
    //   // assert ( dlisthead_has_valid_dlists h2 h );
    //   assert ( dlist_is_valid (Ghost.reveal ghoste) );
    //   admit ();
    //   assert ( dlisthead_has_valid_dlists h2 y ) in
    // valid_dlist ();
    admit ();
    // assert ( dlisthead_is_valid h2 y );
    // admit ();
    y
  )
