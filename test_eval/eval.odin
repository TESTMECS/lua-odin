package test_eval
import i "../"
import pt "../test_parser"
import "core:log"
import "core:mem/virtual"
import "core:testing"
@(test)
test_eval :: proc(t: ^testing.T) {
	using i
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
	root := PARSE_CHUNK(&p)
	i := NEW_INTERPRETER(&p.nodes, varena)
	val := INTERPRET(i, root)
	if val == nil || val.(f64) != 1 {
		testing.fail(t)
	}
}
@(test)
test_eval2 :: proc(t: ^testing.T) {
	using i
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
	root := PARSE_CHUNK(&p)
	i := NEW_INTERPRETER(&p.nodes, varena)
	val := INTERPRET(i, root)
	if val == nil || val.(f64) != 3 {
		testing.fail(t)
	}
}

@(test)
test_eval_table :: proc(t: ^testing.T) {
	using i
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)

	input := `
	local a = {
		"b" = 1,
		"c" = 2,
	}
	return a["c"];
	`


	p := NEW_PARSER(input, varena)
	root := PARSE_CHUNK(&p)
	i := NEW_INTERPRETER(&p.nodes, varena)
	val := INTERPRET(i, root)
	if val == nil || val.(f64) != 2 {
		testing.fail(t)
	}
}
@(test)
test_eval_array :: proc(t: ^testing.T) {
	using i
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)

	input := `
	local a = {
		1,
		2,
	}
	return a[1];
	`


	p := NEW_PARSER(input, varena)
	root := PARSE_CHUNK(&p)
	i := NEW_INTERPRETER(&p.nodes, varena)
	val := INTERPRET(i, root)
	if val == nil || val.(f64) != 1 {
		testing.fail(t)
	}
}
@(test)
test_ifelse :: proc(t: ^testing.T) {
	using i
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)

	input := `
	if false then
		return 1;
	elseif true then
		return 3;
	else
		return 2;
	end`


	p := NEW_PARSER(input, varena)
	root := PARSE_CHUNK(&p)
	i := NEW_INTERPRETER(&p.nodes, varena)
	val := INTERPRET(i, root)
	if val == nil || val.(f64) != 3 {
		testing.fail(t)
	}
}
@(test)
test_while :: proc(t: ^testing.T) {
	using i
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)

	input := `
	local a = 0;
	while a < 10 do
		a = a + 1;
	end
	return a;`


	p := NEW_PARSER(input, varena)
	root := PARSE_CHUNK(&p)
	i := NEW_INTERPRETER(&p.nodes, varena)
	val := INTERPRET(i, root)
	if val == nil || val.(f64) != 10 {
		testing.fail(t)
	}
}
@(test)
test_for :: proc(t: ^testing.T) {
	using i
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)

	input := `
	local a = 0;
	for i = 0, 9 do
		a = i + 1;
	end
	return a;`


	p := NEW_PARSER(input, varena)
	root := PARSE_CHUNK(&p)
	pt.DUMP_AST(&p)
	i := NEW_INTERPRETER(&p.nodes, varena)
	val := INTERPRET(i, root)
	if val == nil || val.(f64) != 10 {
		testing.fail(t)
	}
}
@(test)
test_for_list :: proc(t: ^testing.T) {
	using i
	v := new(virtual.Arena, context.allocator)
	err := virtual.arena_init_growing(v)
	ensure(err == nil)
	defer virtual.arena_destroy(v)
	defer free_all(context.allocator)
	varena := virtual.arena_allocator(v)

	input := `
	local a = {1,2,3};
	for i = 1, #a do
		a[i] = a[i] + 1;
	end
	return a;
	`


	p := NEW_PARSER(input, varena)
	root := PARSE_CHUNK(&p)
	i := NEW_INTERPRETER(&p.nodes, varena)
	val := INTERPRET(i, root)
	tbl, ok := val.(^Table)
	if val == nil || !ok {
		testing.fail(t)
	}
}

