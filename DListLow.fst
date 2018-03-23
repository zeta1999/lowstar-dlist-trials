module DListLow

open FStar
open FStar.HyperStack
open FStar.HyperStack.ST
open FStar.Buffer
open FStar.Int
open C
open C.Nullity
open FStar.Ghost
open FStar.Seq
open PointerEquality
module U64 = FStar.UInt64
module U32 = FStar.UInt32
module U16 = FStar.UInt16
module U8 = FStar.UInt8
module HS = FStar.HyperStack
module B = FStar.Buffer
module ST = FStar.HyperStack.ST

unopteq
(** Node of a doubly linked list *)
type dlist (t:Type0) = {
  (* forward link *)
  flink: (pointer_or_null (dlist t));
  (* backward link *)
  blink: (pointer_or_null (dlist t));
  (* payload *)
  p: t;
}

unopteq
(** Doubly linked list head *)
type dlisthead (t:Type0) ={
  lhead: (pointer_or_null (dlist t));
  ltail: (pointer_or_null (dlist t));
  nodes: erased (seq (pointer (dlist t)));
}

unfold let null #t = null t
unfold let is_not_null p = not (is_null p)

(** Initialize an element of a doubly linked list *)
val empty_entry: #t:Type -> payload:t -> dlist t
let empty_entry #t payload =
  { flink = null ; blink = null ; p = payload }

(** Initialize a doubly linked list head *)
val empty_list: #t:Type -> dlisthead t
let empty_list #t =
  { lhead = null ; ltail = null ; nodes = hide createEmpty }

val getSome: (a:pointer_or_null 'a{is_not_null a}) -> (b:pointer 'a{a == b})
let getSome a = a

