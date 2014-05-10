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

(* Management of default values for structs and lists.  These values are
   passed as a pointers to data stored in the PluginSchema message
   generated by capnpc.  We will need to make a deep copy to transfer these
   objects into a StringStorage-based message, so we can easily serialize
   the string contents right into the generated code. *)


type t
type ident_t

(** [create ()] constructs a new, empty instance for recording default values. *)
val create : unit -> t

(** [add_struct defaults ident s] adds a deep copy of struct [s] to the
    defaults message, making it accessible under the specified identifier. *)
val add_struct : t -> ident_t ->
  Capnp.Message.ro CapnpRuntime.Common.Make(GenCommon.M).StructStorage.t -> unit

(** [add_list defaults ident lst] adds a deep copy of list [lst] to the
    defaults message, making it accessible under the specified identifier. *)
val add_list : t -> ident_t ->
  Capnp.Message.ro CapnpRuntime.Common.Make(GenCommon.M).ListStorage.t -> unit

(** [make_ident id field_name] constructs an identifier for the default value
    associated with the named field within the node with the given [id]. *)
val make_ident : Uint64.t -> string -> ident_t

(** [builder_string_of_ident ident] constructs a string identifier suitable for
    referring to a default value within generated code for Builders. *)
val builder_string_of_ident : ident_t -> string

(** [reader_string_of_ident ident] constructs a string identifier suitable for
    referring to a default value within generated code for Readers. *)
val reader_string_of_ident : ident_t -> string

(** [gen_builder_defaults defaults] generates code which does the following:
    1) Builds a string literal containing the message content
    2) Instantiates a message object from the contents of the string literal
    3) Instantiates struct and list descriptors which refer to the default
       values stored within that message object, which are suitable for
       use within the Builder implementation

    The generated code is returned as a list of lines. *)
val gen_builder_defaults : t -> string list

(** [gen_reader_defaults defaults] generates code which does the following:
    1) Instantiates a new message object of a type matching the functor parameter
    2) Deep copies the builder defaults into the new message
    3) Instantiates struct and list descriptors which refer to the default
       values stored within the new message object, which are suitable for
       use within the Reader implementation

    The generated code is returned as a list of lines. *)
val gen_reader_defaults : t -> string list

