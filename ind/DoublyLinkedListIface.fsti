(*
   Copyright 2018 Jay Bosamiya

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*)

module DoublyLinkedListIface

module HS = FStar.HyperStack
module HST = FStar.HyperStack.ST
module L = FStar.List.Tot
module B = LowStar.Buffer

/// Abstract types defined by this library

(** A singular node which stores a value of type [a] *)
val node (a:Type0) : Type0

(** A doublylinkedlist of elements of type [a] *)
val dll (a:Type0) : Type0

/// Abstract Validity Predicates

val node_valid (h:HS.mem) (n:node 'a) : prop

val dll_valid (h:HS.mem) (d:dll 'a) : prop

/// Abstract node and list footprints

val fp_node (n:node 'a) : GTot B.loc

val fp_dll (h:HS.mem) (d:dll 'a) : GTot B.loc

/// Getters and setters for [node]s

val g_node_val (h:HS.mem) (n:node 'a) : GTot 'a

val node_val (n:node 'a) :
  HST.StackInline 'a
    (requires (fun h0 -> node_valid h0 n))
    (ensures (fun h0 v h1 -> h0 == h1 /\ v == g_node_val h0 n))

val node_of (v:'a) :
  HST.StackInline (node 'a)
    (requires (fun h0 -> True))
    (ensures (fun h0 n h1 ->
         B.modifies B.loc_none h0 h1 /\
         B.fresh_loc (fp_node n) h0 h1 /\
         node_valid h1 n /\
         v == g_node_val h1 n))

// TODO: Add [node_update] to update a [node]'s payload, without
//       needing to remove/re-add things into [dll]s.

/// Abstract Predicate to help "recall" that [g_node_val] remains
/// unchanged for nodes, across multiple [mem]s

val unchanged_node_val (h0 h1:HS.mem) (n:node 'a) : GTot prop

let rec unchanged_node_vals (h0 h1:HS.mem) (ns:list (node 'a)) : GTot prop =
  match ns with
  | [] -> True
  | n :: ns' -> unchanged_node_val h0 h1 n /\ unchanged_node_vals h0 h1 ns'

/// Viewing ghostly state of a DoublyLinkedList as a list

val as_list (h:HS.mem) (d:dll 'a) : GTot (list (node 'a))

/// Creating an empty DoublyLinkedList, and quickly accessing the head
/// and tail of a DoublyLinkedList

val dll_new (u:unit)  :
  HST.StackInline (dll 'a)
    (requires (fun h0 -> True))
    (ensures (fun h0 d h1 ->
         B.modifies B.loc_none h0 h1 /\
         B.fresh_loc (fp_dll h1 d) h0 h1 /\
         dll_valid h1 d /\
         as_list h1 d == []))

val dll_head (d:dll 'a) :
  HST.StackInline (node 'a)
    (requires (fun h0 -> dll_valid h0 d /\ L.length (as_list h0 d) > 0))
    (ensures (fun h0 n h1 ->
         B.modifies B.loc_none h0 h1 /\
         dll_valid h1 d /\
         node_valid h1 n /\
         as_list h0 d == as_list h1 d /\
         n == L.hd (as_list h0 d)))

val dll_tail (d:dll 'a) :
  HST.StackInline (node 'a)
    (requires (fun h0 -> dll_valid h0 d /\ L.length (as_list h0 d) > 0))
    (ensures (fun h0 n h1 ->
         h0 == h1 /\
         dll_valid h1 d /\
         node_valid h1 n /\
         as_list h0 d == as_list h1 d /\
         n == snd (L.unsnoc (as_list h0 d))))

/// Moving forwards or backwards in a list

val next_node (d:dll 'a) (n:node 'a) :
  HST.StackInline (node 'a)
    (requires (fun h0 ->
         dll_valid h0 d /\
         n `L.memP` as_list h0 d /\
         L.index_of (as_list h0 d) n < L.length (as_list h0 d) - 1))
    (ensures (fun h0 n' h1 ->
         h0 == h1 /\
         dll_valid h1 d /\
         node_valid h1 n /\
         as_list h0 d == as_list h1 d /\
         n' == L.index (as_list h0 d) (L.index_of (as_list h0 d) n + 1)))

val prev_node (d:dll 'a) (n:node 'a) :
  HST.StackInline (node 'a)
    (requires (fun h0 ->
         dll_valid h0 d /\
         n `L.memP` as_list h0 d /\
         L.index_of (as_list h0 d) n > 0))
    (ensures (fun h0 n' h1 ->
         h0 == h1 /\
         dll_valid h1 d /\
         node_valid h1 n /\
         as_list h0 d == as_list h1 d /\
         n' == L.index (as_list h0 d) (L.index_of (as_list h0 d) n - 1)))

/// DoublyLinkedList operations on standard [list]s instead

let l_insert_at_head (l:list 'a) (x:'a) : GTot (list 'a) =
  x :: l

let l_insert_at_tail (l:list 'a) (x:'a) : GTot (list 'a) =
  L.snoc (l, x)

let l_insert_before (x0:'a) (l:list 'a{x0 `L.memP` l}) (x:'a) : GTot (list 'a) =
  let l1, l2 = L.split_using l x0 in
  l1 `L.append` (x :: l2)

let l_insert_after (x0:'a) (l:list 'a{x0 `L.memP` l}) (x:'a) : GTot (list 'a) =
  let l1, x1 :: l2 = L.lemma_split_using l x0; L.split_using l x0 in
  assert (x0 == x1);
  l1 `L.append` (x0 :: (x :: l2))

let l_remove_head (l:list 'a{L.length l > 0}) : GTot (list 'a) =
  match l with
  | _ :: l' -> l'

let l_remove_tail (l:list 'a{L.length l > 0}) : GTot (list 'a) =
  let l', _ = L.unsnoc l in
  l'

let l_remove_mid (l:list 'a{L.length l > 0}) (x:'a {x `L.memP` l}) : GTot (list 'a) =
  let l1, x0 :: l2 = L.lemma_split_using l x; L.split_using l x in
  assert (x == x0);
  l1 `L.append` l2

let l_append (l1 l2:list 'a) : GTot (list 'a) =
  l1 `L.append` l2

/// Useful "shortform" for equivalence of [loc]s

let loc_equiv (a b:B.loc) =
  B.loc_includes a b /\ B.loc_includes b a

/// Stateful DoublyLinkedList operations
///
/// These are most likely what you want to be using when writing
/// code. The rest of this interface lets you talk about these
/// operations easily.

val dll_insert_at_head (#t:Type0) (d:dll t) (n:node t) :
  HST.Stack unit
    (requires (fun h0 -> dll_valid h0 d /\ node_valid h0 n /\ (fp_node n `B.loc_disjoint` fp_dll h0 d)))
    (ensures (fun h0 () h1 ->
         B.modifies (fp_dll h1 d) h0 h1 /\
         fp_dll h1 d `loc_equiv` B.loc_union (fp_dll h0 d) (fp_node n) /\
         dll_valid h1 d /\ node_valid h1 n /\
         unchanged_node_vals h0 h1 (as_list h1 d) /\
         as_list h1 d == l_insert_at_head (as_list h0 d) n))

val dll_insert_at_tail (#t:Type0) (d:dll t) (n:node t) :
  HST.Stack unit
    (requires (fun h0 -> dll_valid h0 d /\ node_valid h0 n /\ (fp_node n `B.loc_disjoint` fp_dll h0 d)))
    (ensures (fun h0 () h1 ->
         B.modifies (fp_dll h1 d) h0 h1 /\
         fp_dll h1 d `loc_equiv` B.loc_union (fp_dll h0 d) (fp_node n) /\
         dll_valid h1 d /\ node_valid h1 n /\
         unchanged_node_vals h0 h1 (as_list h1 d) /\
         as_list h1 d == l_insert_at_tail (as_list h0 d) n))

val dll_insert_before (#t:Type0) (n':node t) (d:dll t) (n:node t) :
  HST.Stack unit
    (requires (fun h0 -> dll_valid h0 d /\ node_valid h0 n /\ (fp_node n `B.loc_disjoint` fp_dll h0 d) /\ n' `L.memP` as_list h0 d))
    (ensures (fun h0 () h1 ->
         B.modifies (fp_dll h1 d) h0 h1 /\
         fp_dll h1 d `loc_equiv` B.loc_union (fp_dll h0 d) (fp_node n) /\
         dll_valid h1 d /\ node_valid h1 n /\
         unchanged_node_vals h0 h1 (as_list h1 d) /\
         as_list h1 d == l_insert_before n' (as_list h0 d) n))

val dll_insert_after (#t:Type0) (n':node t) (d:dll t) (n:node t) :
  HST.Stack unit
    (requires (fun h0 -> dll_valid h0 d /\ node_valid h0 n /\ (fp_node n `B.loc_disjoint` fp_dll h0 d) /\ n' `L.memP` as_list h0 d))
    (ensures (fun h0 () h1 ->
         B.modifies (fp_dll h1 d) h0 h1 /\
         fp_dll h1 d `loc_equiv` B.loc_union (fp_dll h0 d) (fp_node n) /\
         dll_valid h1 d /\ node_valid h1 n /\
         unchanged_node_vals h0 h1 (as_list h1 d) /\
         as_list h1 d == l_insert_after n' (as_list h0 d) n))

unfold
let aux_fp_split_by_node (h0 h1:HS.mem) (d:dll 'a) (n:node 'a) =
  fp_dll h0 d `loc_equiv` B.loc_union (fp_dll h1 d) (fp_node n) /\
  fp_dll h1 d `B.loc_disjoint` fp_node n

val dll_remove_head (#t:Type0) (d:dll t) :
  HST.Stack unit
    (requires (fun h0 -> dll_valid h0 d /\ L.length (as_list h0 d) > 0))
    (ensures (fun h0 () h1 ->
         B.modifies (fp_dll h0 d) h0 h1 /\
         aux_fp_split_by_node h0 h1 d (L.hd (as_list h0 d)) /\
         dll_valid h1 d /\
         unchanged_node_vals h0 h1 (as_list h0 d) /\
         as_list h1 d == l_remove_head (as_list h0 d)))

val dll_remove_tail (#t:Type0) (d:dll t) :
  HST.Stack unit
    (requires (fun h0 -> dll_valid h0 d /\ L.length (as_list h0 d) > 0))
    (ensures (fun h0 () h1 ->
         B.modifies (fp_dll h0 d) h0 h1 /\
         aux_fp_split_by_node h0 h1 d (L.last (as_list h0 d)) /\
         dll_valid h1 d /\
         unchanged_node_vals h0 h1 (as_list h0 d) /\
         as_list h1 d == l_remove_tail (as_list h0 d)))

val dll_remove_mid (#t:Type0) (d:dll t) (n:node t) :
  HST.Stack unit
    (requires (fun h0 -> dll_valid h0 d /\ n `L.memP` as_list h0 d))
    (ensures (fun h0 () h1 ->
         B.modifies (fp_dll h0 d) h0 h1 /\
         aux_fp_split_by_node h0 h1 d n /\
         dll_valid h1 d /\
         unchanged_node_vals h0 h1 (as_list h0 d) /\
         as_list h1 d == l_remove_mid (as_list h0 d) n))

val dll_append (#t:Type0) (d1 d2:dll t) :
  HST.Stack unit
    (requires (fun h0 ->
         dll_valid h0 d1 /\
         dll_valid h0 d2 /\
         fp_dll h0 d1 `B.loc_disjoint` fp_dll h0 d2))
    (ensures (fun h0 () h1 ->
         B.modifies (fp_dll h0 d1 `B.loc_union` fp_dll h0 d2) h0 h1 /\ // TODO: fp update?
         dll_valid h1 d1 /\
         unchanged_node_vals h0 h1 (as_list h1 d1) /\
         as_list h1 d1 == as_list h0 d1 `l_append` as_list h1 d2))

/// Automatic validity maintenance
///
/// These are lemmas that you shouldn't really need to refer to
/// manually. If you do, it is (likely) a bug wrt the patterns, and
/// you should ask someone who knows about how this library works to
/// look at things.

val auto_dll_remains_valid_upon_staying_unchanged (h0 h1:HS.mem) (l:B.loc) (d:dll 'a) :
  Lemma
    (requires (dll_valid h0 d /\
               B.modifies l h0 h1 /\
               B.loc_disjoint (fp_dll h0 d) l))
    (ensures (dll_valid h1 d))
    [SMTPat (dll_valid h0 d); SMTPat (dll_valid h1 d); SMTPat (B.modifies l h0 h1)]

val auto_node_remains_valid_upon_staying_unchanged (h0 h1:HS.mem) (l:B.loc) (n:node 'a) :
  Lemma
    (requires (node_valid h0 n /\
               B.modifies l h0 h1 /\
               B.loc_disjoint (fp_node n) l))
    (ensures (node_valid h1 n))
    [SMTPat (node_valid h0 n); SMTPat (node_valid h1 n); SMTPat (B.modifies l h0 h1)]

val auto_node_remains_unchanged_upon_staying_unchanged_val (h0 h1:HS.mem) (n:node 'a) :
  Lemma
    (requires (node_valid h0 n /\
               unchanged_node_val h0 h1 n))
    (ensures (node_valid h1 n))
    [SMTPat (node_valid h1 n); SMTPat (node_valid h0 n); SMTPat (unchanged_node_val h0 h1 n)]

/// Automatic footprint maintenance
///
/// These are lemmas that you shouldn't really need to refer to
/// manually. If you do, it is (likely) a bug wrt the patterns, and
/// you should ask someone who knows about how this library works to
/// look at things.

val auto_dll_fp_upon_staying_unchanged (h0 h1:HS.mem) (l:B.loc) (d:dll 'a) :
  Lemma
    (requires (dll_valid h0 d /\
               B.modifies l h0 h1 /\
               B.loc_disjoint (fp_dll h0 d) l))
    (ensures (fp_dll h1 d == fp_dll h0 d))
    [SMTPat (fp_dll h1 d); SMTPat (dll_valid h0 d); SMTPat (B.modifies l h0 h1)]

/// Automatic value maintenance
///
/// These are lemmas that you shouldn't really need to refer to
/// manually. If you do, it is (likely) a bug wrt the patterns, and
/// you should ask someone who knows about how this library works to
/// look at things.

val auto_dll_as_list_staying_unchanged (h0 h1:HS.mem) (l:B.loc) (d:dll 'a) :
  Lemma
    (requires (dll_valid h0 d /\
               B.modifies l h0 h1 /\
               B.loc_disjoint (fp_dll h0 d) l))
    (ensures (as_list h1 d == as_list h0 d))
    [SMTPat (as_list h1 d); SMTPat (dll_valid h0 d); SMTPat (B.modifies l h0 h1)]

val auto_node_val_staying_unchanged (h0 h1:HS.mem) (l:B.loc) (n:node 'a) :
  Lemma
    (requires (node_valid h0 n /\
               B.modifies l h0 h1 /\
               B.loc_disjoint (fp_node n) l))
    (ensures (g_node_val h1 n == g_node_val h0 n))
    [SMTPat (g_node_val h1 n); SMTPat (node_valid h0 n); SMTPat (B.modifies l h0 h1)]

val auto_node_val_unchanged_staying_unchanged (h0 h1:HS.mem) (n:node 'a) :
  Lemma
    (requires (node_valid h0 n /\
               unchanged_node_val h0 h1 n))
    (ensures (g_node_val h1 n == g_node_val h0 n))
    [SMTPat (g_node_val h1 n); SMTPat (node_valid h0 n); SMTPat (unchanged_node_val h0 h1 n)]

/// Properties of nodes inside and outside lists
///
/// These are lemmas that you shouldn't really need to refer to
/// manually. If you do, it is (likely) a bug wrt the patterns, and
/// you should ask someone who knows about how this library works to
/// look at things.

val auto_node_in_list_is_included (h0:HS.mem) (n:node 'a) (d:dll 'a) :
  Lemma
    (requires (dll_valid h0 d /\
               node_valid h0 n /\
               n `L.memP` as_list h0 d))
    (ensures (B.loc_includes (fp_dll h0 d) (fp_node n)))
    [SMTPat (B.loc_includes (fp_dll h0 d) (fp_node n));
     SMTPat (dll_valid h0 d);
     SMTPat (node_valid h0 n)]
