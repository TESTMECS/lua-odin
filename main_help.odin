package ouau
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
/*
	 ./main_help.odin
	 Copyright(C) 2025 TESTMEE
	 Help functions for Ouau.
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
DUMP_AST :: proc(p: ^Parser) {
	fmt.println("=== AST DUMP ===")
	for i in 0 ..< len(p.nodes.kind) {
		fmt.printf("Node %d: %s", i, p.nodes.kind[i])

		if p.nodes.name[i] != "" {
			fmt.printf(" name='%s'", p.nodes.name[i])
		}
		if p.nodes.int_value[i] != 0 {
			fmt.printf(" int=%d", p.nodes.int_value[i])
		}
		if p.nodes.string_value[i] != "" {
			fmt.printf(" str='%s'", p.nodes.string_value[i])
		}

		child_count := 0
		child := p.nodes.first_child[i]
		for child != 0 {
			child_count += 1
			child = p.nodes.next_sibling[child]
		}
		fmt.printf(" children=%d", child_count)
		fmt.println()
	}
}

