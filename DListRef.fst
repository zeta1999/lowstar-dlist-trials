module DListRef

open FStar
open FStar.Ghost
open FStar.Option
open FStar.Seq
open FStar.Ref

unopteq
(** Node of a doubly linked list *)
type dlist (t:Type0) = {
  (* forward link *)
  flink: option (ref (dlist t));
  (* backward link *)
  blink: option (ref (dlist t));
  (* payload *)
  p: t;
}

unopteq
(** Doubly linked list head *)
type dlisthead (t:Type0) ={
  lhead: option (ref (dlist t));
  ltail: option (ref (dlist t));
  nodes: erased (seq (dlist t));
}

(** Initialize an element of a doubly linked list *)
val empty_entry: #t:Type -> payload:t -> dlist t
let empty_entry #t payload =
  { flink = None ; blink = None ; p = payload }

(** Initialize a doubly linked list head *)
val empty_list: #t:Type -> dlisthead t
let empty_list #t =
  { lhead = None ; ltail = None ; nodes = hide createEmpty }

val getSome: (a:option 'a{isSome a}) -> (b:'a{a == Some b})
let getSome a = Some?.v a

unfold let (@) (a:ref 't) (h0:heap) = sel h0 a
unfold let (^@) (a:option (ref 't){isSome a}) (h0:heap) = (getSome a) @ h0

unfold let (.[]) (s:seq 'a) (n:nat{n < length s}) = index s n

val flink_valid: #t:Type -> h0:heap -> h:dlisthead t -> Type0
let flink_valid #t h0 h =
  let nodes = reveal h.nodes in
  let len = length nodes in
  (forall i. {:pattern (nodes.[i]).flink}
     ((0 <= i /\ i < len - 1) ==>
      isSome (nodes.[i]).flink /\
      (nodes.[i]).flink^@h0 == nodes.[i+1]))

val blink_valid: #t:Type -> h0:heap -> h:dlisthead t -> Type0
let blink_valid #t h0 h =
  let nodes = reveal h.nodes in
  let len = length nodes in
  (forall i. {:pattern (nodes.[i]).blink}
     ((1 <= i /\ i < len) ==>
      isSome (nodes.[i]).blink /\
      (nodes.[i]).blink^@h0 == nodes.[i-1]))

val dlisthead_ghostly_connections: #t:Type -> h0:heap -> h:dlisthead t -> Type0
let dlisthead_ghostly_connections #t h0 h =
  let nodes = reveal h.nodes in
  let len = length nodes in
  let empty = (len = 0) in
  ~empty ==> (
    isSome h.lhead /\ isSome h.ltail /\
    isNone (h.lhead^@h0).blink /\
    isNone (h.ltail^@h0).flink /\
    h.lhead^@h0 == nodes.[0] /\
    h.ltail^@h0 == nodes.[len-1])

val dlisthead_is_valid: #t:Type -> h0:heap -> h:dlisthead t -> Type0
let dlisthead_is_valid #t h0 h =
  let nodes = reveal h.nodes in
  let len = length nodes in
  let empty = (len = 0) in
  (empty ==> isNone h.lhead /\ isNone h.ltail) /\
  (~empty ==> dlisthead_ghostly_connections h0 h /\
              flink_valid h0 h /\
              blink_valid h0 h)

let test1 () : Tot unit = assert (forall h0 t. dlisthead_is_valid h0 (empty_list #t))

val singletonlist: #t:eqtype -> e:ref (dlist t) ->
  ST (dlisthead t)
  (requires (fun _ -> True))
  (ensures (fun h0 y h1 -> modifies (only e) h0 h1 /\ dlisthead_is_valid h1 y))
let singletonlist #t e =
  e := { !e with blink = None; flink = None };
  { lhead = Some e ; ltail = Some e ; nodes = hide (Seq.create 1 (!e)) }

let member_of (#t:eqtype) (h0:heap) (h:dlisthead t) (e:ref (dlist t)) : GTot bool =
  Seq.mem (e@h0) (reveal h.nodes)

type nonempty_dlisthead t = (h:dlisthead t{isSome h.lhead /\ isSome h.ltail})

unfold let (~.) (#t:Type) (a:t) : Tot (erased (seq t)) = hide (Seq.create 1 a)
unfold let (^+) (#t:Type) (a:t) (b:erased (seq t)) : Tot (erased (seq t)) = elift2 Seq.cons (hide a) b

val dlisthead_make_valid_singleton: #t:eqtype -> h:nonempty_dlisthead t ->
  ST (dlisthead t)
    (requires (fun h0 ->
         isNone (h.lhead^@h0).flink /\ isNone (h.lhead^@h0).blink))
    (ensures (fun h1 y h2 -> modifies_none h1 h2 /\ dlisthead_is_valid h2 y))
let dlisthead_make_valid_singleton #t h =
  let Some e = h.lhead in
  { h with ltail = h.lhead ; nodes = ~. !e }

unfold let ghost_tail (#t:Type) (s:erased (seq t){Seq.length (reveal s) > 0}) : Tot (erased (seq t)) =
  hide (Seq.tail (reveal s))

val ghost_tail_properties :
  #t:Type ->
  s:erased (seq t){Seq.length (reveal s) > 0} ->
  Lemma (
    let l = Seq.length (reveal s) in
    let t = ghost_tail s in
    let s0 = reveal s in
    let t0 = reveal t in
    Seq.length t0 = Seq.length s0 - 1 /\
    (forall x. {:pattern (t0.[x])} 0 <= x /\ x < Seq.length t0 ==> t0.[x] == s0.[x+1]))
let ghost_tail_properties #t s = ()

#set-options "--z3rlimit 1 --detail_errors --z3rlimit_factor 20"

val dlisthead_update_head: #t:eqtype -> h:nonempty_dlisthead t -> e:ref (dlist t) ->
  ST (dlisthead t)
    (requires (fun h0 -> dlisthead_is_valid h0 h /\ ~(member_of h0 h e)))
    (ensures (fun h1 y h2 -> modifies (e ^+^ (getSome h.lhead)) h1 h2 /\ dlisthead_is_valid h2 y))
let dlisthead_update_head (#t:eqtype) (h:nonempty_dlisthead t) (e:ref (dlist t)) =
  let h1 = ST.get () in
  let Some n = h.lhead in
  e := { !e with blink = None; flink = Some n };
  let previously_singleton = compare_addrs n (getSome h.ltail) in
  n := { !n with blink = Some e };
  if previously_singleton
  then (
    { lhead = Some e ; ltail = Some n ; nodes = !e ^+ ~. !n }
  ) else (
    let y = { lhead = Some e ; ltail = h.ltail ; nodes = !e ^+ !n ^+ (ghost_tail h.nodes) } in
    let h2 = ST.get () in
    assert (y.ltail == h.ltail);
    assert (h.ltail^@h1 == h.ltail^@h2);
    assert (isSome y.ltail /\ getSome y.ltail == getSome y.ltail /\ sel h2 (getSome y.ltail) == sel h2 (getSome y.ltail)); // WHY IS THIS ASSERT FAILING!!!! THIS SHOULD BE TRIVIAL! subtyping check fails here :/
    admit ();
    assert (let nodes = reveal y.nodes in
            let len = length nodes in
            y.ltail^@h2 == nodes.[len-1]); // Unable to prove this for some reason
    admit ();
    assert (dlisthead_ghostly_connections h2 y);
    assert (flink_valid h2 y);
    assert (blink_valid h2 y);
    admit ();
    y
  )

val insertHeadList: #t:eqtype -> h:dlisthead t -> e:ref (dlist t) ->
  ST (dlisthead t)
    (requires (fun h0 -> dlisthead_is_valid h0 h /\ ~(member_of h0 h e)))
    (ensures (fun _ y h2 -> dlisthead_is_valid h2 y))
let insertHeadList #t h e =
  if isNone h.lhead
  then (
    singletonlist e
  ) else (
    let h1 = ST.get () in
    let n = getSome h.lhead in
    n := { !n with blink = Some e };
    let h1' = ST.get () in
    e := { !e with blink = None ; flink = Some n };
    let ghoste = hide !e in
    let nodes = elift2 cons ghoste h.nodes in
    let y = { lhead = Some e ; ltail = h.ltail ; nodes = nodes } in
    let h2 = ST.get () in
    // assert (isSome y.lhead /\ isSome y.ltail);
    // assert (isNone (y.lhead^@h2).blink);
    assert (isNone (y.ltail^@h2).flink); // OBSERVE
    // assert (y.lhead^@h2 == (reveal y.nodes).[0]);
    assert (h.ltail^@h1 == (reveal h.nodes).[length (reveal h.nodes) - 1]);
    assert (h.ltail^@h1' == (reveal h.nodes).[length (reveal h.nodes) - 1]); // this fails. reason: what if the dlisthead is a singleton when we begin?
    admit ();
    assert (
      let nodes = reveal y.nodes in
      let len = length nodes in
      let empty = (len = 0) in
      ((isSome y.lhead /\ isSome y.ltail) /\
       isNone (y.lhead^@h2).blink /\
       isNone (y.ltail^@h2).flink /\
        (y.lhead^@h2 == nodes.[0]) /\
        (y.ltail^@h2 == nodes.[len-1]) /\
        // (forall i. {:pattern (nodes.[i]).blink}
        //    ((1 <= i /\ i < len) ==>
        //     isSome (nodes.[i]).blink /\
        //     (nodes.[i]).blink^@h2 == nodes.[i-1])) /\
        // (forall i. {:pattern (nodes.[i]).flink}
        //    ((0 <= i /\ i < len - 1) ==>
        //     isSome (nodes.[i]).flink /\
        //     (nodes.[i]).flink^@h2 == nodes.[i+1])) /\
        True)
     );
     admit ();
     y
  )

