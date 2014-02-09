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

module PS = GenCommon.PS
module R  = Runtime
module Reader = MessageReader.Make(GenCommon.M)


(* Generate a decoder lambda for converting from a uint16 to the associated enum value. *)
let generate_enum_decoder ~nodes_table ~scope ~enum_node ~indent ~field_ofs =
  let header = Printf.sprintf "%s(fun u16 -> match u16 with\n" indent in
  let match_cases =
    let scope_relative_name = GenCommon.get_scope_relative_name nodes_table scope enum_node in
    let enumerants =
      match PS.Node.unnamed_union_get enum_node with
      | PS.Node.Enum enum_group ->
          PS.Node.Enum.enumerants_get enum_group
      | _ ->
          failwith "Decoded non-enum node where enum node was expected."
    in
    let buf = Buffer.create 512 in
    for i = 0 to R.Array.length enumerants - 1 do
      let enumerant = R.Array.get enumerants i in
      let match_case =
        Printf.sprintf "%s  | %u -> %s.%s\n"
          indent
          i
          scope_relative_name
          (String.capitalize (PS.Enumerant.name_get enumerant))
      in
      Buffer.add_string buf match_case
    done;
    let footer = Printf.sprintf "%s  | v -> %s.Undefined_ v)\n" indent scope_relative_name in
    let () = Buffer.add_string buf footer in
    Buffer.contents buf
  in
  header ^ match_cases


(* Generate an accessor for decoding an enum type. *)
let generate_enum_accessor ~nodes_table ~scope ~enum_node ~indent ~field_name ~field_ofs
    ~default =
  let decoder_declaration =
    Printf.sprintf "%s  let decode =\n%s%s  in\n"
      indent
      (generate_enum_decoder ~nodes_table ~scope ~enum_node ~indent:(indent ^ "    ") ~field_ofs)
      indent
  in
  Printf.sprintf "%slet %s_get x =\n%s%sdecode (get_struct_field_uint16 ~default:%u x %u)\n"
    indent
    field_name
    decoder_declaration
    indent
    default
    (2 * field_ofs)



(* Generate an accessor for retrieving a list of the given type. *)
let generate_list_accessor ~nodes_table ~scope ~list_type ~indent ~field_name ~field_ofs =
  match PS.Type.unnamed_union_get list_type with
  | PS.Type.Void ->
      Printf.sprintf "%slet %s_get x = failwith \"not implemented\"\n"
        indent
        field_name
  | PS.Type.Bool ->
      Printf.sprintf "%slet %s_get x = get_struct_field_bit_list x %u\n"
        indent
        field_name
        field_ofs
  | PS.Type.Int8 ->
      Printf.sprintf "%slet %s_get x = get_struct_field_int8_list x %u\n"
        indent
        field_name
        field_ofs
  | PS.Type.Int16 ->
      Printf.sprintf "%slet %s_get x = get_struct_field_int16_list x %u\n"
        indent
        field_name
        field_ofs
  | PS.Type.Int32 ->
      Printf.sprintf "%slet %s_get x = get_struct_field_int32_list x %u\n"
        indent
        field_name
        field_ofs
  | PS.Type.Int64 ->
      Printf.sprintf "%slet %s_get x = get_struct_field_int64_list x %u\n"
        indent
        field_name
        field_ofs
  | PS.Type.Uint8 ->
      Printf.sprintf "%slet %s_get x = get_struct_field_uint8_list x %u\n"
        indent
        field_name
        field_ofs
  | PS.Type.Uint16 ->
      Printf.sprintf "%slet %s_get x = get_struct_field_uint16_list x %u\n"
        indent
        field_name
        field_ofs
  | PS.Type.Uint32 ->
      Printf.sprintf "%slet %s_get x = get_struct_field_uint32_list x %u\n"
        indent
        field_name
        field_ofs
  | PS.Type.Uint64 ->
      Printf.sprintf "%slet %s_get x = get_struct_field_uint64_list x %u\n"
        indent
        field_name
        field_ofs
  | PS.Type.Float32 ->
      Printf.sprintf "%slet %s_get x = get_struct_field_float32_list x %u\n"
        indent
        field_name
        field_ofs
  | PS.Type.Float64 ->
      Printf.sprintf "%slet %s_get x = get_struct_field_float64_list x %u\n"
        indent
        field_name
        field_ofs
  | PS.Type.Text ->
      Printf.sprintf "%slet %s_get x = get_struct_field_text_list x %u\n"
        indent
        field_name
        field_ofs
  | PS.Type.Data ->
      Printf.sprintf "%slet %s_get x = get_struct_field_blob_list x %u\n"
        indent
        field_name
        field_ofs
  | PS.Type.List _ ->
      Printf.sprintf "%slet %s_get x = get_struct_field_list_list x %u\n"
        indent
        field_name
        field_ofs
  | PS.Type.Enum enum_def ->
      let enum_id = PS.Type.Enum.typeId_get enum_def in
      let enum_node = Hashtbl.find_exn nodes_table enum_id in
      let decoder_declaration =
        Printf.sprintf "%s  let decode =\n%s%s  in\n"
          indent
          (generate_enum_decoder ~nodes_table ~scope ~enum_node
            ~indent:(indent ^ "    ") ~field_ofs)
          indent
      in
      Printf.sprintf "%slet %s_get x =\n%s%s  get_struct_field_enum_list x %u decode\n"
        indent
        field_name
        decoder_declaration
        indent
        (field_ofs * 2)
  | PS.Type.Struct _ ->
      Printf.sprintf "%slet %s_get x = get_struct_field_struct_list x %u\n"
        indent
        field_name
        field_ofs
  | PS.Type.Interface _ ->
      Printf.sprintf "%slet %s_get x = failwith \"not implemented\"\n"
        indent
        field_name
  | PS.Type.AnyPointer ->
      Printf.sprintf "%slet %s_get x = failwith \"not implemented\"\n"
        indent
        field_name
  | PS.Type.Undefined_ x ->
       failwith (Printf.sprintf "Unknown Type union discriminant %d" x)


