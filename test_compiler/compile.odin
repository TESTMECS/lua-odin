package compiler_test
import compiler "../"
import "core:log"
import "core:mem/virtual"
import "core:testing"

@(test)
test_local :: proc(t: ^testing.T) {
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
	insts := c.instructions[:]
	if len(insts) == 0 {
		testing.fail(t)
	}
	CHECK_DECODE_ABC(t, insts[0], Opcodes.LOADK)
	CHECK_DECODE_ABC(t, insts[1], Opcodes.MOVE)
}

@(test)
test_block :: proc(t: ^testing.T) {
	using compiler
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)


	input := `
	do
		local a = 1;
		local b = 2;
		return a + b;
	end
	`


	p := NEW_PARSER(input, varena)
	nodeid := PARSE_CHUNK(&p)
	c := NEW_COMPILER(&p, varena)
	COMPILE_NODE(c, nodeid)
	insts := c.instructions[:]
	if len(insts) == 0 {
		testing.fail(t)
	}

	CHECK_DECODE_ABC(t, insts[0], Opcodes.LOADK)
	CHECK_DECODE_ABC(t, insts[1], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[2], Opcodes.LOADK)
	CHECK_DECODE_ABC(t, insts[3], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[4], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[5], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[6], Opcodes.ADD)
	CHECK_DECODE_ABC(t, insts[7], Opcodes.RETURN)
}
@(test)
test_function :: proc(t: ^testing.T) {
	using compiler
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)

	input := `
	function test()
		local a = 1;
		local b = 2;
		return a + b;
	end
	`


	p := NEW_PARSER(input, varena)
	nodeid := PARSE_CHUNK(&p)
	c := NEW_COMPILER(&p, varena)
	COMPILE_NODE(c, nodeid)
	insts := c.instructions[:]
	if len(insts) == 0 {
		testing.fail(t)
	}
	CHECK_DECODE_ABC(t, insts[0], Opcodes.CLOSURE)
	CHECK_DECODE_ABC(t, insts[1], Opcodes.SETGLOBAL)
}

