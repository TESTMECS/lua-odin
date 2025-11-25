package parser_test

import "base:runtime"
import "core:mem/virtual"
import "core:testing"

import parser "../"

@(test)
test_do :: proc(t: ^testing.T) {
	using parser
	v: virtual.Arena
	err := virtual.arena_init_growing(&v)
	defer virtual.arena_destroy(&v)
	testing.expectf(t, err == nil, "Error initializing arena::(%v)", err)

	input := `
	do
		local a = 1
		function add(a,b) return a + b end
		add(1,2)
	end`
	p, errr := NEW_PARSER(input, &v)
	testing.expectf(t, errr == nil, "Error creating Parser::(%v)", err)
	nodeid, errrr := p->CHUNK()
	testing.expectf(t, errrr == nil, "Error parsing chunk::(%v)", err)
	DUMP_AST(&p)
	EXPECT_NODE(p.nodes.kind[0], .BLOCK, t)
	EXPECT_NODE(p.nodes.kind[1], .BLOCK, t)
	// local a = 1
	EXPECT_NODE(p.nodes.kind[2], .LOCAL, t)
	EXPECT_NODE(p.nodes.kind[3], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[4], .LITERAL, t)
	// function add(a,b)
	EXPECT_NODE(p.nodes.kind[5], .FUNCTION, t)
	EXPECT_NODE(p.nodes.kind[6], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[7], .IDENTIFIER, t)
	// return a+b end
	EXPECT_NODE(p.nodes.kind[8], .BLOCK, t)
	EXPECT_NODE(p.nodes.kind[9], .RETURN, t)
	EXPECT_NODE(p.nodes.kind[10], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[11], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[12], .BINARY, t)
	// add(1,2)
	EXPECT_NODE(p.nodes.kind[13], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[14], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[15], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[16], .CALL, t)
}
@(test)
test_conditionals :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil, "Error initializing arena::(%v)")
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	input := `
	local a = 1
	local b = 2
	local c = 3
	if a == 1 then
		b = 1
	elseif c > 2 then
		b = 200
	else
		print(b)
	end
	`


	p, errr := NEW_PARSER(input, v)
	testing.expectf(t, errr == nil, "Error creating parser::(%v)", err)

	nodeid, errrr := p->CHUNK()
	testing.expectf(t, errrr == nil, "Error parsing chunk::(%v)", err)

	// DUMP_AST(&p)
	EXPECT_NODE(p.nodes.kind[0], .BLOCK, t)
	// a
	EXPECT_NODE(p.nodes.kind[1], .LOCAL, t)
	EXPECT_NODE(p.nodes.kind[2], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[3], .LITERAL, t)
	// b
	EXPECT_NODE(p.nodes.kind[4], .LOCAL, t)
	EXPECT_NODE(p.nodes.kind[5], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[6], .LITERAL, t)
	// c
	EXPECT_NODE(p.nodes.kind[7], .LOCAL, t)
	EXPECT_NODE(p.nodes.kind[8], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[9], .LITERAL, t)
	// if
	EXPECT_NODE(p.nodes.kind[10], .IF, t)
	// a == 1
	EXPECT_NODE(p.nodes.kind[11], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[12], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[13], .LITERAL, t)
	// b = 1
	EXPECT_NODE(p.nodes.kind[14], .BLOCK, t)
	EXPECT_NODE(p.nodes.kind[15], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[16], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[17], .LITERAL, t)
	// c > 2
	EXPECT_NODE(p.nodes.kind[18], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[19], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[20], .LITERAL, t)
	// b = 200
	EXPECT_NODE(p.nodes.kind[21], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[22], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[23], .LITERAL, t)
	// print(b)
	EXPECT_NODE(p.nodes.kind[24], .BLOCK, t)
	EXPECT_NODE(p.nodes.kind[25], .CALL, t)
	EXPECT_NODE(p.nodes.kind[26], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[27], .IDENTIFIER, t)
}
@(test)
test_functions :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil, "Error initializing arena::(%v)")
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	input := `
	local function add(a,b)
		return a + b
	end
	add(1,2)
	`
	p, errr := NEW_PARSER(input, v)
	testing.expectf(t, errr == nil, "Error creating parser::(%v)", err)
	nodeid, errrr := p->CHUNK()
	testing.expectf(t, errrr == nil, "Error parsing chunk::(%v)", err)
	// DUMP_AST(&p)
	EXPECT_NODE(p.nodes.kind[0], .BLOCK, t)
	// local function
	EXPECT_NODE(p.nodes.kind[1], .LOCAL, t)
	EXPECT_NODE(p.nodes.kind[2], .FUNCTION, t)
	// (a,b)
	EXPECT_NODE(p.nodes.kind[3], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[4], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[5], .BLOCK, t)
	// return a + b
	EXPECT_NODE(p.nodes.kind[6], .RETURN, t)
	EXPECT_NODE(p.nodes.kind[7], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[8], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[9], .IDENTIFIER, t)
	// add(1,2)
	EXPECT_NODE(p.nodes.kind[10], .CALL, t)
	EXPECT_NODE(p.nodes.kind[11], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[12], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[13], .LITERAL, t)
}
@(test)
test_tables :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil, "Error initializing arena::(%v)")
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	input := `
	local a = {
		b = 1,
		c = 2,
		d = 3
	};
	`


	p, errr := NEW_PARSER(input, v)
	testing.expectf(t, errr == nil, "Error parsing chunk::(%v)", err)

	nodeid, errrr := p->CHUNK()
	testing.expectf(t, errrr == nil, "Error parsing chunk::(%v)", err)

	// DUMP_AST(&p)
	EXPECT_NODE(p.nodes.kind[0], .BLOCK, t)
	// local a
	EXPECT_NODE(p.nodes.kind[1], .LOCAL, t)
	EXPECT_NODE(p.nodes.kind[2], .IDENTIFIER, t)
	// {
	EXPECT_NODE(p.nodes.kind[3], .TABLE, t)
	// b = 1
	EXPECT_NODE(p.nodes.kind[4], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[5], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[6], .LITERAL, t)
	// c = 2
	EXPECT_NODE(p.nodes.kind[7], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[8], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[9], .LITERAL, t)
	// d = 3
	EXPECT_NODE(p.nodes.kind[10], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[11], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[12], .LITERAL, t)
}
@(test)
test_for :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil, "Error initializing arena::(%v)")
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	input := `
	for i = 1, 10 do
		print(i)
	end
	`
	p, errr := NEW_PARSER(input, v)
	testing.expectf(t, errr == nil, "Error parsing chunk::(%v)", err)
	program, errrr := p->CHUNK()
	testing.expectf(t, errrr == nil, "Error parsing chunk::(%v)", err)
	// DUMP_AST(&p)
	EXPECT_NODE(p.nodes.kind[0], .BLOCK, t)
	// for
	EXPECT_NODE(p.nodes.kind[1], .FOR, t)
	EXPECT_NODE(p.nodes.kind[2], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[3], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[4], .BLOCK, t)
	// print(i)
	EXPECT_NODE(p.nodes.kind[5], .CALL, t)
	EXPECT_NODE(p.nodes.kind[6], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[7], .IDENTIFIER, t)
}
@(test)
test_while :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil, "Error initializing arena::(%v)")
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	input := `
	while true do
		print("Hello")
	end`
	p, errr := NEW_PARSER(input, v)
	testing.expectf(t, errr == nil, "Error parsing chunk::(%v)", err)
	program, errrr := p->CHUNK()
	testing.expectf(t, errrr == nil, "Error parsing chunk::(%v)", err)
	// DUMP_AST(&p)
	EXPECT_NODE(p.nodes.kind[0], .BLOCK, t)
	// while
	EXPECT_NODE(p.nodes.kind[1], .WHILE, t)
	EXPECT_NODE(p.nodes.kind[2], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[3], .BLOCK, t)
	// print("Hello")
	EXPECT_NODE(p.nodes.kind[4], .CALL, t)
	EXPECT_NODE(p.nodes.kind[5], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[6], .STRING, t)
}
@(test)
test_repeat :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil, "Error initializing arena::(%v)")
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	input := `
	repeat
		print("Hello");
		i = i + 1;
	until false;`
	p, errr := NEW_PARSER(input, v)
	testing.expectf(t, errr == nil, "Error creating parser::(%v)", err)
	program, errrr := p->CHUNK()
	testing.expectf(t, errrr == nil, "Error parsing chunk::(%v)", err)
	// DUMP_AST(&p)
	EXPECT_NODE(p.nodes.kind[0], .BLOCK, t)
	EXPECT_NODE(p.nodes.kind[1], .REPEAT, t)
	EXPECT_NODE(p.nodes.kind[2], .UBLOCK, t)
	EXPECT_NODE(p.nodes.kind[3], .BLOCK, t)
	EXPECT_NODE(p.nodes.kind[4], .CALL, t)
	EXPECT_NODE(p.nodes.kind[5], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[6], .STRING, t)
	EXPECT_NODE(p.nodes.kind[7], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[8], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[9], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[10], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[11], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[12], .LITERAL, t)
}
@(test)
test_list :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil, "Error initializing arena::(%v)")
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	input := `
	local a = {
		b = 1,
		c = 2,
		d = 3
	}
	print(#a)`
	p, errr := NEW_PARSER(input, v)
	testing.expectf(t, errr == nil, "Error parsing chunk::(%v)", err)
	nodeid, errrr := p->CHUNK()
	testing.expectf(t, errrr == nil, "Error parsing chunk::(%v)", err)
	// DUMP_AST(&p)
	EXPECT_NODE(p.nodes.kind[0], .BLOCK, t)
	// local a
	EXPECT_NODE(p.nodes.kind[1], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[2], .TABLE, t)
	// b = 1
	EXPECT_NODE(p.nodes.kind[3], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[4], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[5], .LITERAL, t)
	// c = 2
	EXPECT_NODE(p.nodes.kind[6], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[7], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[8], .LITERAL, t)
	// d = 3
	EXPECT_NODE(p.nodes.kind[9], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[10], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[11], .LITERAL, t)
	// print(#a)
	EXPECT_NODE(p.nodes.kind[12], .CALL, t)
	EXPECT_NODE(p.nodes.kind[13], .IDENTIFIER, t)
	EXPECT_NODE(p.nodes.kind[14], .UNARY, t)
	EXPECT_NODE(p.nodes.kind[15], .IDENTIFIER, t)
}
@(test)
test_logic :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil, "Error initializing arena::(%v)")
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)

	input := `
	local a = true and false 
	local b = true or false
	local bb = not true
	local c = 1 < 2
	local d = 1 <= 2
	local e = 1 > 2
	local f = 1 >= 2
	local g = 1 == 2
	local h = 1 ~= 2
	local i = 1 * 2
	local j = 1 / 2
	local k = 1 % 2
	local l = 1 ^ 2 `
	p, errr := NEW_PARSER(input, v)
	testing.expectf(t, errr == nil, "Error parsing chunk::(%v)", err)
	nodeid, errrr := p->CHUNK()
	testing.expectf(t, errrr == nil, "Error parsing chunk::(%v)", err)
	DUMP_AST(&p)
}
@(test)
test_bitwise :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil, "Error initializing arena::(%v)")
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	input := `
	local a = 1 << 2 
	local b = 1 >> 2
	local c = 1 & 2
	local d = 1 | 2
	local e = 1 ~ 2
	local g = !1`
	p, errr := NEW_PARSER(input, v)
	testing.expectf(t, errr == nil, "Error creating parser::(%v)", err)
	nodeid, errrr := p->CHUNK()
	testing.expectf(t, errrr == nil, "Error parsing chunk::(%v)", err)
	DUMP_AST(&p)
}
@(test)
test_array_assignment :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil, "Error initializing arena::(%v)")
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	input := `
	local a = {1,2,3};
	a[1] = 5;`
	p, errr := NEW_PARSER(input, v)
	testing.expectf(t, errr == nil, "Error creating parser::(%v)", err)
	nodeid, errrr := CHUNK(&p)
	testing.expectf(t, errrr == nil, "Error parsing chunk::(%v)", err)
	DUMP_AST(&p)
}
@(test)
test_array_access :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil, "Error initializing arena::(%v)")
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	input := `a[1];`
	p, errr := NEW_PARSER(input, v)
	testing.expectf(t, errr == nil, "Error creating parser::(%v)", err)
	nodeid, errrr := CHUNK(&p)
	testing.expectf(t, errrr == nil, "Error parsing chunk::(%v)", err)
	DUMP_AST(&p)
}
@(test)
test_string :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil, "Error initializing arena::(%v)")
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	input := `local a = "Hello World";`
	p, errr := NEW_PARSER(input, v)
	testing.expectf(t, errr == nil, "Error creating parser::(%v)", err)
	nodeid, errrr := p->CHUNK()
	testing.expectf(t, errrr == nil, "Error parsing chunk::(%v)", err)
	DUMP_AST(&p)
}
@(test)
test_global :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil, "Error initializing arena::(%v)")
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	input := `
	do
		global a = 1;
		return a;
	end`
	p, errr := NEW_PARSER(input, v)
	testing.expectf(t, errr == nil, "Error creating parser::(%v)", err)
	nodeid, errrr := p->CHUNK()
	testing.expectf(t, errrr == nil, "Error parsing chunk::(%v)", err)
	DUMP_AST(&p)
}

