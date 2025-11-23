package parser_test

import "core:log"
import "core:mem/virtual"
import "core:testing"

import parser "../"

@(test)
test_do :: proc(t: ^testing.T) {
	using parser
	using testing
	err: ParserTestingError

	v := new(virtual.Arena, context.allocator)
	err = virtual.arena_init_growing(v)
	expectf(t, err == nil, "Error initializing arena %v", err)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)

	input := `
	do
		local a = 1;
		function add(a,b) return a+b end;
		add(1,2);
	end
	`


	p, err = NEW_PARSER(input, v)
	expectf(t, err == nil, "Error parsing chunk %v", err)

	testing.fail(t)
	nodeid, errr := p->PARSE_CHUNK()


	DUMP_AST(&p)

	EXPECT_NODE(p.nodes.kind[0], .BLOCK, t) // id:0
	EXPECT_CHILD(&p, 0, 1, t)
	EXPECT_NODE(p.nodes.kind[1], .BLOCK, t) // id:1
	EXPECT_CHILD(&p, 1, 2, t)
	EXPECT_NODE(p.nodes.kind[2], .LOCAL, t) // id:2
	EXPECT_CHILD(&p, 2, 3, t)
	EXPECT_NODE(p.nodes.kind[3], .IDENTIFIER, t)
	CHECK_ID(&p, 3, "a", t)
	EXPECT_NODE(p.nodes.kind[4], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[5], .FUNCTION, t) // id:6
	EXPECT_CHILD(&p, 5, 6, t) // name is the child
	EXPECT_NODE(p.nodes.kind[6], .IDENTIFIER, t) // param
	CHECK_ID(&p, 6, "a", t)
	EXPECT_NODE(p.nodes.kind[7], .IDENTIFIER, t)
	CHECK_ID(&p, 7, "b", t)
	EXPECT_NODE(p.nodes.kind[8], .BLOCK, t)
	EXPECT_CHILD(&p, 8, 9, t) // Return value is child of the block
	EXPECT_NODE(p.nodes.kind[9], .RETURN, t)
	EXPECT_CHILD(&p, 9, 12, t) // Return value is child of the
	EXPECT_NODE(p.nodes.kind[10], .IDENTIFIER, t)
	CHECK_ID(&p, 10, "a", t)
	EXPECT_NODE(p.nodes.kind[11], .IDENTIFIER, t)
	CHECK_ID(&p, 11, "b", t)
	EXPECT_NODE(p.nodes.kind[12], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[13], .IDENTIFIER, t)
	CHECK_ID(&p, 13, "add", t)
	EXPECT_NODE(p.nodes.kind[14], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[15], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[16], .CALL, t)
}
@(test)
test_conditionals :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)

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


	p := NEW_PARSER(input, v)
	nodeid, errr := p->PARSE_CHUNK()
	if errr != nil {
		log.errorf("Error parsing chunk %v", errr)
		testing.fail(t)
	}

	DUMP_AST(&p)

	EXPECT_NODE(p.nodes.kind[0], .BLOCK, t)
	EXPECT_NODE(p.nodes.kind[1], .LOCAL, t)
	EXPECT_NODE(p.nodes.kind[2], .IDENTIFIER, t)
	CHECK_ID(&p, 2, "a", t)
	EXPECT_NODE(p.nodes.kind[3], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[4], .LOCAL, t)
	EXPECT_NODE(p.nodes.kind[5], .IDENTIFIER, t)
	CHECK_ID(&p, 5, "b", t)
	EXPECT_NODE(p.nodes.kind[6], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[7], .LOCAL, t)
	EXPECT_NODE(p.nodes.kind[8], .IDENTIFIER, t)
	CHECK_ID(&p, 8, "c", t)
	EXPECT_NODE(p.nodes.kind[9], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[10], .IF, t)
	EXPECT_NODE(p.nodes.kind[11], .IDENTIFIER, t)
	CHECK_ID(&p, 11, "a", t)
	EXPECT_NODE(p.nodes.kind[12], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[13], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[14], .BLOCK, t)
	EXPECT_NODE(p.nodes.kind[15], .IDENTIFIER, t)
	CHECK_ID(&p, 15, "b", t)
	EXPECT_NODE(p.nodes.kind[16], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[17], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[18], .IDENTIFIER, t)
	CHECK_ID(&p, 18, "c", t)
	EXPECT_NODE(p.nodes.kind[19], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[20], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[21], .BLOCK, t)
	EXPECT_NODE(p.nodes.kind[22], .IDENTIFIER, t)
	CHECK_ID(&p, 22, "b", t)
	EXPECT_NODE(p.nodes.kind[23], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[24], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[25], .BLOCK, t)
	EXPECT_NODE(p.nodes.kind[26], .IDENTIFIER, t)
	CHECK_ID(&p, 26, "print", t)
	EXPECT_NODE(p.nodes.kind[27], .IDENTIFIER, t)
	CHECK_ID(&p, 27, "b", t)
	EXPECT_NODE(p.nodes.kind[28], .CALL, t)
}
@(test)
test_functions :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)

	input := `
	function add(a,b)
		return a + b
	end
	add(1,2)
	`


	p := NEW_PARSER(input, v)

	nodeid, errr := p->PARSE_CHUNK()
	if errr != nil {
		log.errorf("Error parsing chunk %v", errr)
		testing.fail(t)
	}

	DUMP_AST(&p)
}
@(test)
test_tables :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)

	input := `
	local a = {
		b = 1,
		c = 2,
		d = 3
	};
	`


	p := NEW_PARSER(input, v)
	nodeid, errr := p->PARSE_CHUNK()
	if errr != nil {
		log.errorf("Error parsing chunk %v", errr)
		testing.fail(t)
	}

	DUMP_AST(&p)

	EXPECT_NODE(p.nodes.kind[0], .BLOCK, t)
	EXPECT_NODE(p.nodes.kind[1], .LOCAL, t)
	EXPECT_NODE(p.nodes.kind[2], .IDENTIFIER, t)
	CHECK_ID(&p, 2, "a", t)
	EXPECT_NODE(p.nodes.kind[3], .TABLE, t)
	EXPECT_NODE(p.nodes.kind[4], .IDENTIFIER, t)
	CHECK_ID(&p, 4, "b", t)
	EXPECT_NODE(p.nodes.kind[5], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[6], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[7], .IDENTIFIER, t)
	CHECK_ID(&p, 7, "c", t)
	EXPECT_NODE(p.nodes.kind[8], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[9], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[10], .IDENTIFIER, t)
	CHECK_ID(&p, 10, "d", t)
	EXPECT_NODE(p.nodes.kind[11], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[12], .BINARY, t)
}
@(test)
test_for :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)

	input := `
	for i = 1, 10 do
		print(i)
	end
	`


	p := NEW_PARSER(input, v)
	program, errr := p->PARSE_CHUNK()
	if errr != nil {
		log.errorf("Error parsing chunk %v", errr)
		testing.fail(t)
	}

	DUMP_AST(&p)

	EXPECT_NODE(p.nodes.kind[0], .BLOCK, t)
	EXPECT_NODE(p.nodes.kind[1], .FOR, t)
	EXPECT_NODE(p.nodes.kind[2], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[3], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[4], .BLOCK, t)
	EXPECT_NODE(p.nodes.kind[5], .IDENTIFIER, t)
	CHECK_ID(&p, 5, "print", t)
	EXPECT_NODE(p.nodes.kind[6], .IDENTIFIER, t)
	CHECK_ID(&p, 6, "i", t)
	EXPECT_NODE(p.nodes.kind[7], .CALL, t)
}
@(test)
test_while :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)

	input := `
	while true do
		print("Hello")
	end
	`


	p := NEW_PARSER(input, v)
	program, errr := p->PARSE_CHUNK()
	if errr != nil {
		log.errorf("Error parsing chunk %v", errr)
		testing.fail(t)
	}

	DUMP_AST(&p)

	EXPECT_NODE(p.nodes.kind[0], .BLOCK, t)
	EXPECT_NODE(p.nodes.kind[1], .WHILE, t)
	EXPECT_NODE(p.nodes.kind[2], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[3], .BLOCK, t)
	EXPECT_NODE(p.nodes.kind[4], .IDENTIFIER, t)
	CHECK_ID(&p, 4, "print", t)
	EXPECT_NODE(p.nodes.kind[5], .STRING, t)
	EXPECT_NODE(p.nodes.kind[6], .CALL, t)
}
@(test)
test_repeat :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)

	input := `
	repeat
		print("Hello");
		i = i + 1;
	until false; 
	`


	p := NEW_PARSER(input, v)
	program, errr := p->PARSE_CHUNK()
	if errr != nil {
		log.errorf("Error parsing chunk %v", errr)
		testing.fail(t)
	}

	DUMP_AST(&p)

	EXPECT_NODE(p.nodes.kind[0], .BLOCK, t)
	EXPECT_NODE(p.nodes.kind[1], .REPEAT, t)
	EXPECT_NODE(p.nodes.kind[2], .BLOCK, t)
	EXPECT_NODE(p.nodes.kind[3], .IDENTIFIER, t)
	CHECK_ID(&p, 3, "print", t)
	EXPECT_NODE(p.nodes.kind[4], .STRING, t)
	EXPECT_NODE(p.nodes.kind[5], .CALL, t)
	EXPECT_NODE(p.nodes.kind[6], .IDENTIFIER, t)
	CHECK_ID(&p, 6, "i", t)
	EXPECT_NODE(p.nodes.kind[7], .IDENTIFIER, t)
	CHECK_ID(&p, 7, "i", t)
	EXPECT_NODE(p.nodes.kind[8], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[9], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[10], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[11], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[12], .UBLOCK, t)
}

