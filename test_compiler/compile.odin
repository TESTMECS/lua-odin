package compiler_test
import compiler "../"
import "core:log"
import "core:mem/virtual"
import "core:testing"
@(test)
test_local :: proc(t: ^testing.T) {
	using compiler
	v: virtual.Arena
	err := virtual.arena_init_growing(&v)
	ensure(err == nil, "Error initializing arena")
	defer virtual.arena_destroy(&v)
	my_alloc := virtual.arena_allocator(&v)
	input := `local a = 1+1;`
	p, p_err := NEW_PARSER(input, &v)
	testing.expectf(t, p_err == nil, "Error creating Parser::(%v)", p_err)
	nodeid, chunk_err := p->CHUNK()
	testing.expectf(t, chunk_err == nil, "Error parsing chunk::(%v)", chunk_err)
	c := NEW_COMPILER(&p.nodes, nil, &v)
	COMPILE_NODE(&c, nodeid)
	insts := new_clone(c.instructions, my_alloc)
	if len(insts) == 0 {
		testing.fail(t)
	}
	context.logger.lowest_level = .Debug
	for i in insts {
		DEBUG_INSTRUCTION(t, i)
	}
	my_insts := insts[:]
	CHECK_DECODE_ABC(t, my_insts[0], Opcodes.LOADK)
	CHECK_DECODE_ABC(t, my_insts[1], Opcodes.MOVE)
}
@(test)
test_block :: proc(t: ^testing.T) {
	using compiler
	v: virtual.Arena
	err := virtual.arena_init_growing(&v)
	ensure(err == nil, "Error initializing arena")
	defer virtual.arena_destroy(&v)
	input := `
	do
		local a = 1;
		local b = 2;
		return a + b;
	end`
	p, p_err := NEW_PARSER(input, &v)
	testing.expectf(t, p_err == nil, "Error creating Parser::(%v)", p_err)
	nodeid, chunk_err := p->CHUNK()
	testing.expectf(t, chunk_err == nil, "Error parsing chunk::(%v)", chunk_err)
	c := NEW_COMPILER(&p.nodes, nil, &v)
	COMPILE_NODE(&c, nodeid)
	insts := c.instructions[:]
	if len(insts) == 0 {
		testing.fail(t)
	}
	context.logger.lowest_level = .Debug
	for i in insts {
		DEBUG_INSTRUCTION(t, i)
	}
	log.infof("locals::(%v)", c.locals)
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
	v: virtual.Arena
	err := virtual.arena_init_growing(&v)
	ensure(err == nil, "Error initializing arena")
	defer virtual.arena_destroy(&v)
	input := `
	function test()
		local a = 1;
		local b = 2;
		return a + b;
	end`
	p, p_err := NEW_PARSER(input, &v)
	testing.expectf(t, p_err == nil, "Error creating Parser::(%v)", p_err)
	nodeid, chunk_err := p->CHUNK()
	testing.expectf(t, chunk_err == nil, "Error parsing chunk::(%v)", chunk_err)
	c := NEW_COMPILER(&p.nodes, nil, &v)
	COMPILE_NODE(&c, nodeid)
	insts := c.instructions[:]
	if len(insts) == 0 {
		testing.fail(t)
	}
	CHECK_DECODE_ABC(t, insts[0], Opcodes.CLOSURE)
	CHECK_DECODE_ABC(t, insts[1], Opcodes.SETGLOBAL)
}
@(test)
test_table :: proc(t: ^testing.T) {
	using compiler
	v: virtual.Arena
	err := virtual.arena_init_growing(&v)
	ensure(err == nil, "Error initializing arena")
	defer virtual.arena_destroy(&v)
	input := `
	local a = {
		b = 1,
		c = 2
	}`
	p, p_err := NEW_PARSER(input, &v)
	testing.expectf(t, p_err == nil, "Error creating Parser::(%v)", p_err)
	nodeid, chunk_err := p->CHUNK()
	testing.expectf(t, chunk_err == nil, "Error parsing chunk::(%v)", chunk_err)
	c := NEW_COMPILER(&p.nodes, nil, &v)
	COMPILE_NODE(&c, nodeid)
	insts := c.instructions[:]
	if len(insts) == 0 {
		testing.fail(t)
	}
	context.logger.lowest_level = .Debug
	for i in insts {
		DEBUG_INSTRUCTION(t, i)
	}
	CHECK_DECODE_ABC(t, insts[0], Opcodes.NEWTABLE)
	CHECK_DECODE_ABC(t, insts[1], Opcodes.GETGLOBAL)
	CHECK_DECODE_ABC(t, insts[2], Opcodes.LOADK)
}
@(test)
test_global :: proc(t: ^testing.T) {
	using compiler
	v: virtual.Arena
	err := virtual.arena_init_growing(&v)
	ensure(err == nil, "Error initializing arena")
	defer virtual.arena_destroy(&v)
	input := `
	global a = 1;`
	p, p_err := NEW_PARSER(input, &v)
	testing.expectf(t, p_err == nil, "Error creating Parser::(%v)", p_err)
	nodeid, chunk_err := p->CHUNK()
	testing.expectf(t, chunk_err == nil, "Error parsing chunk::(%v)", chunk_err)
	c := NEW_COMPILER(&p.nodes, nil, &v)
	COMPILE_NODE(&c, nodeid)
	insts := c.instructions[:]
	if len(insts) == 0 {
		testing.fail(t)
	}
	context.logger.lowest_level = .Debug
	for i in insts {
		DEBUG_INSTRUCTION(t, i)
	}
	CHECK_DECODE_ABC(t, insts[0], Opcodes.LOADK)
	CHECK_DECODE_ABC(t, insts[1], Opcodes.SETGLOBAL)
}
@(test)
test_while :: proc(t: ^testing.T) {
	using compiler
	v: virtual.Arena
	err := virtual.arena_init_growing(&v)
	ensure(err == nil, "Error initializing arena")
	defer virtual.arena_destroy(&v)
	input := `
	local a = 0;
	local b = true;
	while b do
		a = a + 1
		b = false
	end
	return a;`
	p, p_err := NEW_PARSER(input, &v)
	testing.expectf(t, p_err == nil, "Error creating Parser::(%v)", p_err)
	nodeid, chunk_err := p->CHUNK()
	testing.expectf(t, chunk_err == nil, "Error parsing chunk::(%v)", chunk_err)
	c := NEW_COMPILER(&p.nodes, nil, &v)
	COMPILE_NODE(&c, nodeid)
	insts := c.instructions[:]
	if len(insts) == 0 {
		testing.fail(t)
	}
	context.logger.lowest_level = .Debug
	for i in insts {
		DEBUG_INSTRUCTION(t, i)
	}
	CHECK_DECODE_ABC(t, insts[0], Opcodes.LOADK)
	CHECK_DECODE_ABC(t, insts[1], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[2], Opcodes.LOADBOOL)
	CHECK_DECODE_ABC(t, insts[3], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[4], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[5], Opcodes.JMP)
	CHECK_DECODE_ABC(t, insts[6], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[7], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[8], Opcodes.LOADK)
	CHECK_DECODE_ABC(t, insts[9], Opcodes.ADD)
	CHECK_DECODE_ABC(t, insts[10], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[11], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[12], Opcodes.LOADBOOL)
	CHECK_DECODE_ABC(t, insts[13], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[14], Opcodes.JMP)
}
@(test)
test_repeat :: proc(t: ^testing.T) {
	using compiler
	v: virtual.Arena
	err := virtual.arena_init_growing(&v)
	ensure(err == nil, "Error initializing arena")
	defer virtual.arena_destroy(&v)
	input := `
	local a = 0;
	local b = true;
	repeat
		a = a + 1
		b = false
	until b
	return a;`
	p, p_err := NEW_PARSER(input, &v)
	testing.expectf(t, p_err == nil, "Error creating Parser::(%v)", p_err)
	nodeid, chunk_err := p->CHUNK()
	testing.expectf(t, chunk_err == nil, "Error parsing chunk::(%v)", chunk_err)
	c := NEW_COMPILER(&p.nodes, nil, &v)
	COMPILE_NODE(&c, nodeid)
	insts := c.instructions[:]
	if len(insts) == 0 {
		testing.fail(t)
	}
	context.logger.lowest_level = .Debug
	for i in insts {
		DEBUG_INSTRUCTION(t, i)
	}
	CHECK_DECODE_ABC(t, insts[0], Opcodes.LOADK)
	CHECK_DECODE_ABC(t, insts[1], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[2], Opcodes.LOADBOOL)
	CHECK_DECODE_ABC(t, insts[3], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[4], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[5], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[6], Opcodes.LOADK)
	CHECK_DECODE_ABC(t, insts[7], Opcodes.ADD)
	CHECK_DECODE_ABC(t, insts[8], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[9], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[10], Opcodes.LOADBOOL)
	CHECK_DECODE_ABC(t, insts[11], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[12], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[13], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[14], Opcodes.JMP)
}
@(test)
test_for :: proc(t: ^testing.T) {
	using compiler
	v: virtual.Arena
	err := virtual.arena_init_growing(&v)
	ensure(err == nil, "Error initializing arena")
	defer virtual.arena_destroy(&v)
	input := `
	local a = 0;
	for i = 0, 9 do
		a = i + 1;
	end
	return a;`
	p, p_err := NEW_PARSER(input, &v)
	testing.expectf(t, p_err == nil, "Error creating Parser::(%v)", p_err)
	nodeid, chunk_err := p->CHUNK()
	testing.expectf(t, chunk_err == nil, "Error parsing chunk::(%v)", chunk_err)
	c := NEW_COMPILER(&p.nodes, nil, &v)
	COMPILE_NODE(&c, nodeid)
	insts := c.instructions[:]
	if len(insts) == 0 {
		testing.fail(t)
	}
	context.logger.lowest_level = .Debug
	for i in insts {
		DEBUG_INSTRUCTION(t, i)
	}
	CHECK_DECODE_ABC(t, insts[0], Opcodes.LOADK)
	CHECK_DECODE_ABC(t, insts[1], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[2], Opcodes.LOADK)
	CHECK_DECODE_ABC(t, insts[3], Opcodes.LOADK)
	CHECK_DECODE_ABC(t, insts[4], Opcodes.LOADK)
	CHECK_DECODE_ABC(t, insts[5], Opcodes.LE)
	CHECK_DECODE_ABC(t, insts[6], Opcodes.JMP)
	CHECK_DECODE_ABC(t, insts[7], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[8], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[9], Opcodes.LOADK)
	CHECK_DECODE_ABC(t, insts[10], Opcodes.ADD)
	CHECK_DECODE_ABC(t, insts[11], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[12], Opcodes.ADD)
	CHECK_DECODE_ABC(t, insts[13], Opcodes.MOVE)
}
@(test)
test_if :: proc(t: ^testing.T) {
	using compiler
	v: virtual.Arena
	err := virtual.arena_init_growing(&v)
	ensure(err == nil, "Error initializing arena")
	defer virtual.arena_destroy(&v)
	input := `
	if false then
		return 1;
	elseif true then
		return 3;
	else
		return 2;
	end`
	p, p_err := NEW_PARSER(input, &v)
	testing.expectf(t, p_err == nil, "Error creating Parser::(%v)", p_err)
	nodeid, chunk_err := p->CHUNK()
	testing.expectf(t, chunk_err == nil, "Error parsing chunk::(%v)", chunk_err)
	c := NEW_COMPILER(&p.nodes, nil, &v)
	COMPILE_NODE(&c, nodeid)
	insts := c.instructions[:]
	if len(insts) == 0 {
		testing.fail(t)
	}
	context.logger.lowest_level = .Debug
	for i in insts {
		DEBUG_INSTRUCTION(t, i)
	}
	CHECK_DECODE_ABC(t, insts[0], Opcodes.LOADBOOL)
	CHECK_DECODE_ABC(t, insts[1], Opcodes.JMP)
	CHECK_DECODE_ABC(t, insts[2], Opcodes.LOADK)
	CHECK_DECODE_ABC(t, insts[3], Opcodes.RETURN)
}
@(test)
test_call :: proc(t: ^testing.T) {
	using compiler
	v: virtual.Arena
	err := virtual.arena_init_growing(&v)
	ensure(err == nil, "Error initializing arena")
	defer virtual.arena_destroy(&v)
	input := `
	local a = 1;
	local b = 2;
	function add(a, b)
		return a + b
	end
	return add(a, b);`
	p, p_err := NEW_PARSER(input, &v)
	testing.expectf(t, p_err == nil, "Error creating Parser::(%v)", p_err)
	nodeid, chunk_err := p->CHUNK()
	testing.expectf(t, chunk_err == nil, "Error parsing chunk::(%v)", chunk_err)
	c := NEW_COMPILER(&p.nodes, nil, &v)
	COMPILE_NODE(&c, nodeid)
	insts := c.instructions[:]
	if len(insts) == 0 {
		testing.fail(t)
	}
	// DUMP_AST(&p)
	context.logger.lowest_level = .Debug
	for i in insts {
		DEBUG_INSTRUCTION(t, i)
	}
	CHECK_DECODE_ABC(t, insts[0], Opcodes.LOADK)
	CHECK_DECODE_ABC(t, insts[1], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[2], Opcodes.LOADK)
	CHECK_DECODE_ABC(t, insts[3], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[4], Opcodes.CLOSURE)
	CHECK_DECODE_ABC(t, insts[5], Opcodes.SETGLOBAL)
	CHECK_DECODE_ABC(t, insts[6], Opcodes.GETGLOBAL)
	CHECK_DECODE_ABC(t, insts[7], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[8], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[9], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[10], Opcodes.MOVE)
	CHECK_DECODE_ABC(t, insts[11], Opcodes.CALL)
	CHECK_DECODE_ABC(t, insts[12], Opcodes.RETURN)
}

