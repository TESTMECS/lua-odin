package test_vm

import vm "../"
import "core:log"
import "core:mem/virtual"
import "core:testing"

@(rodata)
config := vm.VM_Config {
	stack_size   = 256,
	call_depth   = 32,
	gc_threshold = 1024 * 1024,
	max_threads  = 4,
	debug_level  = 2,
	trace_gc     = true,
	trace_stack  = false,
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
	do
		local a = 1;
		return a;
	end
	`


	p := NEW_PARSER(input, varena)
	nodeid := PARSE_CHUNK(&p)

	new_nodes := new_clone(p.nodes, varena)
	c := NEW_COMPILER(new_nodes, varena)

	COMPILE_NODE(c, nodeid)
	insts := c.instructions[:]

	if len(insts) == 0 {
		testing.fail(t)
	}

	vm: ^VM = NEW_VM(&config)
	// log.info("VM %v", vm)

	main_proto := Prototype {
		header = GC_HEADER{marked = false, generation = 0, gctype = .PROTOTYPE},
		instructions = insts,
		constants = c.constants[:],
		proto = c.prototypes[:],
		upvalues = {},
		max_stack = c.max_stack,
		num_params = 0,
	}
	my_closure := new(Closure, varena)
	my_closure.header = GC_HEADER {
		marked     = false,
		generation = 0,
		gctype     = .CLOSURE,
	}
	my_closure.is_native = false
	my_closure.proto = &main_proto
	my_closure.upvalues = {}

	result_value := VM_EXECUTE(vm, my_closure, {})
	log.info("Result value: %v", result_value)
}

@(test)
test_function :: proc(t: ^testing.T) {
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
	clone_nodes := new_clone(p.nodes, varena)
	// DUMP_AST(&p)
	c := NEW_COMPILER(clone_nodes, varena)
	COMPILE_NODE(c, nodeid)
	// log.info("1. Compiler instructions: %v", c.instructions[:])
	// log.info("2. Compiler constants: %v", c.constants[:])
	// log.info("3. Compiler prototypes count: %d", len(c.prototypes))
	// log.info("Compiler prototypes: %v", c.prototypes[:])
	insts := c.instructions[:]
	if len(insts) == 0 {
		testing.fail(t)
	}
	vm: ^VM = NEW_VM(&config)
	// log.info("VM %v", vm)
	main_proto := Prototype {
		header = GC_HEADER{marked = false, generation = 0, gctype = .PROTOTYPE},
		instructions = insts,
		constants = c.constants[:],
		proto = c.prototypes[:],
		upvalues = {},
		max_stack = c.max_stack,
		num_params = 0,
	}
	my_closure := new(Closure, varena)
	my_closure.header = GC_HEADER {
		marked     = false,
		generation = 0,
		gctype     = .CLOSURE,
	}
	my_closure.is_native = false
	my_closure.proto = &main_proto
	my_closure.upvalues = {}
	result_value := VM_EXECUTE(vm, my_closure, {})
	if result_value == nil {
		testing.fail(t)
	}
}

