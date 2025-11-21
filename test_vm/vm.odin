package test_vm

import vm "../"
import "core:log"
import "core:mem/virtual"
import "core:testing"
@(test)
test_vm :: proc(t: ^testing.T) {
	using vm
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)

	input := `local a = 1; return a;`
	p := NEW_PARSER(input, varena)
	nodeid := PARSE_CHUNK(&p)
	c := NEW_COMPILER(&p, varena)
	COMPILE_NODE(c, nodeid)
	insts := c.instructions[:]
	if len(insts) == 0 {
		testing.fail(t)
	}
	config := VM_Config {
		stack_size   = 256,
		call_depth   = 32,
		gc_threshold = 1024 * 1024,
		max_threads  = 4,
	}
	my_proto := COMPILER_TO_PROTOTYPE(c, varena)
	vm := NEW_VM(&config, varena)
	closure := new(Closure, varena)
	closure.proto = my_proto
	closure.is_native = false
	result := VM_EXECUTE(vm, closure, {})
	if result_val, ok := result.(f64); ok {
		testing.expect(t, result_val == 1, "result_val == 1")
	}
	 else {
		testing.fail(t)
	}
}
@(test)
test_block :: proc(t: ^testing.T) {
	using vm
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)

	input := `
	local a = 1;
	local b = 2;
	function add(a, b)
		return a + b
	end
	return add(a, b);
	`


	p := NEW_PARSER(input, varena)
	nodeid := PARSE_CHUNK(&p)
	// DUMP_AST(&p)
	c := NEW_COMPILER(&p, varena)
	COMPILE_NODE(c, nodeid)
	// In your test, after COMPILE_NODE:
	log.info("Compiler instructions: %v", c.instructions[:])
	log.info("Compiler constants: %v", c.constants[:])
	log.info("Compiler prototypes count: %d", len(c.prototypes))
	log.info("Compiler prototypes: %v", c.prototypes[:])


	insts := c.instructions[:]
	if len(insts) == 0 {
		testing.fail(t)
	}
	config := VM_Config {
		stack_size   = 256,
		call_depth   = 32,
		gc_threshold = 1024 * 1024,
		max_threads  = 4,
	}
	my_proto := COMPILER_TO_PROTOTYPE(c)
	// After conversion:
	log.info("Prototype proto count: %d", len(my_proto.proto))
	log.info("Prototype proto: %v", my_proto.proto[:])
	vm := NEW_VM(&config, varena)
	closure := new(Closure, varena)
	closure.proto = my_proto
	closure.is_native = false
	result := VM_EXECUTE(vm, closure, {})
	if result_val, ok := result.(f64); ok {
		log.info("Result is:", result)
		testing.expect(t, result_val == 3, "result_val != 3")
	}
	 else {
		testing.fail(t)
	}
}

