(******************************************************************************
 * capnp-ocaml
 *
 * Copyright (c) 2013-2014, Paul Pelzl
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice,
 *     this list of conditions and the following disclaimer.
 *
 *  2. Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 ******************************************************************************)

open Core.Std
open OUnit2


let expect_packs_to unpacked packed =
  assert_equal packed (Capnp.Runtime.Packing.pack_string unpacked);
  assert_equal unpacked (Capnp.Runtime.Packing.unpack_string packed)


let packing_suite =
  let t0 ctx = expect_packs_to "" "" in
  let t1 ctx = expect_packs_to
      "\x00\x00\x00\x00\x00\x00\x00\x00"
      "\x00\x00"
  in
  let t2 ctx = expect_packs_to
      "\x00\x00\x0c\x00\x00\x22\x00\x00"
      "\x24\x0c\x22"
  in
  let t3 ctx = expect_packs_to
      "\x01\x03\x02\x04\x05\x07\x06\x08"
      "\xff\x01\x03\x02\x04\x05\x07\x06\x08\x00"
  in
  let t4 ctx = expect_packs_to
      "\x00\x00\x00\x00\x00\x00\x00\x00\x01\x03\x02\x04\x05\x07\x06\x08"
      "\x00\x00\xff\x01\x03\x02\x04\x05\x07\x06\x08\x00"
  in
  let t5 ctx = expect_packs_to
      "\x00\x00\x0c\x00\x00\x22\x00\x00\x01\x03\x02\x04\x05\x07\x06\x08"
      "\x24\x0c\x22\xff\x01\x03\x02\x04\x05\x07\x06\x08\x00"
  in
  let t6 ctx = expect_packs_to
      "\x01\x03\x02\x04\x05\x07\x06\x08\x08\x06\x07\x04\x05\x02\x03\x01"
      "\xff\x01\x03\x02\x04\x05\x07\x06\x08\x01\x08\x06\x07\x04\x05\x02\x03\x01"
  in
  let t7 ctx = expect_packs_to
      "\x01\x02\x03\x04\x05\x06\x07\x08\
       \x01\x02\x03\x04\x05\x06\x07\x08\
       \x01\x02\x03\x04\x05\x06\x07\x08\
       \x01\x02\x03\x04\x05\x06\x07\x08\
       \x00\x02\x04\x00\x09\x00\x05\x01"
      "\xff\x01\x02\x03\x04\x05\x06\x07\x08\x03\
       \x01\x02\x03\x04\x05\x06\x07\x08\
       \x01\x02\x03\x04\x05\x06\x07\x08\
       \x01\x02\x03\x04\x05\x06\x07\x08\
       \xd6\x02\x04\x09\x05\x01"
  in
  let t8 ctx = expect_packs_to
      "\x01\x02\x03\x04\x05\x06\x07\x08\
       \x01\x02\x03\x04\x05\x06\x07\x08\
       \x06\x02\x04\x03\x09\x00\x05\x01\
       \x01\x02\x03\x04\x05\x06\x07\x08\
       \x00\x02\x04\x00\x09\x00\x05\x01"
      "\xff\x01\x02\x03\x04\x05\x06\x07\x08\x03\
       \x01\x02\x03\x04\x05\x06\x07\x08\
       \x06\x02\x04\x03\x09\x00\x05\x01\
       \x01\x02\x03\x04\x05\x06\x07\x08\
       \xd6\x02\x04\x09\x05\x01"
  in
  let t9 ctx = expect_packs_to
      "\x08\x00\x64\x06\x00\x01\x01\x02\
       \x00\x00\x00\x00\x00\x00\x00\x00\
       \x00\x00\x00\x00\x00\x00\x00\x00\
       \x00\x00\x00\x00\x00\x00\x00\x00\
       \x00\x00\x01\x00\x02\x00\x03\x01"
      "\xed\x08\x64\x06\x01\x01\x02\x00\x02\xd4\x01\x02\x03\x01"
  in
  "serialize_packed" >::: [
    "empty" >:: t0;
    "zero" >:: t1;
    "sparse" >:: t2;
    "literal1" >:: t3;
    "concat1" >:: t4;
    "concat2" >:: t5;
    "literal2" >:: t6;
    "literals with compressible tail" >:: t7;
    "literals with compressible tail" >:: t8;
    "sparse" >:: t9;
  ]


(* Generator for characters with a distribution that resembles real
   cap'n proto data, with lots of zeros. *)
let random_char_generator () =
  let r = Random.int 6 in
  if r = 0 then
    Char.of_int_exn (Random.int 256)
  else
    '\x00'


let test_random ctx =
  let rec string_gen () =
    let s = Quickcheck.sg ~char_gen:random_char_generator () in
    (* input string must be word-aligned *)
    Capnp.Runtime.Util.str_slice ~stop:((String.length s) land (lnot 0x7)) s
  in
  Quickcheck.laws_exn "unpack(pack(x)) = x" 2000 string_gen (fun s ->
    let packed = Capnp.Runtime.Packing.pack_string s in
    let unpacked = Capnp.Runtime.Packing.unpack_string packed in
    unpacked = s)


let test_random_fragmented ctx =
  let rec string_gen () =
    let s = Quickcheck.sg ~char_gen:random_char_generator () in
    (* input string must be word-aligned *)
    Capnp.Runtime.Util.str_slice ~stop:((String.length s) land (lnot 0x7)) s
  in
  Quickcheck.laws_exn "unpack(fragment(pack(x))) = x" 2000 string_gen (fun s ->
    let open Capnp.Runtime in
    let packed = Packing.pack_string s in
    let packed_fragments = FragmentBuffer.empty () in
    let rec loop ofs =
      if ofs = String.length packed then
        ()
      else
        let next_ofs = min (String.length packed) (ofs + (Random.int 100)) in
        let () = FragmentBuffer.add_fragment packed_fragments
          (Util.str_slice ~start:ofs ~stop:next_ofs packed)
        in
        loop next_ofs
    in
    loop 0;
    let unpacked_fragments = FragmentBuffer.empty () in
    let () = Packing.unpack ~packed:packed_fragments
        ~unpacked:unpacked_fragments
    in
    let () = assert (FragmentBuffer.byte_count packed_fragments = 0) in
    let bytes_avail = FragmentBuffer.byte_count unpacked_fragments in
    let unpacked =
      match FragmentBuffer.remove_at_least unpacked_fragments bytes_avail with
      | Some v -> v
      | None -> assert false
    in
    let () = assert (FragmentBuffer.byte_count unpacked_fragments = 0) in
    unpacked = s)


let random_packing_suite =
  "random packing" >::: [
    "pack_string/unpack_string" >:: test_random;
    "fragmented pack_string/unpack_string" >:: test_random_fragmented
  ]

let () = run_test_tt_main packing_suite
let () = run_test_tt_main random_packing_suite
