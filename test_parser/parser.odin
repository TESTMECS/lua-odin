package parser_test

import "core:log"
import "core:mem/virtual"
import "core:testing"

import parser "../"

@(test)
test_parser :: proc(t: ^testing.T) {
	using parser

	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)

	input := `
	do
		local a = 1;
		function add(a,b) return a+b end;
		add(1,2);
	end
	`


	expect := proc(kind: NODE_KIND, expect: NODE_KIND, t: ^testing.T) {
		if expect != kind {
			log.info("expect", expect, "got", kind)
			testing.fail(t)
		}
	}
	expect_child := proc(p: ^Parser, parent: NODEID, child: NODEID, t: ^testing.T) {
		if p.nodes.first_child[parent] != child {
			log.info("expect", child, "got", p.nodes.first_child[parent])
			testing.fail(t)
		}
	}


	p := NEW_PARSER(input, varena)
	nodeid := PARSE_CHUNK(&p)

	// dump_ast(&p)

	expect(p.nodes.kind[0], .BLOCK, t) // id:0
	expect_child(&p, 0, 1, t)
	expect(p.nodes.kind[1], .BLOCK, t) // id:1
	expect_child(&p, 1, 2, t)
	expect(p.nodes.kind[2], .LOCAL, t) // id:2
	expect_child(&p, 2, 3, t)
	expect(p.nodes.kind[3], .IDENTIFIER, t)
	expect(p.nodes.kind[4], .LITERAL, t)
	expect(p.nodes.kind[5], .FUNCTION, t) // id:6
	expect_child(&p, 5, 6, t) // name is the child
	expect(p.nodes.kind[6], .IDENTIFIER, t) // param
	expect(p.nodes.kind[7], .IDENTIFIER, t)
	expect(p.nodes.kind[8], .BLOCK, t)
	expect_child(&p, 8, 9, t) // Return value is child of the block
	expect(p.nodes.kind[9], .RETURN, t)
	expect_child(&p, 9, 12, t) // Return value is child of the
	expect(p.nodes.kind[10], .IDENTIFIER, t)
	expect(p.nodes.kind[11], .IDENTIFIER, t)
	expect(p.nodes.kind[12], .BINARY, t)
	expect(p.nodes.kind[13], .IDENTIFIER, t)
	expect(p.nodes.kind[14], .LITERAL, t)
	expect(p.nodes.kind[15], .LITERAL, t)
	expect(p.nodes.kind[16], .CALL, t)
}
@(test)
test_conditionals :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)

	input := `
	local a = 1;
	local b = 2;
	local c = 3;
	if a == 1 then
		b = 1
	elseif c > 2 then
		b = 200
	else
		print(b)
	end
	`


	p := NEW_PARSER(input, varena)
	nodeid := PARSE_CHUNK(&p)
	// dump_ast(&p)
}
@(test)
test_functions :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)

	input := `
	local function add(a,b)
		return a + b
	end
	add(1,2)
	`


	p := NEW_PARSER(input, varena)
	nodeid := PARSE_CHUNK(&p)
	// dump_ast(&p)
}
@(test)
test_tables :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)

	input := `
	local a = {
		b = 1,
		c = 2,
		d = 3,
	}
	`


	p := NEW_PARSER(input, varena)
	nodeid := PARSE_CHUNK(&p)
	// dump_ast(&p)
}
@(test)
test_for :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)

	input := `
	for i = 1, 10 do
		print(i)
	end
	`


	p := parser.NEW_PARSER(input, varena)
	program := parser.PARSE_CHUNK(&p)
	// dump_ast(&p)
}
@(test)
test_while :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)
	input := `
	while true do
		print("Hello")
	end
	`


	p := parser.NEW_PARSER(input, varena)
	program := parser.PARSE_CHUNK(&p)
	// dump_ast(&p)
}
@(test)
test_repeat :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)
	input := `
	repeat
		print("Hello");
		i = i + 1;
	until false; 
	`


	p := parser.NEW_PARSER(input, varena)
	program := parser.PARSE_CHUNK(&p)
	// dump_ast(&p)
}
@(test)
test_list :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)
	input := `
	local a = {
		b = 1,
		c = 2,
		d = 3,
	}
	print(#a)
	`


	p := NEW_PARSER(input, varena)
	nodeid := PARSE_CHUNK(&p)
	// dump_ast(&p)
}
@(test)
test_logic :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)
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
	local l = 1 ^ 2
	`


	p := NEW_PARSER(input, varena)
	nodeid := PARSE_CHUNK(&p)
	// dump_ast(&p)
}
@(test)
test_bitwise :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)

	input := `
	local a = 1 << 2 
	local b = 1 >> 2
	local c = 1 & 2
	local d = 1 | 2
	local e = 1 ~ 2
	local g = !1
	`


	p := NEW_PARSER(input, varena)
	nodeid := PARSE_CHUNK(&p)
	// dump_ast(&p)
}
@(test)
test_parse_forlist :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)
	input := `
	local a = {1,2,3};
	`


	p := NEW_PARSER(input, varena)
	nodeid := PARSE_CHUNK(&p)
	dump_ast(&p)
}
@(test)
test_array_assignment :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)
	input := `
	local a = {1,2,3};
	a[1] = 5;
	`


	p := NEW_PARSER(input, varena)
	nodeid := PARSE_CHUNK(&p)
	dump_ast(&p)
}
@(test)
test_array_access :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)
	input := `
	a[1];
	`


	p := NEW_PARSER(input, varena)
	nodeid := PARSE_CHUNK(&p)
	// dump_ast(&p)
}
@(test)
test_string :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)

	input := `
	local a = "Hello World";
	`


	p := NEW_PARSER(input, varena)
	nodeid := PARSE_CHUNK(&p)
	// log.info(p.nodes)
}

