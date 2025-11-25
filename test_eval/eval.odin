package test_eval
import i "../"
import "core:log"
import "core:mem/virtual"
import "core:testing"
@(test)
test_eval_block :: proc(t: ^testing.T) {
	using i
	v: virtual.Arena
	err := virtual.arena_init_growing(&v)
	ensure(err == nil, "Error initializing arena")
	defer virtual.arena_destroy(&v)
	input := `
	do 
	 local a = 1;
		return a;
	end`
	p, p_err := NEW_PARSER(input, &v)
	testing.expectf(t, p_err == nil, "Error creating Parser::(%v)", p_err)
	root, chunk_err := CHUNK(&p)
	testing.expectf(t, chunk_err == nil, "Error parsing chunk::(%v)", chunk_err)
	i := NEW_INTERPRETER(&p.nodes, &v)
	val := INTERPRET(&i, root)
	log.infof("Return Val::(%v)", val)
	if val == nil || val.(f64) != 1 {
		testing.fail(t)
	}
}
@(test)
test_function :: proc(t: ^testing.T) {
	using i
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
	root, chunk_err := CHUNK(&p)
	testing.expectf(t, chunk_err != nil, "Error parsing chunk::(%v)", chunk_err)
	i := NEW_INTERPRETER(&p.nodes, &v)
	val := INTERPRET(&i, root)
	if val == nil || val.(f64) != 3 {
		testing.fail(t)
	}
}
@(test)
test_eval_table :: proc(t: ^testing.T) {
	using i
	v: virtual.Arena
	err := virtual.arena_init_growing(&v)
	ensure(err == nil, "Error initializing arena")
	defer virtual.arena_destroy(&v)

	input := `
	local a = {
		"b" = 1,
		"c" = 2,
	}
	return a["c"];`
	p, p_err := NEW_PARSER(input, &v)
	testing.expectf(t, p_err == nil, "Error creating Parser::(%v)", p_err)
	root, chunk_err := CHUNK(&p)
	testing.expectf(t, chunk_err != nil, "Error parsing chunk::(%v)", chunk_err)
	i := NEW_INTERPRETER(&p.nodes, &v)
	val := INTERPRET(&i, root)
	if val == nil || val.(f64) != 2 {
		testing.fail(t)
	}
}
@(test)
test_eval_array :: proc(t: ^testing.T) {
	using i
	v: virtual.Arena
	err := virtual.arena_init_growing(&v)
	ensure(err == nil, "Error initializing arena")
	defer virtual.arena_destroy(&v)
	input := `
	local a = {
		1,
		2,
	}
	return a[1];`
	p, p_err := NEW_PARSER(input, &v)
	testing.expectf(t, p_err == nil, "Error creating Parser::(%v)", p_err)
	root, chunk_err := CHUNK(&p)
	testing.expectf(t, chunk_err != nil, "Error parsing chunk::(%v)", chunk_err)
	i := NEW_INTERPRETER(&p.nodes, &v)
	val := INTERPRET(&i, root)
	if val == nil || val.(f64) != 1 {
		testing.fail(t)
	}
}
@(test)
test_ifelse :: proc(t: ^testing.T) {
	using i
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
	root, chunk_err := CHUNK(&p)
	testing.expectf(t, chunk_err != nil, "Error parsing chunk::(%v)", chunk_err)
	i := NEW_INTERPRETER(&p.nodes, &v)
	val := INTERPRET(&i, root)
	if val == nil || val.(f64) != 3 {
		testing.fail(t)
	}
}
@(test)
test_while :: proc(t: ^testing.T) {
	using i
	v: virtual.Arena
	err := virtual.arena_init_growing(&v)
	ensure(err == nil, "Error initializing arena")
	defer virtual.arena_destroy(&v)

	input := `
	local a = 0;
	while a < 10 do
		a = a + 1;
	end
	return a;`
	p, p_err := NEW_PARSER(input, &v)
	testing.expectf(t, p_err == nil, "Error creating Parser::(%v)", p_err)
	root, chunk_err := CHUNK(&p)
	testing.expectf(t, chunk_err != nil, "Error parsing chunk::(%v)", chunk_err)
	i := NEW_INTERPRETER(&p.nodes, &v)
	val := INTERPRET(&i, root)
	if val == nil || val.(f64) != 10 {
		testing.fail(t)
	}
}
@(test)
test_for :: proc(t: ^testing.T) {
	using i
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
	root, chunk_err := CHUNK(&p)
	testing.expectf(t, chunk_err != nil, "Error parsing chunk::(%v)", chunk_err)
	DUMP_AST(&p)
	i := NEW_INTERPRETER(&p.nodes, &v)
	val := INTERPRET(&i, root)
	if val == nil || val.(f64) != 10 {
		testing.fail(t)
	}
}
@(test)
test_for_list :: proc(t: ^testing.T) {
	using i
	v: virtual.Arena
	err := virtual.arena_init_growing(&v)
	ensure(err == nil, "Error initializing arena")
	defer virtual.arena_destroy(&v)
	input := `
	local a = {1,2,3};
	for i = 1, #a do
		a[i] = a[i] + 1;
	end
	return a;`
	p, p_err := NEW_PARSER(input, &v)
	root, chunk_err := CHUNK(&p)
	i := NEW_INTERPRETER(&p.nodes, &v)
	val := INTERPRET(&i, root)
	tbl, ok := val.(^Table)
	if val == nil || !ok {
		testing.fail(t)
	}
}
@(test)
test_global :: proc(t: ^testing.T) {
	using i
	v: virtual.Arena
	err := virtual.arena_init_growing(&v)
	ensure(err == nil, "Error initializing arena")
	defer virtual.arena_destroy(&v)
	input := `
	global a = 1;
	return a;`
	p, p_err := NEW_PARSER(input, &v)
	testing.expectf(t, p_err == nil, "Error creating Parser::(%v)", p_err)
	root, chunk_err := CHUNK(&p)
	testing.expectf(t, chunk_err != nil, "Error parsing chunk::(%v)", chunk_err)
	DUMP_AST(&p)
	i := NEW_INTERPRETER(&p.nodes, &v)
	val := INTERPRET(&i, root)
	if val == nil || val.(f64) != 1 {
		testing.fail(t)
	}
}

