open Common

let dump_jsonnet_ast file =
  (* let cst = Tree_sitter_jsonnet.Parse.file file in *)
  (* let res = Parse_jsonnet_tree_sitter.parse file in *)
  let ast = Parse_jsonnet.parse_program file in
  pr2 (AST_jsonnet.show_program ast)

let dump_jsonnet_core file =
  let ast = Parse_jsonnet.parse_program file in
  let core = Desugar_jsonnet.desugar_program ast in
  pr2 (Core_jsonnet.show_program core)
