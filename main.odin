package ouau
import "core:bufio"
import "core:fmt"
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

main :: proc() {
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	varena := virtual.arena_allocator(v)
	defer virtual.arena_destroy(v)

	sb := strings.builder_make(varena)
	defer strings.builder_destroy(&sb)

	if len(os.args) < 2 {
		fmt.println(HELP_MSG)
		os.exit(1)
	}

	user_args := os.args[1:]

	switch user_args[0] {
	case "repl":
		reader: bufio.Reader
		bufio.reader_init(&reader, os.stream_from_handle(os.stdin), bufio.DEFAULT_BUF_SIZE, varena)
		xtra_args := user_args[1:]
		i := NEW_INTERPRETER(nil, varena)

		for {

			fmt.println(PROMPT)
			input_builder := strings.builder_make(varena)
			defer strings.builder_destroy(&input_builder)

			for {

				line, err := bufio.reader_read_string(&reader, '\n', varena)
				if err != nil do OUAU_ERR("ERR: Failed to read input", err, &sb, false, 1)
				line = strings.trim_space(line)

				if strings.has_suffix(line, "\\") {
					line = strings.trim_suffix(line, "\\")
					strings.write_string(&input_builder, line)
					strings.write_byte(&input_builder, '\n')
					fmt.print("...")
					continue
				}
				 else {
					strings.write_string(&input_builder, line)
					break
				}
			}
			complete_input := strings.to_string(input_builder)
			if complete_input == "exit" do OUAU_RESULT("", EXIT_MSG, &sb, true)
			OUAU_RUN_STRING(complete_input, &sb, false, varena, i)
		}
	case "file":
		i := NEW_INTERPRETER(nil, varena)
		assert(user_args[1] != "")
		file_path := user_args[1]
		file, ok := os.read_entire_file_from_filename(file_path, varena)
		if !ok do OUAU_ERR("ERR: Failed to read file", err, &sb, false, 1)
		OUAU_RUN_STRING(string(file), &sb, false, varena, i)
	case "ast":
		assert(user_args[1] != "")
		file_path := user_args[1]
		file, ok := os.read_entire_file_from_filename(file_path, varena)
		if !ok do OUAU_ERR("ERR: Failed to read file", err, &sb, false, 1)
		p := NEW_PARSER(string(file), varena)
		_ = p->PARSE_CHUNK()
		DUMP_AST(&p)
	case "regs":
		unimplemented("TODO")
	}
}