(* FIXME: would be nice to unify default value logic with [generate_constant]... *)
let generate_field_accessor ~nodes_table ~scope ~indent field =
  let field_name = String.uncapitalize (PS.Field.name_get field) in
  match PS.Field.unnamed_union_get field with
  | PS.Field.Group group ->
      Printf.sprintf "%slet %s_get x = x\n"
        indent
        field_name
  | PS.Field.Slot slot ->
      let field_ofs = Uint32.to_int (PS.Field.Slot.offset_get slot) in
      let tp = PS.Field.Slot.type_get slot in
      let default = PS.Field.Slot.defaultValue_get slot in
      begin match (PS.Type.unnamed_union_get tp, PS.Value.unnamed_union_get default) with
      | (PS.Type.Void, PS.Value.Void) ->
          Printf.sprintf "%slet %s_get x = ()\n" indent field_name
      | (PS.Type.Bool, PS.Value.Bool a) ->
          Printf.sprintf "%slet %s_get x = get_struct_field_bit ~default_bit:%s x %u %u\n"
            indent
            field_name
            (if a then "true" else "false")
            (field_ofs / 8)
            (field_ofs mod 8)
      | (PS.Type.Int8, PS.Value.Int8 a) ->
          Printf.sprintf "%slet %s_get x = get_struct_field_int8 ~default:%d x %u\n"
            indent
            field_name
            a
            field_ofs
      | (PS.Type.Int16, PS.Value.Int16 a) ->
          Printf.sprintf "%slet %s_get x = get_struct_field_int16 ~default:%d x %u\n"
            indent
            field_name
            a
            (field_ofs * 2)
      | (PS.Type.Int32, PS.Value.Int32 a) ->
          (Printf.sprintf "%slet %s_get x = get_struct_field_int32 ~default:%sl x %u\n"
            indent
            field_name
            (Int32.to_string a)
            (field_ofs * 4)) ^
          (Printf.sprintf "%slet %s_get_int_exn x = Int32.to_int (%s_get x)\n"
            indent
            field_name
            field_name)
      | (PS.Type.Int64, PS.Value.Int64 a) ->
          (Printf.sprintf "%slet %s_get x = get_struct_field_int64 ~default:%sL x %u\n"
            indent
            field_name
            (Int64.to_string a)
            (field_ofs * 8)) ^
          (Printf.sprintf "%slet %s_get_int_exn x = Int64.to_int (%s_get x)\n"
            indent
            field_name
            field_name)
      | (PS.Type.Uint8, PS.Value.Uint8 a) ->
          Printf.sprintf "%slet %s_get x = get_struct_field_uint8 ~default:%d x %u\n"
            indent
            field_name
            a
            field_ofs
      | (PS.Type.Uint16, PS.Value.Uint16 a) ->
          Printf.sprintf "%slet %s_get x = get_struct_field_uint16 ~default:%d x %u\n"
            indent
            field_name
            a
            (field_ofs * 2)
      | (PS.Type.Uint32, PS.Value.Uint32 a) ->
          let default =
            if Uint32.compare a Uint32.zero = 0 then
              "Uint32.zero"
            else
              Printf.sprintf "(Uint32.of_string \"%s\")" (Uint32.to_string a)
          in
          (Printf.sprintf "%slet %s_get x = get_struct_field_uint32 ~default:%s x %u\n"
            indent
            field_name
            default
            (field_ofs * 4)) ^
          (Printf.sprintf "%slet %s_get_int_exn x = Uint32.to_int (%s_get x)\n"
            indent
            field_name
            field_name)
      | (PS.Type.Uint64, PS.Value.Uint64 a) ->
          let default =
            if Uint64.compare a Uint64.zero = 0 then
              "Uint64.zero"
            else
              Printf.sprintf "(Uint64.of_string \"%s\")" (Uint64.to_string a)
          in
          (Printf.sprintf "%slet %s_get x = get_struct_field_uint64 ~default:%s x %u\n"
            indent
            field_name
            default
            (field_ofs * 8)) ^
          (Printf.sprintf "%slet %s_get_int_exn x = Uint64.to_int (%s_get x)\n"
            indent
            field_name
            field_name)
      | (PS.Type.Float32, PS.Value.Float32 a) ->
          let default_int32 = Int32.bits_of_float a in
          Printf.sprintf
            "%slet %s_get x = Int32.float_of_bits (get_struct_field_int32 ~default:%sl x %u)\n"
              indent
              field_name
              (Int32.to_string default_int32)
              (field_ofs * 4)
      | (PS.Type.Float64, PS.Value.Float64 a) ->
          let default_int64 = Int64.bits_of_float a in
          Printf.sprintf
            "%slet %s_get x = Int64.float_of_bits (get_struct_field_int64 ~default:%sL x %u)\n"
              indent
              field_name
              (Int64.to_string default_int64)
              (field_ofs * 8)
      | (PS.Type.Text, PS.Value.Text a) ->
          Printf.sprintf "%slet %s_get x = get_struct_field_text ~default:\"%s\" x %u\n"
            indent
            field_name
            (String.escaped a)
            (field_ofs * 8)
      | (PS.Type.Data, PS.Value.Data a) ->
          Printf.sprintf "%slet %s_get x = get_struct_field_blob ~default:\"%s\" x %u\n"
            indent
            field_name
            (String.escaped a)
            (field_ofs * 8)
      | (PS.Type.List list_def, PS.Value.List pointer_slice_opt) ->
          let has_trivial_default =
            begin match pointer_slice_opt with
            | Some pointer_slice ->
                begin match Reader.decode_pointer pointer_slice with
                | Pointer.Null -> true
                | _ -> false
                end
            | None ->
                true
            end
          in
          if has_trivial_default then
            let list_type = PS.Type.List.elementType_get list_def in
            generate_list_accessor ~nodes_table ~scope ~list_type ~indent ~field_name ~field_ofs
          else
            failwith "Default values for lists are not implemented."
      | (PS.Type.Enum enum_def, PS.Value.Enum val_uint16) ->
          let enum_id = PS.Type.Enum.typeId_get enum_def in
          let enum_node = Hashtbl.find_exn nodes_table enum_id in
          generate_enum_accessor
            ~nodes_table ~scope ~enum_node ~indent ~field_name ~field_ofs
            ~default:val_uint16
      | (PS.Type.Struct struct_def, PS.Value.Struct pointer_slice_opt) ->
          let has_trivial_default =
            begin match pointer_slice_opt with
            | Some pointer_slice ->
                begin match Reader.decode_pointer pointer_slice with
                | Pointer.Null -> true
                | _ -> false
                end
            | None ->
                true
            end
          in
          if has_trivial_default then
              Printf.sprintf "%slet %s_get x = get_struct_field_struct x %u\n"
                indent
                field_name
                field_ofs
          else
              failwith "Default values for structs are not implemented."
      | (PS.Type.Interface iface_def, PS.Value.Interface) ->
          Printf.sprintf "%slet %s_get x = failwith \"not implemented\"\n"
            indent
            field_name
      | (PS.Type.AnyPointer, PS.Value.AnyPointer pointer) ->
          Printf.sprintf "%slet %s_get x = get_struct_pointer x %u\n"
            indent
            field_name
            field_ofs
      | (PS.Type.Undefined_ x, _) ->
          failwith (Printf.sprintf "Unknown Field union discriminant %u." x)

      (* All other cases represent an ill-formed default value in the plugin request *)
      | (PS.Type.Void, _)
      | (PS.Type.Bool, _)
      | (PS.Type.Int8, _)
      | (PS.Type.Int16, _)
      | (PS.Type.Int32, _)
      | (PS.Type.Int64, _)
      | (PS.Type.Uint8, _)
      | (PS.Type.Uint16, _)
      | (PS.Type.Uint32, _)
      | (PS.Type.Uint64, _)
      | (PS.Type.Float32, _)
      | (PS.Type.Float64, _)
      | (PS.Type.Text, _)
      | (PS.Type.Data, _)
      | (PS.Type.List _, _)
      | (PS.Type.Enum _, _)
      | (PS.Type.Struct _, _)
      | (PS.Type.Interface _, _)
      | (PS.Type.AnyPointer, _) ->
          let err_msg =
            Printf.sprintf "The default value for field \"%s\" has an unexpected type." field_name
          in
          failwith err_msg
      end
  | PS.Field.Undefined_ x ->
      failwith (Printf.sprintf "Unknown Field union discriminant %u." x)


