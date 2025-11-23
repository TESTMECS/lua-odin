package ouau
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
/*
*	 ./main_help.odin
*	 Copyright(C) 2025 TESTMEE
*	 Help functions for Ouau.
*/
OUAU_RUN_STRING :: proc(
	input: string,
	sb: ^strings.Builder,
	is_exit := false,
	varena: mem.Allocator,
	i: ^Interpreter,
) {
	p := NEW_PARSER(input, varena)
	root := PARSE_CHUNK(&p)
	i.nodes = &p.nodes
	val := INTERPRET(i, root)
	fmt.println("RET:", val)
}
OUAU_ERR :: proc(
	msg: string,
	err: os.Error,
	sb: ^strings.Builder,
	is_exit := true,
	exit_code := 1,
) {
	strings.builder_reset(sb)
	fmt.sbprintln(sb, msg, err)
	err_msg := strings.to_string(sb^)
	if is_exit {
		fmt.eprintln(err_msg)
		os.exit(exit_code)
	}
	 else {
		fmt.println(err_msg)
	}
}
OUAU_RESULT :: proc(res: string, msg: string, sb: ^strings.Builder, is_exit := true) {
	strings.builder_reset(sb)
	fmt.sbprintln(sb, msg, res)
	result := strings.to_string(sb^)
	if is_exit {
		fmt.println("IS", result)
		os.exit(0)
	}
	 else {
		fmt.println("IS", result)
	}
}
dump_node :: proc(p: ^Parser, id: u32, indent: int) {
	for _ in 0 ..< indent {
		fmt.print("  ")
	}

	fmt.printf("%s", p.nodes.kind[id])

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

