package ouau
import "core:bufio"
import "core:fmt"
import "core:io"
import "core:mem/virtual"
import "core:os"
import "core:strings"
/*
*	 ./main.odin
*	 Copyright(C) 2025 TESTMEE
*	 This file defines the main functions for Ouau CLI.
*/
HELP_MSG :: "Usage: lua-odin <file|repl|ast|regs> <file>"
PROMPT :: "(Ouau)$ "
EXIT_MSG :: "Bye!"
VERSION :: "0.0.1"

main :: proc() {
	if err := Ouau(); err != nil {
		fmt.eprintln("[ERROR]::(%v)", err)
		os.exit(1)
	} else {
		os.exit(0)
	}
}
@(private = "file")
Ouau :: proc() -> (main_err: Maybe(OuauError)) {
	v := new(virtual.Arena, context.allocator)
	virtual.arena_init_growing(v) or_return
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	old_allocator := context.allocator
	context.allocator = virtual.arena_allocator(v)
	defer context.allocator = old_allocator
	if len(os.args) < 2 || os.args[1] == "-h" || os.args[1] == "--help" {
		fmt.println(HELP_MSG)
		os.exit(1)
	}
	if os.args[1] == "-v" || os.args[1] == "--version" {
		fmt.println(VERSION)
		os.exit(0)
	}
	user_args := os.args[1:]
	switch user_args[0] {
	case "repl":
		reader: bufio.Reader
		bufio.reader_init(&reader, os.stream_from_handle(os.stdin), bufio.DEFAULT_BUF_SIZE)
		xtra_args := user_args[1:]
		i := NEW_INTERPRETER(nil, v)
		for {
			fmt.println(PROMPT)
			input_builder := strings.builder_make()
			defer strings.builder_destroy(&input_builder)
			for {
				line := bufio.reader_read_string(&reader, '\n') or_return
				line = strings.trim_space(line)
				if strings.has_suffix(line, "\\") {
					line = strings.trim_suffix(line, "\\")
					strings.write_string(&input_builder, line)
					strings.write_byte(&input_builder, '\n')
					fmt.print("...")
					continue
				} else {
					strings.write_string(&input_builder, line)
					break
				}
			}
			complete_input := strings.to_string(input_builder)
			if complete_input == "exit" do return nil
			return_value := OUAU_EVAL_STRING(complete_input, v, i) or_return
			fmt.println("==> ", return_value)
		}
	case "file":
		i := NEW_INTERPRETER(nil, v)
		assert(user_args[1] != "")
		file_path := user_args[1]
		if file, ok := os.read_entire_file_from_filename(file_path); ok {
			return_value := OUAU_EVAL_STRING(string(file), v, i) or_return
			fmt.println("==> ", return_value)
		} else {
			return io.Error.Unexpected_EOF
		}
	case "ast":
		assert(user_args[1] != "")
		file_path := user_args[1]
		if file, ok := os.read_entire_file_from_filename(file_path); ok {
			p := NEW_PARSER(string(file), v) or_return
			_, main_err = p->CHUNK()
			DUMP_AST(&p)
		} else {
			return io.Error.Unexpected_EOF
		}
	case "regs":
		unimplemented("TODO")
	}
	return nil
}

OUAU_EVAL_STRING :: proc(
	input: string,
	v: ^virtual.Arena,
	i: ^Interpreter,
) -> (
	return_value: Value,
	err: OuauError,
) {
	p := NEW_PARSER(input, v) or_return
	root := p->CHUNK() or_return
	i.nodes = &p.nodes
	return_value = INTERPRET(i, root)
	return return_value, nil
}
dump_node :: proc(p: ^Parser, id: u32, indent: int) {
	for _ in 0 ..< indent {
		fmt.print("  ")
	}
	fmt.printf("%s", p.nodes.kind[id])
	if p.nodes.kind[id] == .BINARY {
		defer fmt.printf(" %s", p.nodes.kind[id])
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

