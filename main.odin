package ouau
import "core:bufio"
import "core:fmt"
import "core:mem/virtual"
import "core:os"
import "core:strings"
main :: proc() {
	// Arena
	v: virtual.Arena
	err := virtual.arena_init_growing(&v)
	ensure(err == nil)
	varena := virtual.arena_allocator(&v)
	defer virtual.arena_destroy(&v)
	//
	sb := strings.builder_make(varena)
	defer strings.builder_destroy(&sb)
	// ARGS
	if len(os.args) < 2 {
		fmt.println("Usage: lua-odin <file|repl|ast|bytes> <file>")
		os.exit(1)
	}
	//
	user_args := os.args[1:]
	switch user_args[0] {
	case "repl":
		reader: bufio.Reader
		bufio.reader_init(&reader, os.stream_from_handle(os.stdin), bufio.DEFAULT_BUF_SIZE, varena)
		xtra_args := user_args[1:]
		i := NEW_INTERPRETER(nil, varena)
		for {
			fmt.println("Ouau=>> ")
			line, err := bufio.reader_read_string(&reader, '\n', varena)
			if err != nil do OUAU_ERR("ERR: Failed to read input", err, &sb, false, 1)
			line = strings.trim_space(line)
			if line == "exit" do OUAU_RESULT("", "Bye!", &sb, true)
			OUAU_RUN_STRING(line, &sb, false, varena, i)
		}
	case "file":
		// Create one interpreter for the entire REPL session
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
		_ = PARSE_CHUNK(&p)
		DUMP_AST(&p)
	case "bytes":
		unimplemented("TODO")
	}
}

