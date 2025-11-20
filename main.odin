package ouau
import "core:bufio"
import "core:fmt"
import "core:mem"
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
		
		// Create one interpreter for the entire REPL session
		i := NEW_INTERPRETER(nil, varena)
		
		for {
			fmt.println("Ouau=>> ")
			line, err := bufio.reader_read_string(&reader, '\n')
			if err != nil do OUAU_ERR("ERR: Failed to read input", err, &sb, false, 1)
			line = strings.trim_space(line)
			if line == "exit" do OUAU_RESULT("", "Bye!", &sb, true)
			OUAU_RUN_STRING(line, &sb, false, varena, i)
		}
	case "file":
		unimplemented("TODO")
	case "ast":
		unimplemented("TODO")
	case "bytes":
		unimplemented("TODO")
	}
}
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
CHECK_TY :: proc(val: Value) -> bool {
	switch v in val {
	case bool, f64, string, rawptr, (^Table), (^Closure), (^ReturnValue):
		return true
	}
	return false
}