(* Generate a function for unpacking a capnp union type as an OCaml variant. *)
let generate_union_accessors ~nodes_table ~scope struct_def fields =
  let indent = String.make (2 * (List.length scope + 1)) ' ' in
  let cases = List.fold_left fields ~init:[] ~f:(fun acc field ->
    let field_name = String.uncapitalize (PS.Field.name_get field) in
    let ctor_name = String.capitalize field_name in
    let field_value = PS.Field.discriminantValue_get field in
    let field_has_void_type =
      match PS.Field.unnamed_union_get field with
      | PS.Field.Slot slot ->
          begin match PS.Type.unnamed_union_get (PS.Field.Slot.type_get slot) with
          | PS.Type.Void -> true
          | _ -> false
          end
      | _ -> false
    in
    if field_has_void_type then
      (Printf.sprintf "%s  | %u -> %s"
        indent
        field_value
        ctor_name) :: acc
    else
      (Printf.sprintf "%s  | %u -> %s (%s_get x)"
        indent
        field_value
        ctor_name
        field_name) :: acc)
  in
  let header = [
    Printf.sprintf "%slet unnamed_union_get x =" indent;
    Printf.sprintf "%s  match get_struct_field_uint16 ~default:0 x %u with"
      indent ((Uint32.to_int (PS.Node.Struct.discriminantOffset_get struct_def)) * 2);
  ] in
  let footer = [
    Printf.sprintf "%s  | v -> Undefined_ v\n" indent
  ] in
  (GenCommon.generate_union_type nodes_table scope struct_def fields) ^ "\n" ^
  String.concat ~sep:"\n" (header @ cases @ footer)