unfold let (@) (a:pointer 't) (h0:HS.mem{h0 `B.live` a}) = B.get h0 a 0
unfold let (^@) (a:(pointer_or_null 't){is_not_null a}) (h0:HS.mem{h0 `B.live` (getSome a)}) = (getSome a) @ h0

unfold let (.[]) (s:seq 'a) (n:nat{n < length s}) = index s n

unfold let ( := ) a b = a.(0ul) <- b
unfold let ( ! ) a = !* a

// logic : Cannot use due to https://github.com/FStarLang/FStar/issues/638
let not_aliased (#t:Type) (a:(pointer_or_null t)) (b:(pointer_or_null t)) : GTot Type0 =
  is_null a \/ is_null b \/
  (let (a:_{is_not_null a}) = a in // workaround for not using two phase type checker
   let (b:_{is_not_null b}) = b in
   disjoint (getSome a) (getSome b))

// logic : Cannot use due to https://github.com/FStarLang/FStar/issues/638
let not_aliased0 (#t:Type) (a:pointer t) (b:(pointer_or_null t)) : GTot Type0 =
  is_null b \/
  (let (b:_{is_not_null b}) = b in // workaround for not using two phase type checker
   disjoint a (getSome b))

logic
let not_aliased00 (#t:Type) (a:pointer t) (b:pointer t) : GTot Type0 =
  disjoint a b

logic
let dlist_is_valid' (#t:Type) (h0:HS.mem) (n:dlist t) : GTot Type0 =
  not_aliased n.flink n.blink

// logic
let dlist_is_valid (#t:Type) (h0:HS.mem) (n:pointer (dlist t)) : GTot Type0 =
  h0 `B.live` n /\
  dlist_is_valid' #t h0 (n@h0)

let (==$) (#t:Type) (a:(pointer_or_null t)) (b:pointer t) =
  is_not_null a /\
  (let (a:_{is_not_null a}) = a in // workaround for not using two phase type checker
   as_addr (getSome a) = as_addr b)

logic
let ( |> ) (#t:Type) (a:dlist t) (b:pointer (dlist t)) : GTot Type0 =
  a.flink ==$ b

logic
let ( <| ) (#t:Type) (a:pointer (dlist t)) (b: dlist t) : GTot Type0 =
  b.blink ==$ a

irreducible
let ( =|> ) (#t:Type) (a:pointer (dlist t)) (b:pointer (dlist t)) : ST unit
    (requires (fun h0 ->
         h0 `B.live` a /\ h0 `B.live` b /\
         not_aliased00 a b /\
         not_aliased0 b (a@h0).blink))
    (ensures (fun h1 _ h2 ->
         modifies_1 a h1 h2 /\
         dlist_is_valid h2 a /\
         (a@h1).p == (a@h2).p /\
         (a@h1).blink == (a@h2).blink /\
         b@h1 == b@h2 /\
         (a@h2) |> b)) =
  a := { !a with flink = b }

irreducible
let ( <|= ) (#t:Type) (a:pointer (dlist t)) (b:pointer (dlist t)) : ST unit
    (requires (fun h0 ->
         h0 `B.live` a /\ h0 `B.live` b /\
         not_aliased00 a b /\
         not_aliased0 a (b@h0).flink))
    (ensures (fun h1 _ h2 ->
         modifies_1 b h1 h2 /\
         dlist_is_valid h2 b /\
         a@h1 == a@h2 /\
         (b@h1).p == (b@h2).p /\
         (b@h1).flink == (b@h2).flink /\
         a <| (b@h2))) =
  b := { !b with blink = a }

irreducible
let ( !=|> ) (#t:Type) (a:pointer (dlist t)) : ST unit
    (requires (fun h0 -> h0 `B.live` a))
    (ensures (fun h1 _ h2 ->
         modifies_1 a h1 h2 /\
         dlist_is_valid h2 a /\
         (a@h1).p == (a@h2).p /\
         (a@h1).blink == (a@h2).blink /\
         (a@h2).flink == null)) =
  a := { !a with flink = null }

irreducible
let ( !<|= ) (#t:Type) (a:pointer (dlist t)) : ST unit
    (requires (fun h0 -> h0 `B.live` a))
    (ensures (fun h1 _ h2 ->
         modifies_1 a h1 h2 /\
         dlist_is_valid h2 a /\
         (a@h1).p == (a@h2).p /\
         (a@h1).flink == (a@h2).flink /\
         (a@h2).blink == null)) =
  a := { !a with blink = null }

unfold let (~.) (#t:Type) (a:t) : Tot (erased (seq t)) = hide (Seq.create 1 a)
unfold let (^+) (#t:Type) (a:t) (b:erased (seq t)) : Tot (erased (seq t)) = elift2 Seq.cons (hide a) b
unfold let (+^) (#t:Type) (a:erased (seq t)) (b:t) : Tot (erased (seq t)) = elift2 Seq.snoc a (hide b)

logic
let all_nodes_contained (#t:Type) (h0:HS.mem) (h:dlisthead t) : GTot Type0 =
  let nodes = reveal h.nodes in
  (is_not_null h.lhead ==> h0 `B.live` (getSome h.lhead)) /\
  (is_not_null h.ltail ==> h0 `B.live` (getSome h.ltail)) /\
  (forall i. {:pattern (h0 `B.live` nodes.[i])}
     h0 `B.live` nodes.[i]) /\
  (forall i j. {:pattern (B.frameOf nodes.[i]); (B.frameOf nodes.[j])}
     B.frameOf nodes.[i] = B.frameOf nodes.[j])

logic
let flink_valid (#t:Type) (h0:HS.mem) (h:dlisthead t) : GTot Type0 =
  let nodes = reveal h.nodes in
  let len = length nodes in
  all_nodes_contained h0 h /\
  (forall i. {:pattern ((nodes.[i]@h0).flink)}
     ((0 <= i /\ i < len - 1) ==>
      (let (a:_{h0 `B.live` nodes.[i]}) = nodes.[i] in // workaround for 2 phase
       nodes.[i]@h0 |> nodes.[i+1])))

logic
let blink_valid (#t:Type) (h0:HS.mem) (h:dlisthead t) : GTot Type0 =
  let nodes = reveal h.nodes in
  let len = length nodes in
  all_nodes_contained h0 h /\
  (forall i. {:pattern ((nodes.[i]@h0).blink)}
     ((1 <= i /\ i < len) ==>
      (let (_:_{h0 `B.live` nodes.[i]}) = nodes.[i] in // workaround for 2 phase
      nodes.[i-1] <| nodes.[i]@h0)))

logic
let dlisthead_ghostly_connections (#t:Type) (h0:HS.mem) (h:dlisthead t) : GTot Type0 =
  let nodes = reveal h.nodes in
  let len = length nodes in
  let empty = (len = 0) in
  all_nodes_contained h0 h /\
  ~empty ==> (
    h.lhead ==$ nodes.[0] /\
    h.ltail ==$ nodes.[len-1] /\
    is_null (h.lhead^@h0).blink /\
    is_null (h.ltail^@h0).flink)

logic
let elements_dont_alias1 (#t:Type) (h0:HS.mem) (h:dlisthead t) : GTot Type0 =
  let nodes = reveal h.nodes in
  all_nodes_contained h0 h /\
  (forall i j. {:pattern (not_aliased (nodes.[i]@h0).flink (nodes.[j]@h0).flink)}
     0 < i /\ i < j /\ j < length nodes ==>
   (let (_:_{h0 `B.live` nodes.[i]}) = nodes.[i] in // workaround for 2 phase
    let (_:_{h0 `B.live` nodes.[j]}) = nodes.[j] in
    not_aliased (nodes.[i]@h0).flink (nodes.[j]@h0).flink))

logic
let elements_dont_alias2 (#t:Type) (h0:HS.mem) (h:dlisthead t) : GTot Type0 =
  let nodes = reveal h.nodes in
  all_nodes_contained h0 h /\
  (forall i j. {:pattern (not_aliased (nodes.[i]@h0).blink (nodes.[j]@h0).blink)}
     0 < i /\ i < j /\ j < length nodes ==>
   (let (_:_{h0 `B.live` nodes.[i]}) = nodes.[i] in // workaround for 2 phase
    let (_:_{h0 `B.live` nodes.[j]}) = nodes.[j] in
    not_aliased (nodes.[i]@h0).blink (nodes.[j]@h0).blink))

// logic : Cannot use due to https://github.com/FStarLang/FStar/issues/638
let elements_dont_alias (#t:Type) (h0:HS.mem) (h:dlisthead t) : GTot Type0 =
  elements_dont_alias1 h0 h /\
  elements_dont_alias2 h0 h

logic
let elements_are_valid (#t:Type) (h0:HS.mem) (h:dlisthead t) : GTot Type0 =
  let nodes = reveal h.nodes in
  all_nodes_contained h0 h /\
  (forall i. {:pattern (nodes.[i])}
     dlist_is_valid h0 nodes.[i])

logic
let all_elements_distinct (#t:Type) (h0:HS.mem) (h:dlisthead t) : GTot Type0 =
    let nodes = reveal h.nodes in
    (forall i j. {:pattern (nodes.[i]); (nodes.[j])}
       (0 <= i /\ i < j /\ j < Seq.length nodes) ==>
       (let (i:nat{i < Seq.length nodes}) = i in // workaround for not using two phase type checker
        let (j:nat{j < Seq.length nodes}) = j in
        disjoint nodes.[i] nodes.[j]))

logic
let dlisthead_is_valid (#t:Type) (h0:HS.mem) (h:dlisthead t) : GTot Type0 =
  let nodes = reveal h.nodes in
  let len = length nodes in
  let empty = (len = 0) in
  (empty ==> is_null h.lhead /\ is_null h.ltail) /\
  (~empty ==> dlisthead_ghostly_connections h0 h /\
              flink_valid h0 h /\
              blink_valid h0 h) /\
  elements_are_valid h0 h /\
  elements_dont_alias h0 h /\
  all_elements_distinct h0 h

let test1 () : Tot unit = assert (forall h0 t. dlisthead_is_valid h0 (empty_list #t))

val singletonlist: #t:eqtype -> e:pointer (dlist t) ->
  ST (dlisthead t)
  (requires (fun h0 -> h0 `B.live` e))
  (ensures (fun h0 y h1 -> modifies_1 e h0 h1 /\ dlisthead_is_valid h1 y))
let singletonlist #t e =
  !<|= e; !=|> e;
  { lhead = e ; ltail = e ; nodes = ~. e }

// logic
let contains_by_addr (#t:Type) (s:seq (pointer t)) (x:pointer t) : GTot Type0 =
  (exists i. B.as_addr s.[i] == B.as_addr x)

logic
let member_of (#t:eqtype) (h0:HS.mem) (h:dlisthead t) (e:pointer (dlist t)) : GTot Type0 =
  let nodes = reveal h.nodes in
  nodes `contains_by_addr` e

// logic : Cannot use due to https://github.com/FStarLang/FStar/issues/638
let has_nothing_in (#t:eqtype) (h0:HS.mem)
    (h:dlisthead t{dlisthead_is_valid h0 h})
    (e:pointer (dlist t){h0 `B.live` e})
  : GTot Type0 =
  (~(member_of h0 h e)) /\
  (not_aliased0 e h.lhead) /\
  (not_aliased0 e h.ltail) /\
  (let nodes = reveal h.nodes in
   (forall i. {:pattern (nodes.[i]@h0).flink}
      (not_aliased0 e (nodes.[i]@h0).flink /\
       not_aliased (e@h0).flink (nodes.[i]@h0).flink /\
       not_aliased (e@h0).blink (nodes.[i]@h0).flink)) /\
   (forall i. {:pattern (nodes.[i]@h0).blink}
      (not_aliased0 e (nodes.[i]@h0).blink) /\
      not_aliased (e@h0).flink (nodes.[i]@h0).blink /\
      not_aliased (e@h0).blink (nodes.[i]@h0).blink))

type nonempty_dlisthead t = (h:dlisthead t{is_not_null h.lhead /\ is_not_null h.ltail})

val dlisthead_make_valid_singleton: #t:eqtype -> h:nonempty_dlisthead t ->
  ST (dlisthead t)
    (requires (fun h0 ->
         h0 `B.live` (getSome h.lhead) /\
         is_null (h.lhead^@h0).flink /\ is_null (h.lhead^@h0).blink))
    (ensures (fun h1 y h2 -> modifies_none h1 h2 /\ dlisthead_is_valid h2 y))
let dlisthead_make_valid_singleton #t h =
  let e = h.lhead in
  { h with ltail = h.lhead ; nodes = ~. e }

let is_singleton (#t:Type) (h:nonempty_dlisthead t) : Tot bool =
  compare_addrs (getSome h.lhead) (getSome h.ltail)

val nonempty_singleton_properties :
  #t:Type ->
  h:nonempty_dlisthead t ->
  ST unit
    (requires (fun h0 -> dlisthead_is_valid h0 h /\ is_singleton h))
    (ensures (fun h0 _ h1 -> h0 == h1 /\ Seq.length (reveal h.nodes) == 1))
let nonempty_singleton_properties #t h =
  let h0 = ST.get () in
  let n = reveal h.nodes in
  let l = Seq.length n in
  let hd = getSome h.lhead in
  let tl = getSome h.ltail in
  let fst = Seq.head n in
  let lst = Seq.last n in
  assert (compare_addrs hd fst);
  assert (compare_addrs tl lst);
  assert (compare_addrs hd tl);
  assert (compare_addrs fst lst);
  admit ()// TODO: Prove this

val nonempty_nonsingleton_properties :
  #t:Type ->
  h:nonempty_dlisthead t ->
  ST unit
    (requires (fun h0 -> dlisthead_is_valid h0 h /\ ~(compare_addrs (getSome h.lhead) (getSome h.ltail))))
    (ensures (fun h0 _ h1 -> h0 == h1 /\ Seq.length (reveal h.nodes) > 1))
let nonempty_nonsingleton_properties #t h = ()

val ghost_append_properties: #t:Type -> a:t -> b:erased (seq t) ->
  Lemma (let r = a ^+ b in
         forall i j. {:pattern ((reveal b).[i] == (reveal r).[j])}
           j = i + 1 /\ 0 <= i /\ i < length (reveal b) ==> (reveal b).[i] == (reveal r).[j])
let ghost_append_properties #t a b = ()

#set-options "--z3rlimit 50 --z3refresh"

val dlisthead_update_head: #t:eqtype -> h:nonempty_dlisthead t -> e:pointer (dlist t) ->
  ST (dlisthead t)
    (requires (fun h0 -> dlisthead_is_valid h0 h /\ dlist_is_valid h0 e /\ has_nothing_in h0 h e))
    (ensures (fun h1 y h2 -> modifies (e ^+^ (getSome h.lhead)) h1 h2 /\ dlisthead_is_valid h2 y))
let dlisthead_update_head (#t:eqtype) (h:nonempty_dlisthead t) (e:pointer (dlist t)) =
  let h1 = ST.get () in
  let Some n = h.lhead in
  !<|= e;
  e =|> n;
  e <|= n;
  let y = { lhead = Some e ; ltail = h.ltail ; nodes = e ^+ h.nodes } in
  let h2 = ST.get () in
  assert (
    let ynodes = reveal y.nodes in
    let hnodes = reveal h.nodes in
    (forall (i:nat{2 <= i /\ i < Seq.length ynodes /\ i-1 < Seq.length hnodes}).
              {:pattern (ynodes.[i]@h2)}
       ynodes.[i]@h2 == hnodes.[i-1]@h1)); // OBSERVE
    y

#reset-options

val insertHeadList : #t:eqtype -> h:dlisthead t -> e:pointer (dlist t) ->
  ST (dlisthead t)
    (requires (fun h0 -> dlisthead_is_valid h0 h /\ dlist_is_valid h0 e /\ has_nothing_in h0 h e))
    (ensures (fun h1 y h2 ->
         (is_not_null h.lhead ==>
          modifies (e ^+^ (getSome h.lhead)) h1 h2) /\
         (~(is_not_null h.lhead) ==>
          modifies (only e) h1 h2) /\
         dlisthead_is_valid h2 y))
let insertHeadList #t h e =
  if is_not_null h.lhead
  then dlisthead_update_head h e
  else singletonlist e

#set-options "--z3rlimit 25 --z3refresh"

val dlisthead_update_tail: #t:eqtype -> h:nonempty_dlisthead t -> e:pointer (dlist t) ->
  ST (dlisthead t)
    (requires (fun h0 -> dlisthead_is_valid h0 h /\ dlist_is_valid h0 e /\ has_nothing_in h0 h e))
    (ensures (fun h1 y h2 -> modifies (e ^+^ (getSome h.ltail)) h1 h2 /\ dlisthead_is_valid h2 y))
let dlisthead_update_tail #t h e =
  let h1 = ST.get () in
  let previously_singleton = is_singleton h in
  let Some n = h.ltail in
  !=|> e;
  n =|> e;
  n <|= e;
  let y = { lhead = h.lhead ; ltail = Some e ; nodes = h.nodes +^ e } in
  let h2 = ST.get () in
  assert (
    let ynodes = reveal y.nodes in
    let hnodes = reveal h.nodes in
    (forall (i:nat{0 <= i /\ i < Seq.length ynodes - 2 /\ i < Seq.length hnodes - 1}).
              {:pattern (ynodes.[i]@h2)}
       ynodes.[i]@h2 == hnodes.[i]@h1)); // OBSERVE
    y

#reset-options

val insertTailList : #t:eqtype -> h:dlisthead t -> e:pointer (dlist t) ->
  ST (dlisthead t)
    (requires (fun h0 -> dlisthead_is_valid h0 h /\ dlist_is_valid h0 e /\ has_nothing_in h0 h e))
    (ensures (fun h1 y h2 ->
         (is_not_null h.ltail ==>
          modifies (e ^+^ (getSome h.ltail)) h1 h2) /\
         (~(is_not_null h.lhead) ==>
          modifies (only e) h1 h2) /\
         dlisthead_is_valid h2 y))
let insertTailList #t h e =
  if is_not_null h.ltail
  then dlisthead_update_tail h e
  else singletonlist e

unfold let ghost_tail (#t:Type) (s:erased (seq t){Seq.length (reveal s) > 0}) : Tot (erased (seq t)) =
  hide (Seq.tail (reveal s))

#set-options "--z3rlimit 50 --max_fuel 4 --max_ifuel 1"

val dlisthead_remove_head: #t:eqtype -> h:nonempty_dlisthead t ->
  ST (dlisthead t)
    (requires (fun h0 -> dlisthead_is_valid h0 h))
    (ensures (fun h1 y h2 ->
         (is_singleton h ==>
          modifies (only (getSome h.lhead)) h1 h2) /\
         (~(is_singleton h) ==>
          modifies ((getSome h.lhead) ^+^ (reveal h.nodes).[1]) h1 h2) /\
         dlisthead_is_valid h2 y))
let dlisthead_remove_head #t h =
  let h1 = ST.get () in
  let Some n = h.lhead in
  if is_singleton h
  then (
    empty_list
  ) else (
    let Some next = (!n).flink in
    recall next;
    // unlink them
    !=|> n;
    !<|= next;
    let Some htail = h.ltail in
    let y = { lhead = Some next ; ltail = h.ltail ; nodes = ghost_tail h.nodes } in
    let h2 = ST.get () in
    assert (
      let ynodes = reveal y.nodes in
      let hnodes = reveal h.nodes in
      (forall (i:nat{1 <= i /\ i < Seq.length ynodes /\ i+1 < Seq.length hnodes}).
                {:pattern (ynodes.[i]@h2)}
         ynodes.[i]@h2 == hnodes.[i+1]@h1)); // OBSERVE
      y
  )

#reset-options

unfold let ghost_unsnoc (#t:Type) (s:erased (seq t){Seq.length (reveal s) > 0}) : Tot (erased (seq t)) =
  let x = reveal s in
  let l = length x - 1 in
  hide (slice x 0 l)

#set-options "--z3rlimit 50"

val dlisthead_remove_tail: #t:eqtype -> h:nonempty_dlisthead t ->
  ST (dlisthead t)
    (requires (fun h0 -> dlisthead_is_valid h0 h))
    (ensures (fun h1 y h2 ->
         (is_singleton h ==>
          modifies (only (getSome h.ltail)) h1 h2) /\
         (~(is_singleton h) ==>
          (let nodes = reveal h.nodes in
          modifies ((getSome h.ltail) ^+^ nodes.[length nodes - 2]) h1 h2)) /\
         dlisthead_is_valid h2 y))
let dlisthead_remove_tail #t h =
  let h1 = ST.get () in
  if is_singleton h then (
    empty_list
  ) else (
    let Some n = h.ltail in
    let Some prev = (!n).blink in
    recall prev;
    //unlink them
    !<|= n;
    !=|> prev;
    let y = { lhead = h.lhead ; ltail = Some prev ; nodes = ghost_unsnoc h.nodes } in
    let h2 = ST.get () in
    assert (
      let ynodes = reveal y.nodes in
      let hnodes = reveal h.nodes in
      (forall (i:nat{0 <= i /\ i < Seq.length ynodes - 1 /\ i < Seq.length hnodes - 2}).
                {:pattern (ynodes.[i]@h2)}
         ynodes.[i]@h2 == hnodes.[i]@h1)); // OBSERVE
      y
  )

#reset-options

let rec get_ref_index (#t:Type) (s:seq (pointer t)) (x:pointer t{s `contains_by_addr` x}) :
  GTot (i:nat{i < Seq.length s})
    (decreases (Seq.length s)) =
  contains_elim s x;
  let h, t = Seq.head s, Seq.tail s in
  if compare_addrs h x then 0 else (
    contains_cons h t x;
    1 + get_ref_index t x)

val lemma_get_ref_index : #t:Type -> s:seq (pointer t) -> x:pointer t{s `contains_by_addr` x} ->
  Lemma (ensures (
    addr_of s.[get_ref_index s x] = addr_of x))
    (decreases (Seq.length s))
    [SMTPat (addr_of s.[get_ref_index s x])]
let rec lemma_get_ref_index #t s x =
  contains_elim s x;
  let h, t = Seq.head s, Seq.tail s in
  if compare_addrs h x then () else (
    contains_cons h t x;
    lemma_get_ref_index t x)

val split_seq_at_element : #t:Type -> s:seq (pointer t) -> x:pointer t{s `contains_by_addr` x} ->
  GTot (v:(seq (pointer t) * nat * seq (pointer t)){
      let l, i, r = v in
      indexable s i /\ (
      let (i:nat{i < length s}) = i in // workaround for two phase thing
      s == append l (cons s.[i] r) /\
      addr_of s.[i] == addr_of x)
  })
let split_seq_at_element #t s x =
  let i = get_ref_index s x in
  let l, mr = Seq.split s i in
  lemma_split s i;
  l, i, tail mr

#reset-options "--z3rlimit 1 --detail_errors --z3rlimit_factor 20"

val dlisthead_remove_strictly_mid: #t:eqtype -> h:nonempty_dlisthead t -> e:pointer (dlist t) ->
  ST (dlisthead t)
    (requires (fun h0 -> dlisthead_is_valid h0 h /\ dlist_is_valid h0 e /\
                         member_of h0 h e /\
                         not_aliased0 e h.lhead /\ not_aliased0 e h.ltail))
    (ensures (fun h1 y h2 ->
         is_not_null (e@h1).flink /\ is_not_null (e@h1).blink /\
         dlist_is_valid h2 e /\
         is_null (e@h2).flink /\ is_null (e@h2).blink /\
         modifies (e ^++ (getSome (e@h1).flink) ^+^ (getSome (e@h1).blink)) h1 h2 /\
         dlisthead_is_valid h2 y))
let dlisthead_remove_strictly_mid #t h e =
  let h1 = ST.get () in
  let Some prev = (!e).blink in
  let Some next = (!e).flink in
  recall prev;
  recall next;
  !<|= e;
  !=|> e;
  prev =|> next;
  prev <|= next;
  let nodes = h.nodes in // TODO: Fix this
  let y = { lhead = h.lhead ; ltail = h.ltail ; nodes = nodes } in
  admit ();
  h // TODO: Actually do something

/// Useful code that can be copied over below

(*
    assert (all_nodes_contained h2 y);
    assert (dlisthead_ghostly_connections h2 y);
    assert (flink_valid h2 y);
    assert (blink_valid h2 y);
    assert (elements_are_valid h2 y);
    assert (elements_dont_alias1 h2 y);
    assert (elements_dont_alias2 h2 y);
    assert (all_elements_distinct h2 y);
*)