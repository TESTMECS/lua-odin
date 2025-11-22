package ouau
import "core:fmt"
import "core:math"
import "core:slice"
import "core:strings"
/*
*	 ./eval.odin
*	 Copyright(C) 2025 TESTMEE
*	 Defines the interpreter functions for Ouau.
*	 <@Frame, @Environment, @Interpreter| Frame manages the call stack for the current environment in the Interpreter.>
*/
Frame :: struct {
	env:         ^Environment,
	return_addr: NODEID,
	result:      Value,
}
Interpreter :: struct {
	globals:    map[string]Value,
	current:    ^Environment,
	nodes:      ^NODES,
	call_stack: [dynamic]^Frame,
}
@(require_results)
NEW_INTERPRETER :: proc(nodes: ^NODES, allocator := context.allocator) -> ^Interpreter {
	i := new(Interpreter, allocator)
	i.nodes = nodes
	i.globals = make(map[string]Value, allocator)
	i.current = NEW_ENVIRONMENT(nil, allocator)
	i.call_stack = make([dynamic]^Frame, allocator)
	INIT_BUILTINS(i)
	return i
}
@(private = "file")
INIT_BUILTINS :: proc(interpreter: ^Interpreter) {
	print_fn := new(Closure)
	print_fn.is_native = true
	print_fn.native_proc = BUILTIN_PRINT
	interpreter.globals["print"] = print_fn
}
@(private = "file")
BUILTIN_PRINT :: proc(args: []Value) -> Value {
	for arg in args {
		fmt.print(arg)
	}
	fmt.println()
	return nil
}
@(require_results)
INTERPRET :: proc(interpreter: ^Interpreter, root: NODEID) -> Value {
	child := interpreter.nodes.first_child[root]
	last_val: Value
	for child != 0 {
		v := EVAL(interpreter, child)
		if ret, ok := v.(^ReturnValue); ok {
			return ret.value
		}
		last_val = v
		child = interpreter.nodes.next_sibling[child]
	}
	return last_val
}
Environment :: struct {
	values: map[string]Value,
	sorted: [dynamic]string,
	dirty:  bool,
	outer:  ^Environment,
}
@(private = "file")
NEW_ENVIRONMENT :: proc(outer: ^Environment, allocator := context.allocator) -> ^Environment {
	env := new(Environment, allocator)
	env.outer = outer
	env.values = make(map[string]Value, allocator)
	return env
}
@(private = "file")
ENV_GET :: proc(env: ^Environment, name: string) -> (Value, bool) {
	my_env := env // assign to local to avoid shadowing.
	for my_env != nil {
		if v, ok := my_env.values[name]; ok {
			return v, true
		}
		my_env = my_env.outer
	}
	return nil, false
}
@(private = "file")
ENV_SET :: proc(env: ^Environment, name: string, v: Value) {
	env.values[name] = v
	env.dirty = true
}
@(private = "file")
ENV_SET_UPWARD :: proc(env: ^Environment, name: string, v: Value) {
	my_env := env // assign to local to avoid shadowing.
	for my_env != nil {
		if _, ok := my_env.values[name]; ok {
			my_env.values[name] = v
			my_env.dirty = true
			return
		}
		my_env = my_env.outer
	}
	env.values[name] = v
	env.dirty = true
}
@(private = "file")
ENV_RESORT :: proc(env: ^Environment) {
	if !env.dirty do return
	env_len := len(env.sorted)
	clear(&env.sorted)
	resize(&env.sorted, env_len)
	for k in env.values {
		append(&env.sorted, k)
	}
	slice.sort_by(env.sorted[:], proc(a, b: string) -> bool {
		return a < b
	})
	env.dirty = false
}
@(private = "file")
EVAL :: proc(i: ^Interpreter, node: NODEID) -> Value {
	kind := i.nodes.kind[node]
	#partial switch kind {
	case .BLOCK:
		return EVAL_BLOCK(i, node)
	case .UBLOCK:
		return EVAL_UBLOCK(i, node)
	case .IF:
		return EVAL_IF(i, node)
	case .WHILE:
		return EVAL_WHILE(i, node)
	case .REPEAT:
		return EVAL_REPEAT(i, node)
	case .DO:
		return EVAL_DO(i, node)
	case .FUNCTION:
		return EVAL_FUNCTION(i, node)
	case .FOR:
		return EVAL_FOR(i, node)
	case .LOCAL:
		return EVAL_LOCAL(i, node)
	case .GLOBAL:
		return EVAL_GLOBAL(i, node)
	case .BREAK:
		return nil
	case .RETURN:
		return EVAL_RETURN(i, node)
	case .CALL:
		return EVAL_CALL(i, node)
	case .UNARY:
		return EVAL_UNARY(i, node)
	case .BINARY:
		return EVAL_BINARY(i, node)
	case .STRING:
		return EVAL_STRING(i, node)
	case .TABLE:
		return EVAL_TABLE(i, node)
	case .ASSIGN:
		return EVAL_ASSIGN(i, node)
	case .IDENTIFIER:
		name := i.nodes.name[node]
		if val, ok := ENV_GET(i.current, name); ok {
			return val
		}
		if val, ok := i.globals[name]; ok {
			return val
		}
		return nil
	case .LITERAL:
		s_val := i.nodes.string_value[node]
		if s_val != "" {
			if s_val == "true" {
				return true
			}
			if s_val == "false" {
				return false
			}
			return nil
		}
		return f64(i.nodes.int_value[node])
	}
	return nil
}
@(private = "file")
EVAL_BLOCK :: proc(i: ^Interpreter, node: NODEID) -> Value {
	child := i.nodes.first_child[node]
	last_result: Value
	for child != 0 {
		v := EVAL(i, child)
		if _, ok := v.(^ReturnValue); ok {
			return v
		}
		last_result = v
		child = i.nodes.next_sibling[child]
	}
	return last_result
}
@(private = "file")
EVAL_UBLOCK :: proc(i: ^Interpreter, node: NODEID) -> Value {
	child := i.nodes.first_child[node]
	block_result := EVAL(i, child)
	if block_result != nil {
		return block_result
	}
	child = i.nodes.next_sibling[child]
	condition := EVAL(i, child)
	return condition
}
@(private = "file")
EVAL_IF :: proc(i: ^Interpreter, node: NODEID) -> Value {
	child := i.nodes.first_child[node]
	cond := EVAL(i, child)
	child = i.nodes.next_sibling[child]
	if IS_TRUTHY(cond) {
		return EVAL(i, child)
	}
	 else {
		child = i.nodes.next_sibling[child]
		for child != 0 {
			// child is the condition, next sibling is the body
			cond := EVAL(i, child)
			body_child := i.nodes.next_sibling[child]
			if IS_TRUTHY(cond) {
				return EVAL(i, body_child)
			}
			child = i.nodes.next_sibling[body_child]
		}
	}
	return nil
}
@(private = "file")
EVAL_WHILE :: proc(i: ^Interpreter, node: NODEID) -> Value {
	child := i.nodes.first_child[node]
	cond_node := child
	body_node := i.nodes.next_sibling[child]

	for IS_TRUTHY(EVAL(i, cond_node)) {
		result := EVAL(i, body_node)
		if result != nil {
			return result // Handle break/return
		}
	}

	return nil
}
@(private = "file")
EVAL_REPEAT :: proc(i: ^Interpreter, node: NODEID) -> Value {
	child := i.nodes.first_child[node]
	ublock_node := child
	for {
		block_result := EVAL(i, ublock_node)
		if block_result != nil {
			return block_result
		}
		condition := EVAL(i, GET_RIGHT_CHILD(i, ublock_node))
		if IS_TRUTHY(condition) {
			break
		}
	}
	return nil
}
@(private = "file")
EVAL_DO :: proc(i: ^Interpreter, node: NODEID) -> Value {
	child := i.nodes.first_child[node]
	return EVAL(i, child)
}
@(private = "file")
EVAL_FUNCTION :: proc(i: ^Interpreter, node: NODEID, allocator := context.allocator) -> Value {
	fn := new(Closure, allocator)
	fn.is_native = false
	fn.params = EXTRACT_PARAMS(i, node)
	fn.body = GET_FUNCTION_BODY(i, node)
	fn.closure = i.current

	name := i.nodes.name[node]
	if name != "" {
		ENV_SET(i.current, name, fn)
		return nil
	}

	return fn
}
@(private = "file")
EVAL_FOR :: proc(i: ^Interpreter, node: NODEID) -> Value {
	var_name := i.nodes.name[node]
	child := i.nodes.first_child[node]
	// Numeric for loop: init, limit, [step], body
	init := EVAL(i, child)
	child = i.nodes.next_sibling[child]
	limit := EVAL(i, child)
	child = i.nodes.next_sibling[child]
	step: Value = 1.0
	// Check if there's a step expression before the body
	if child != 0 && i.nodes.kind[child] != .BLOCK {
		step = EVAL(i, child)
		child = i.nodes.next_sibling[child]
	}
	ENV_SET(i.current, var_name, init)
	for {
		current_val, _ := ENV_GET(i.current, var_name)
		if (step.(f64) > 0 && current_val.(f64) > limit.(f64)) ||
		   (step.(f64) < 0 && current_val.(f64) < limit.(f64)) {
			break
		}
		body_result := EVAL(i, child)
		if _, ok := body_result.(^ReturnValue); ok {
			return body_result
		}
		current_val, _ = ENV_GET(i.current, var_name)
		ENV_SET(i.current, var_name, current_val.(f64) + step.(f64))
	}
	return nil
}
@(private = "file")
EVAL_LOCAL :: proc(i: ^Interpreter, node: NODEID) -> Value {
	child := i.nodes.first_child[node]
	vars: [dynamic]string
	for child != 0 && i.nodes.kind[child] == .IDENTIFIER {
		append(&vars, i.nodes.name[child])
		child = i.nodes.next_sibling[child]
	}
	values: [dynamic]Value
	for child != 0 {
		val := EVAL(i, child)
		append(&values, val)
		child = i.nodes.next_sibling[child]
	}
	last_value: Value
	for name, idx in vars {
		if idx < len(values) {
			ENV_SET(i.current, name, values[idx])
			last_value = values[idx]
		}
		 else {
			ENV_SET(i.current, name, nil)
		}
	}
	return last_value
}
@(private = "file")
EVAL_RETURN :: proc(i: ^Interpreter, node: NODEID) -> Value {
	child := i.nodes.first_child[node]
	val: Value
	if child != 0 {
		val = EVAL(i, child)
	}
	 else {
		val = nil
	}

	ret_val := new(ReturnValue)
	ret_val.value = val
	return ret_val
}
@(private = "file")
EVAL_CALL :: proc(i: ^Interpreter, node: NODEID) -> Value {
	fn_child := GET_FUNCTION_CHILD(i, node)
	fn_val := EVAL(i, fn_child)
	if fn_val == nil {
		return nil
	}

	fn_val_closure, ok := fn_val.(^Closure)
	if !ok {
		return nil
	}

	arg_child := GET_ARGUMENTS_CHILD(i, node)
	args := EVAL_EXPRESSION_LIST(i, arg_child)
	if fn_val_closure.is_native {
		return fn_val_closure.native_proc(args)
	}
	 else {
		return CALL_USER_FUNCTION(i, fn_val_closure, args)
	}
}
@(private = "file")
EVAL_UNARY :: proc(i: ^Interpreter, node: NODEID) -> Value {
	child := i.nodes.first_child[node]
	operand := EVAL(i, child)
	op := i.nodes.token[node]
	#partial switch op {
	case .MINUS:
		return -operand.(f64)
	case .NOT:
		return !IS_TRUTHY(operand)
	case .POUND:
		switch val in operand {
		case string:
			return f64(len(val))
		case ^Table:
			// For tables, return the length of the array part
			// This is a simplified version - in real Lua it's more complex
			// We'll count consecutive integer keys starting from 1
			length: i64 = 0
			for {
				key_tag := KeyTag {
					kind = 1,
					i    = length + 1,
				}
				if _, exists := val.data[key_tag]; exists {
					length += 1
				}
				 else {
					break
				}
			}
			return f64(length)
		case bool, f64, rawptr, ^Closure, ^ReturnValue:
			return nil
		case:
			return nil
		}
	case:
		return nil
	}
}
@(private = "file")
EVAL_BINARY :: proc(i: ^Interpreter, node: NODEID) -> Value {
	left := EVAL(i, GET_LEFT_CHILD(i, node))
	right := EVAL(i, GET_RIGHT_CHILD(i, node))
	op := i.nodes.token[node]
	#partial switch op {
	case .ASSIGN:
		return EVAL_ASSIGN(i, node)
	case .EQ:
		return EVAL_COMPARE(left, right, .EQ)
	case .NE:
		return EVAL_COMPARE(left, right, .NE)
	case .LT:
		return EVAL_COMPARE(left, right, .LT)
	case .LE:
		return EVAL_COMPARE(left, right, .LE)
	case .GT:
		return EVAL_COMPARE(left, right, .GT)
	case .GE:
		return EVAL_COMPARE(left, right, .GE)
	case .OR:
		return IS_TRUTHY(left) || IS_TRUTHY(right)
	case .ANDAND:
		return IS_TRUTHY(left) && IS_TRUTHY(right)
	case .OROR:
		return IS_TRUTHY(left) || IS_TRUTHY(right)
	case .PLUS:
		return EVAL_PLUS(left, right)
	case .MINUS:
		return EVAL_MINUS(left, right)
	case .MUL:
		return EVAL_MUL(left, right)
	case .DIV:
		return EVAL_DIV(left, right)
	case .MOD:
		return EVAL_MOD(left, right)
	case .POW:
		return math.pow_f64(left.(f64), right.(f64))
	case .BXOR:
		return EVAL_BITWISE(left, right, .BXOR)
	case .BAND:
		return EVAL_BITWISE(left, right, .BAND)
	case .BOR:
		return EVAL_BITWISE(left, right, .BOR)
	case .SHL:
		return EVAL_BITWISE(left, right, .SHL)
	case .SHR:
		return EVAL_BITWISE(left, right, .SHR)
	case .DOT:
		table_val := left
		table, ok := table_val.(^Table)
		if !ok || table == nil {
			return nil
		}
		right_node_id := GET_RIGHT_CHILD(i, node)
		key_name := i.nodes.name[right_node_id]
		key_tag := VALUE_TO_KEY_TAG(key_name)
		if val, found := table.data[key_tag]; found {
			return val
		}
		return nil
	case .BOPEN:
		table_val := left
		table, ok := table_val.(^Table)
		if !ok || table == nil {
			return nil
		}
		right_node_id := GET_RIGHT_CHILD(i, node)
		key_val := EVAL(i, right_node_id)
		key_tag := VALUE_TO_KEY_TAG(key_val)
		if val, found := table.data[key_tag]; found {
			return val
		}
		return nil
	}
	return nil
}
@(private = "file")
EVAL_STRING :: proc(i: ^Interpreter, node: NODEID) -> Value {
	return i.nodes.string_value[node]
}
@(private = "file")
EVAL_TABLE :: proc(i: ^Interpreter, node: NODEID) -> Value {
	table := new(Table)
	table.data = make(map[KeyTag]Value)

	child := i.nodes.first_child[node]
	for child != 0 {
		if i.nodes.kind[child] == .BINARY {
			key := EVAL(i, GET_LEFT_CHILD(i, child))
			value := EVAL(i, GET_RIGHT_CHILD(i, child))
			key_tag := VALUE_TO_KEY_TAG(key)
			table.data[key_tag] = value
		}
		 else {
			// Array-style value (implicit integer key)
			key_tag := KeyTag {
				kind = 1,
				i    = cast(i64)len(table.data) + 1,
			}
			value := EVAL(i, child)
			table.data[key_tag] = value
		}
		child = i.nodes.next_sibling[child]
	}

	return table
}
@(private = "file")
GET_FUNCTION_CHILD :: proc(i: ^Interpreter, node: NODEID) -> NODEID {
	return i.nodes.first_child[node]
}
@(private = "file")
GET_ARGUMENTS_CHILD :: proc(i: ^Interpreter, node: NODEID) -> NODEID {
	fn_child := i.nodes.first_child[node]
	arg_child := i.nodes.next_sibling[fn_child]
	return arg_child
}
@(private = "file")
GET_LEFT_CHILD :: proc(i: ^Interpreter, node: NODEID) -> NODEID {
	return i.nodes.first_child[node]
}
@(private = "file")
GET_RIGHT_CHILD :: proc(i: ^Interpreter, node: NODEID) -> NODEID {
	left := i.nodes.first_child[node]
	return i.nodes.next_sibling[left]
}
@(private = "file")
EXTRACT_PARAMS :: proc(i: ^Interpreter, node: NODEID, allocator := context.allocator) -> []string {
	params := make([dynamic]string, allocator)

	child := i.nodes.first_child[node]

	// Collect all consecutive IDENTIFIER nodes as parameters
	for child != 0 && i.nodes.kind[child] == .IDENTIFIER {
		append(&params, i.nodes.name[child])
		child = i.nodes.next_sibling[child]
	}

	return params[:]
}
@(private = "file")
GET_FUNCTION_BODY :: proc(i: ^Interpreter, node: NODEID) -> NODEID {
	child := i.nodes.first_child[node]
	// Skip parameters
	for child != 0 && i.nodes.kind[child] == .IDENTIFIER {
		child = i.nodes.next_sibling[child]
	}
	// The next child should be the block
	return child
}
@(private = "file")
IS_TRUTHY :: proc(PValue: Value) -> bool {
	switch v in PValue {
	case bool:
		return v
	case f64:
		return v != 0.0
	case string:
		return len(v) > 0
	case rawptr:
		return v != nil
	case (^Table):
		return v.data != nil
	case (^Closure):
		return v.body != 0
	case ^ReturnValue:
		return true
	}
	return false
}
@(private = "file")
CALL_USER_FUNCTION :: proc(i: ^Interpreter, fn: ^Closure, args: []Value) -> Value {
	env := NEW_ENVIRONMENT(fn.closure)
	for param, i in fn.params {
		if i < len(args) {
			ENV_SET(env, param, args[i])
		}
	}
	old_env := i.current
	i.current = env
	result := EVAL(i, fn.body)
	i.current = old_env

	if ret, ok := result.(^ReturnValue); ok {
		return ret.value
	}
	return nil // No explicit return
}
@(private = "file")
EVAL_EXPRESSION_LIST :: proc(i: ^Interpreter, node: NODEID) -> []Value {
	values: [dynamic]Value

	if node == 0 {
		return values[:]
	}

	// Check if this node is a container (like a block) or an actual argument
	if i.nodes.kind[node] == .BLOCK {
		child := i.nodes.first_child[node]
		for child != 0 {
			append(&values, EVAL(i, child))
			child = i.nodes.next_sibling[child]
		}
	}
	 else {
		// This node is the actual argument
		append(&values, EVAL(i, node))
	}

	return values[:]
}
@(private = "file")
EVAL_COMPARE :: proc(left, right: Value, op: Token) -> bool {
	#partial switch op {
	case .EQ:
		switch ty in left {
		case bool:
			return left.(bool) == right.(bool)
		case f64:
			return left.(f64) == right.(f64)
		case string:
			return left.(string) == right.(string)
		case rawptr:
			return left.(rawptr) == right.(rawptr)
		case (^Table):
			return COMPARE_TABLE(left.(^Table), right.(^Table))
		case (^Closure):
			return COMPARE_CLOSURE(left.(^Closure), right.(^Closure))
		case ^ReturnValue:
			return false
		}
	case .NE:
		return !EVAL_COMPARE(left, right, .EQ)
	case .LT:
		#partial switch ty in left {
		case f64:
			return left.(f64) < right.(f64)
		case string:
			return len(left.(string)) < len(right.(string))
		case:
			unimplemented("Less than is not supported for this type.")
		}
	case .LE:
		return EVAL_COMPARE(left, right, .LT) || EVAL_COMPARE(left, right, .EQ)
	case .GT:
		return !EVAL_COMPARE(left, right, .LE)
	case .GE:
		return !EVAL_COMPARE(left, right, .LT)
	case:
		unimplemented("TODO")
	}
	panic("unreachable")
}
@(private = "file")
EVAL_PLUS :: proc(left, right: Value) -> Value {
	if left_str, left_ok := left.(string); left_ok {
		if right_str, right_ok := right.(string); right_ok {
			a := [2]string{left_str, right_str}
			return strings.concatenate(a[:])
		}
		right_str, right_ok := right.(string)
		a := [2]string{left_str, right_str}
		return strings.concatenate(a[:])
	}
	lvalue, ok := left.(f64)
	if !ok {
		return nil
	}
	rvalue, okk := right.(f64)
	if !okk {
		return nil
	}
	return lvalue + rvalue
}
@(private = "file")
EVAL_MINUS :: proc(left, right: Value) -> Value {
	#partial switch ty in left {
	case f64:
		return left.(f64) - right.(f64)
	case:
		return nil
	}
}
@(private = "file")
EVAL_MUL :: proc(left, right: Value) -> Value {
	#partial switch ty in left {
	case f64:
		return left.(f64) * right.(f64)
	case:
		return nil
	}
}
@(private = "file")
EVAL_DIV :: proc(left, right: Value) -> Value {
	#partial switch ty in left {
	case f64:
		return left.(f64) / right.(f64)
	case:
		return nil
	}
}
@(private = "file")
EVAL_MOD :: proc(left, right: Value) -> Value {
	return math.mod_f64(left.(f64), right.(f64))
}
@(private = "file")
EVAL_BITWISE :: proc(left, right: Value, op: Token) -> Value {
	left_int := cast(i64)left.(f64)
	right_int := cast(i64)right.(f64)

	#partial switch op {
	case .SHL:
		return cast(f64)(left_int << uint(right_int))
	case .SHR:
		return cast(f64)(left_int >> uint(right_int))
	case .BAND:
		return cast(f64)(left_int & right_int)
	case .BOR:
		return cast(f64)(left_int | right_int)
	case .BXOR:
		return cast(f64)(left_int ~ right_int)
	}
	return 0.0
}
@(private = "file")
COMPARE_TABLE :: proc(left, right: ^Table) -> bool {
	if left == right {
		return true
	}
	if left == nil || right == nil {
		return false
	}
	if len(left.data) != len(right.data) {
		return false
	}

	// Compare all key-value pairs
	for key, left_val in left.data {
		if right_val, ok := right.data[key]; !ok {
			return false
		}
		 else if !EVAL_COMPARE(left_val, right_val, .EQ) {
			return false
		}
	}

	return true
}
@(private = "file")
COMPARE_CLOSURE :: proc(left, right: ^Closure) -> bool {
	return left == right
}
@(private = "file")
EVAL_ASSIGN :: proc(i: ^Interpreter, node: NODEID) -> Value {
	lvalue := GET_LEFT_CHILD(i, node)
	rvalue := GET_RIGHT_CHILD(i, node)

	lvalue_kind := i.nodes.kind[lvalue]
	#partial switch lvalue_kind {
	case .IDENTIFIER:
		value_to_assign := EVAL(i, rvalue)
		name := i.nodes.name[lvalue]
		env := i.current
		for env != nil {
			if val, ok := ENV_GET(env, name); ok {
				ENV_SET(env, name, value_to_assign)
				return value_to_assign
			}
			env = env.outer
		}
		ENV_SET(env, name, value_to_assign)
		return value_to_assign

	case .BINARY:
		op := i.nodes.token[lvalue]

		if op == .DOT {
			// For dot access, evaluate table and key first, then RHS
			table_expr_node := GET_LEFT_CHILD(i, lvalue)
			table_val := EVAL(i, table_expr_node)
			table, ok := table_val.(^Table)
			if !ok || table == nil {
				return nil
			}
			key_node := GET_RIGHT_CHILD(i, lvalue)
			key_val := EVAL(i, key_node)
			key_tag := VALUE_TO_KEY_TAG(key_val)

			// Now evaluate RHS after we have the table location
			value_to_assign := EVAL(i, rvalue)
			table.data[key_tag] = value_to_assign
			return value_to_assign

		}
		 else if op == .BOPEN {
			table_expr_node := GET_LEFT_CHILD(i, lvalue)
			table_val := EVAL(i, table_expr_node)
			table, ok := table_val.(^Table)
			if !ok || table == nil {
				return nil
			}
			key_node := GET_RIGHT_CHILD(i, lvalue)
			key_val := EVAL(i, key_node)
			key_tag := VALUE_TO_KEY_TAG(key_val)
			// Now evaluate RHS after we have the table location
			value_to_assign := EVAL(i, rvalue)
			table.data[key_tag] = value_to_assign
			return value_to_assign
		}
	case:
	}
	return nil
}
@(private = "file")
EVAL_GLOBAL :: proc(i: ^Interpreter, node: NODEID) -> Value {
	child := i.nodes.first_child[node]
	vars: [dynamic]string
	for child != 0 && i.nodes.kind[child] == .IDENTIFIER {
		append(&vars, i.nodes.name[child])
		child = i.nodes.next_sibling[child]
	}
	values: [dynamic]Value
	for child != 0 {
		val := EVAL(i, child)
		append(&values, val)
		child = i.nodes.next_sibling[child]
	}
	last_value: Value
	for name, idx in vars {
		if idx < len(values) {
			i.globals[name] = values[idx]
			last_value = values[idx]
		}
		 else {
			i.globals[name] = nil
		}
	}
	return last_value
}