(* Generate accessors for retrieving all fields of a struct, regardless of whether
 * or not the fields are packed into a union.  (Fields packed inside a union are
 * not exposed in the module signature. *)
let generate_accessors ~nodes_table ~scope struct_def fields =
  let indent = String.make (2 * (List.length scope + 1)) ' ' in
  let accessors = List.fold_left fields ~init:[] ~f:(fun acc field ->
    let x = generate_field_accessor ~nodes_table ~scope ~indent field in
    x :: acc)
  in
  String.concat ~sep:"" accessors


let generate_constant ~nodes_table ~scope const_def =
  let const_val = PS.Node.Const.value_get const_def in
  match PS.Value.unnamed_union_get const_val with
  | PS.Value.Void ->
      "()"
  | PS.Value.Bool a ->
      if a then "true" else "false"
  | PS.Value.Int8 a
  | PS.Value.Int16 a
  | PS.Value.Uint8 a
  | PS.Value.Uint16 a ->
      Int.to_string a
  | PS.Value.Int32 a ->
      (Int32.to_string a) ^ "l"
  | PS.Value.Int64 a ->
      (Int64.to_string a) ^ "L"
  | PS.Value.Uint32 a ->
      Printf.sprintf "(Uint32.of_string %s)" (Uint32.to_string a)
  | PS.Value.Uint64 a ->
      Printf.sprintf "(Uint64.of_string %s)" (Uint64.to_string a)
  | PS.Value.Float32 a ->
      Printf.sprintf "(Int32.float_of_bits %sl)"
        (Int32.to_string (Int32.bits_of_float a))
  | PS.Value.Float64 a ->
      Printf.sprintf "(Int64.float_of_bits %sL)"
        (Int64.to_string (Int64.bits_of_float a))
  | PS.Value.Text a
  | PS.Value.Data a ->
      "\"" ^ (String.escaped a) ^ "\""
  | PS.Value.List _ ->
      failwith "List constants are not yet implemented."
  | PS.Value.Enum enum_val ->
      let const_type = PS.Node.Const.type_get const_def in
      let enum_node =
        match PS.Type.unnamed_union_get const_type with
        | PS.Type.Enum enum_def ->
            let enum_id = PS.Type.Enum.typeId_get enum_def in
            Hashtbl.find_exn nodes_table enum_id
        | _ ->
            failwith "Decoded non-enum node where enum node was expected."
      in
      let enumerants =
        match PS.Node.unnamed_union_get enum_node with
        | PS.Node.Enum enum_group -> PS.Node.Enum.enumerants_get enum_group
        | _ -> failwith "Decoded non-enum node where enum node was expected."
      in
      let scope_relative_name =
        GenCommon.get_scope_relative_name nodes_table scope enum_node in
      if enum_val >= R.Array.length enumerants then
        Printf.sprintf "%s.Undefined_ %u" scope_relative_name enum_val
      else
        let enumerant = R.Array.get enumerants enum_val in
        Printf.sprintf "%s.%s"
          scope_relative_name
          (String.capitalize (PS.Enumerant.name_get enumerant))
  | PS.Value.Struct _ ->
      failwith "Struct constants are not yet implemented."
  | PS.Value.Interface ->
      failwith "Interface constants are not yet implemented."
  | PS.Value.AnyPointer _ ->
      failwith "AnyPointer constants are not yet implemented."
  | PS.Value.Undefined_ x ->
      failwith (Printf.sprintf "Unknown Value union discriminant %u." x)


(* Generate the OCaml module corresponding to a struct definition.  [scope] is a
 * stack of scope IDs corresponding to this lexical context, and is used to figure
 * out what module prefixes are required to properly qualify a type.
 *
 * Raises: Failure if the children of this node contain a cycle. *)
let rec generate_struct_node ~nodes_table ~scope ~nested_modules ~node struct_def =
  let unsorted_fields =
    let fields_accessor = PS.Node.Struct.fields_get struct_def in
    let rec loop_fields acc i =
      if i = R.Array.length fields_accessor then
        acc
      else
        let field = R.Array.get fields_accessor i in
        loop_fields (field :: acc) (i + 1)
    in
    loop_fields [] 0
  in
  (* Sorting in reverse code order allows us to avoid a List.rev *)
  let all_fields = List.sort unsorted_fields ~cmp:(fun x y ->
    - (Int.compare (PS.Field.codeOrder_get x) (PS.Field.codeOrder_get y)))
  in
  let union_fields = List.filter all_fields ~f:(fun field ->
    (PS.Field.discriminantValue_get field) <> PS.Field.noDiscriminant)
  in
  let accessors = generate_accessors ~nodes_table ~scope struct_def all_fields in
  let union_accessors =
    match union_fields with
    | [] -> ""
    | _  -> generate_union_accessors ~nodes_table ~scope struct_def union_fields
  in
  let indent = String.make (2 * (List.length scope + 1)) ' ' in
  let unique_typename = GenCommon.make_unique_typename ~nodes_table node in
  (Printf.sprintf "%stype t = ro StructStorage.t option\n" indent) ^
  (Printf.sprintf "%stype %s = t\n" indent unique_typename) ^
  (Printf.sprintf "%stype array_t = ro ListStorage.t\n\n" indent) ^
    nested_modules ^ accessors ^ union_accessors ^
    (Printf.sprintf "%slet of_message x = get_root_struct x\n" indent)


(* Generate the OCaml module and type signature corresponding to a node.  [scope] is
 * a stack of scope IDs corresponding to this lexical context, and is used to figure out
 * what module prefixes are required to properly qualify a type.
 *
 * Raises: Failure if the children of this node contain a cycle. *)
and generate_node
    ~(suppress_module_wrapper : bool)
    ~(nodes_table : (Uint64.t, PS.Node.t) Hashtbl.t)
    ~(scope : Uint64.t list)
    ~(node_name : string)
    (node : PS.Node.t)
: string =
  let node_id = PS.Node.id_get node in
  let indent = String.make (2 * (List.length scope)) ' ' in
  let generate_nested_modules () =
    match Topsort.topological_sort nodes_table (GenCommon.children_of nodes_table node) with
    | Some child_nodes ->
        let child_modules = List.map child_nodes ~f:(fun child ->
          let child_name = GenCommon.get_unqualified_name ~parent:node ~child in
          generate_node ~suppress_module_wrapper:false ~nodes_table
            ~scope:(node_id :: scope) ~node_name:child_name child)
        in
        begin match child_modules with
        | [] -> ""
        | _  -> (String.concat ~sep:"\n" child_modules) ^ "\n"
        end
    | None ->
        let error_msg = Printf.sprintf
          "The children of node %s (%s) have a cyclic dependency."
          (Uint64.to_string node_id)
          (PS.Node.displayName_get node)
        in
        failwith error_msg
  in
  match PS.Node.unnamed_union_get node with
  | PS.Node.File ->
      generate_nested_modules ()
  | PS.Node.Struct struct_def ->
      let nested_modules = generate_nested_modules () in
      let body =
        generate_struct_node ~nodes_table ~scope ~nested_modules ~node struct_def
      in
      if suppress_module_wrapper then
        body
      else
        (Printf.sprintf "%smodule %s = struct\n" indent node_name) ^
        body ^
        (Printf.sprintf "%send\n" indent)
  | PS.Node.Enum enum_def ->
      let nested_modules = generate_nested_modules () in
      let body =
        GenCommon.generate_enum_sig ~nodes_table ~scope ~nested_modules enum_def
      in
      if suppress_module_wrapper then
        body
      else
        (Printf.sprintf "%smodule %s = struct\n" indent node_name) ^
        body ^
        (Printf.sprintf "%send\n" indent)
  | PS.Node.Interface iface_def ->
      generate_nested_modules ()
  | PS.Node.Const const_def ->
      Printf.sprintf "%slet %s = %s\n"
        indent
        (String.uncapitalize node_name)
        (generate_constant ~nodes_table ~scope const_def)
  | PS.Node.Annotation annot_def ->
      generate_nested_modules ()
  | PS.Node.Undefined_ x ->
      failwith (Printf.sprintf "Unknown Node union discriminant %u" x)
