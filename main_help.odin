package ouau
import "core:fmt"
import "core:mem/virtual"
/*
*	 ./main_help.odin
*	 Copyright(C) 2025 TESTMEE
*	 Help functions for Ouau.
*/
OUAU_EVAL_STRING :: proc(
	input: string,
	v: ^virtual.Arena,
	i: ^Interpreter,
) -> (
	return_value: Value,
	err: OuauError,
) {
	p := NEW_PARSER(input, v) or_return
	root := PARSE_CHUNK(&p) or_return
	i.nodes = &p.nodes
	return_value = INTERPRET(i, root)
	return return_value, nil
}
dump_node :: proc(p: ^Parser, id: u32, indent: int) {
	// Print each AST node.
	for _ in 0 ..< indent {
		fmt.print("  ")
	}
	fmt.printf("%s", p.nodes.kind[id])
	#partial switch p.nodes.kind[id] {
	case .BINARY:
		fmt.printf(" <.%s.>", p.nodes.token[id])
	case:
	}
	if p.nodes.name[id] != "" {
		fmt.printf(" name='%s'", p.nodes.name[id])
	}
	if p.nodes.int_value[id] != 0 {
		fmt.printf(" int=%d", p.nodes.int_value[id])
	}
	if p.nodes.string_value[id] != "" {
		fmt.printf(" str='%s'", p.nodes.string_value[id])
	}
	fmt.println()
	child := p.nodes.first_child[id]
	for child != 0 {
		dump_node(p, child, indent + 1)
		child = p.nodes.next_sibling[child]
	}
}

DUMP_AST :: proc(p: ^Parser) {
	fmt.println("=== AST DUMP ===")
	dump_node(p, 0, 0)
}