@(test)
test_list :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)

	input := `
	local a = {
		b = 1,
		c = 2,
		d = 3
	}
	print(#a)
	`


	p := NEW_PARSER(input, v)
	nodeid, errr := p->PARSE_CHUNK()
	if errr != nil {
		log.errorf("Error parsing chunk %v", errr)
		testing.fail(t)
	}

	DUMP_AST(&p)

	EXPECT_NODE(p.nodes.kind[0], .BLOCK, t)
	EXPECT_NODE(p.nodes.kind[1], .LOCAL, t)
	EXPECT_NODE(p.nodes.kind[2], .IDENTIFIER, t)
	CHECK_ID(&p, 2, "a", t)
	EXPECT_NODE(p.nodes.kind[3], .TABLE, t)
	EXPECT_NODE(p.nodes.kind[4], .IDENTIFIER, t)
	CHECK_ID(&p, 4, "b", t)
	EXPECT_NODE(p.nodes.kind[5], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[6], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[7], .IDENTIFIER, t)
	CHECK_ID(&p, 7, "c", t)
	EXPECT_NODE(p.nodes.kind[8], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[9], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[10], .IDENTIFIER, t)
	CHECK_ID(&p, 10, "d", t)
	EXPECT_NODE(p.nodes.kind[11], .LITERAL, t)
	EXPECT_NODE(p.nodes.kind[12], .BINARY, t)
	EXPECT_NODE(p.nodes.kind[13], .IDENTIFIER, t)
	CHECK_ID(&p, 13, "print", t)
	EXPECT_NODE(p.nodes.kind[14], .UNARY, t)
	EXPECT_NODE(p.nodes.kind[15], .IDENTIFIER, t)
	CHECK_ID(&p, 15, "a", t)
	EXPECT_NODE(p.nodes.kind[16], .CALL, t)
}

