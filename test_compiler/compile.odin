package compiler_test
import compiler "../"
import "core:fmt"
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
	// for i in insts {
	// 	fmt.printf("op: %v, a: %v, b: %v, c: %v\n", DECODE_ABC(i))
	// }
	if op, _, _, _ := DECODE_ABC(insts[0]); op != u32(Opcodes.LOADK) {
		fmt.println("First instruction is not LOADK")
		testing.fail(t)
	}
	if op, _, _, _ := DECODE_ABC(insts[1]); op != u32(Opcodes.MOVE) {
		fmt.println("Second instruction is not MOVE")
		testing.fail(t)
	}
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
	for i in insts {
		fmt.printf("op: %v, a: %v, b: %v, c: %v\n", DECODE_ABC(i))
	}
}

