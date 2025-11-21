package compiler_test
import compiler "../"
import "core:log"
import "core:mem/virtual"
import "core:testing"

@(test)
test_compiler :: proc(t: ^testing.T) {
	using compiler
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)

	input := `
	local a = 1;
	`


	p := NEW_PARSER(input, varena)
	nodeid := PARSE_CHUNK(&p)
	c := NEW_COMPILER(&p, varena)
	COMPILE_NODE(c, nodeid)
	log.info("Testing")
}