@(test)
test_logic :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
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
	local l = 1 ^ 2
	`


	p := NEW_PARSER(input, v)
	nodeid, errr := p->PARSE_CHUNK()
	if errr != nil {
		log.errorf("Error parsing chunk %v", errr)
		testing.fail(t)
	}

	DUMP_AST(&p)
}
@(test)
test_bitwise :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)

	input := `
	local a = 1 << 2 
	local b = 1 >> 2
	local c = 1 & 2
	local d = 1 | 2
	local e = 1 ~ 2
	local g = !1
	`


	p := NEW_PARSER(input, v)
	nodeid, errr := p->PARSE_CHUNK()
	if errr != nil {
		log.errorf("Error parsing chunk %v", errr)
		testing.fail(t)
	}
	DUMP_AST(&p)
}
@(test)
test_array_assignment :: proc(t: ^testing.T) {
	// Not sure about this one.
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)

	input := `
	local a = {1,2,3};
	a[1] = 5;
	`


	p := NEW_PARSER(input, v)
	nodeid, errr := PARSE_CHUNK(&p)
	if errr != nil {
		log.errorf("Error parsing chunk %v", errr)
		testing.fail(t)
	}
	DUMP_AST(&p)
}
@(test)
test_array_access :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)

	input := `
	a[1];
	`


	p := NEW_PARSER(input, v)
	nodeid, errr := PARSE_CHUNK(&p)
	if errr != nil {
		log.errorf("Error parsing chunk %v", errr)
		testing.fail(t)
	}
	DUMP_AST(&p)
}
@(test)
test_string :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)

	input := `
	local a = "Hello World";
	`


	p := NEW_PARSER(input, v)
	nodeid, errr := p->PARSE_CHUNK()
	if errr != nil {
		log.errorf("Error parsing chunk %v", errr)
		testing.fail(t)
	}

	DUMP_AST(&p)
}
@(test)
test_global :: proc(t: ^testing.T) {
	using parser
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)

	input := `
	do
		global a = 1;
		return a;
	end
	`


	p := NEW_PARSER(input, v)
	nodeid, errr := p->PARSE_CHUNK()
	if errr != nil {
		log.errorf("Error parsing chunk %v", errr)
		testing.fail(t)
	}

	DUMP_AST(&p)
}

