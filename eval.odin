package ouau
import "core:math"
import "core:mem/virtual"
import "core:strings"
/*
*	 ./eval.odin
*	 Copyright(C) 2025 TESTMEE
*	 Defines the interpreter functions for Ouau.
*/
@(require_results)
INTERPRET :: proc(i: ^Interpreter, root: NODEID) -> Value {
	child := i.nodes.first_child[root]
	last_val: Value
	for child != 0 {
		v := i->EVAL(child)
		if ret, ok := v.(^ReturnValue); ok {
			return ret.value
		}
		last_val = v
		child = i.nodes.next_sibling[child]
	}
	return last_val
}
@(private = "file")
EVAL :: proc(i: ^Interpreter, node: NODEID) -> Value {
	my_alloc := virtual.arena_allocator(i.arena)
	kind := i.nodes.kind[node]
	// TODO: Finish partial
	#partial switch kind {
	case .BLOCK:
		child := i.nodes.first_child[node]
		last_result: Value
		for child != 0 {
			v := i->EVAL(child)
			if _, ok := v.(^ReturnValue); ok {
				return v
			}
			last_result = v
			child = i.nodes.next_sibling[child]
		}
		return last_result
	case .UBLOCK:
		child := i->GET_LEFT_CHILD(node)
		block_result := i->EVAL(child)
		if block_result != nil {
			return block_result
		}
		child = i.nodes.next_sibling[child]
		condition := i->EVAL(child)
		return condition
	case .IF:
		child := i.nodes.first_child[node]
		cond := i->EVAL(child)
		child = i.nodes.next_sibling[child]
		if IS_TRUTHY(cond) {
			return i->EVAL(child)
		} else {
			child = i.nodes.next_sibling[child]
			for child != 0 {
				// child is the condition, next sibling is the body
				cond := i->EVAL(child)
				body_child := i.nodes.next_sibling[child]
				if IS_TRUTHY(cond) {
					return i->EVAL(body_child)
				}
				child = i.nodes.next_sibling[body_child]
			}
		}
		return nil
	case .WHILE:
		child := i.nodes.first_child[node]
		cond_node := child
		body_node := i.nodes.next_sibling[child]
		for IS_TRUTHY(i->EVAL(cond_node)) {
			result := i->EVAL(body_node)
			if _, ok := result.(^BreakValue); ok {
				return nil
			}
		}
		return nil
	case .REPEAT:
		child := i.nodes.first_child[node]
		ublock_node := child
		for {
			block_result := i->EVAL(ublock_node)
			if block_result != nil {
				return block_result
			}
			condition := i->EVAL(i->GET_RIGHT_CHILD(ublock_node))
			if IS_TRUTHY(condition) { break }
		}
		return nil
	case .DO:
		child := i.nodes.first_child[node]
		return i->EVAL(child)
	case .FOR:
		var_name := i.nodes.name[node]
		child := i.nodes.first_child[node]
		// Numeric for loop: init, limit, [step], body
		init := i->EVAL(child)
		child = i.nodes.next_sibling[child]
		limit := i->EVAL(child)
		child = i.nodes.next_sibling[child]
		step: Value = 1.0
		// Check if there's a step expression before the body
		if child != 0 && i.nodes.kind[child] != .BLOCK {
			step = i->EVAL(child)
			child = i.nodes.next_sibling[child]
		}
		ENV_SET(i.current, var_name, init)
		for {
			current_val, _ := ENV_GET(i.current, var_name)
			if (step.(f64) > 0 && current_val.(f64) > limit.(f64)) ||
			   (step.(f64) < 0 && current_val.(f64) < limit.(f64)) {
				break
			}
			body_result := i->EVAL(child)
			if _, ok := body_result.(^ReturnValue); ok {
				return body_result
			}
			current_val, _ = ENV_GET(i.current, var_name)
			ENV_SET(i.current, var_name, current_val.(f64) + step.(f64))
		}
		return nil
	case .LOCAL:
		child := i.nodes.first_child[node]
		vars := make([dynamic]string, my_alloc)
		for child != 0 && i.nodes.kind[child] == .IDENTIFIER {
			append(&vars, i.nodes.name[child])
			child = i.nodes.next_sibling[child]
		}
		values := make([dynamic]Value, my_alloc)
		for child != 0 {
			val := i->EVAL(child)
			append(&values, val)
			child = i.nodes.next_sibling[child]
		}
		last_value: Value
		for name, idx in vars {
			if idx < len(values) {
				ENV_SET(i.current, name, values[idx])
				last_value = values[idx]
			} else {
				ENV_SET(i.current, name, nil)
			}
		}
		return last_value

	case .BREAK:
		break_val := new(BreakValue, my_alloc)
		return break_val
	case .RETURN:
		child := i.nodes.first_child[node]
		val: Value
		if child != 0 {
			val = i->EVAL(child)
		} else {
			val = nil
		}
		ret_val := new(ReturnValue, my_alloc)
		ret_val.value = val
		return ret_val
	case .CALL:
		fn_child := i->GET_LEFT_CHILD(node)
		fn_val := i->EVAL(fn_child)
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
		} else {
			return CALL_USER_FUNCTION(i, fn_val_closure, args)
		}
	case .UNARY:
		child := i.nodes.first_child[node]
		operand := i->EVAL(child)
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
					} else {
						break
					}
				}
				return f64(length)
			case bool, f64, rawptr, ^Closure, ^ReturnValue, ^BreakValue:
				return nil
			case:
				return nil
			}
		case:
			return nil
		}
	case .BINARY:
		left := i->EVAL(i->GET_LEFT_CHILD(node))
		right := i->EVAL(i->GET_RIGHT_CHILD(node))
		op := i.nodes.token[node]
		#partial switch op {
		case .ASSIGN:
			return i->ASSIGN(node)
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
			return left.(f64) - right.(f64)
		case .MUL:
			return left.(f64) * right.(f64)
		case .DIV:
			return left.(f64) / right.(f64)
		case .MOD:
			return math.mod_f64(left.(f64), right.(f64))
		case .POW:
			return math.pow_f64(left.(f64), right.(f64))
		case .BXOR:
			left_int := cast(i64)left.(f64)
			right_int := cast(i64)right.(f64)
			return cast(f64)(left_int ~ right_int)
		case .BAND:
			left_int := cast(i64)left.(f64)
			right_int := cast(i64)right.(f64)
			return cast(f64)(left_int & right_int)
		case .BOR:
			left_int := cast(i64)left.(f64)
			right_int := cast(i64)right.(f64)
			return cast(f64)(left_int | right_int)
		case .SHL:
			left_int := cast(i64)left.(f64)
			right_int := cast(i64)right.(f64)
			return cast(f64)(left_int << uint(right_int))
		case .SHR:
			left_int := cast(i64)left.(f64)
			right_int := cast(i64)right.(f64)
			return cast(f64)(left_int >> uint(right_int))
		case .DOT:
			table_val := left
			table, ok := table_val.(^Table)
			if !ok || table == nil {
				return nil
			}
			right_node_id := i->GET_RIGHT_CHILD(node)
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
			right_node_id := i->GET_RIGHT_CHILD(node)
			key_val := i->EVAL(right_node_id)
			key_tag := VALUE_TO_KEY_TAG(key_val)
			if val, found := table.data[key_tag]; found {
				return val
			}
			return nil
		}
		return nil

	case .TABLE:
		table := new(Table, my_alloc)
		table.data = make(map[KeyTag]Value, my_alloc)
		child := i.nodes.first_child[node]
		for child != 0 {
			if i.nodes.kind[child] == .BINARY {
				key := i->EVAL(i->GET_LEFT_CHILD(child))
				value := i->EVAL(i->GET_RIGHT_CHILD(child))
				key_tag := VALUE_TO_KEY_TAG(key)
				table.data[key_tag] = value
			} else {
				// Array-style value (implicit integer key)
				key_tag := KeyTag {
					kind = 1,
					i    = cast(i64)len(table.data) + 1,
				}
				value := i->EVAL(child)
				table.data[key_tag] = value
			}
			child = i.nodes.next_sibling[child]
		}
		return table
	case .GLOBAL:
		child := i.nodes.first_child[node]
		vars := make([dynamic]string, my_alloc)
		for child != 0 && i.nodes.kind[child] == .IDENTIFIER {
			append(&vars, i.nodes.name[child])
			child = i.nodes.next_sibling[child]
		}
		values := make([dynamic]Value, my_alloc)
		for child != 0 {
			val := i->EVAL(child)
			append(&values, val)
			child = i.nodes.next_sibling[child]
		}
		last_value: Value
		for name, idx in vars {
			if idx < len(values) {
				i.globals[name] = values[idx]
				last_value = values[idx]
			} else {
				i.globals[name] = nil
			}
		}
		return last_value
	case .STRING:
		return i.nodes.string_value[node]
	case .ASSIGN:
		return i->ASSIGN(node)
	case .FUNCTION:
		return EVAL_FUNCTION(i, node)
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
EVAL_FUNCTION :: proc(i: ^Interpreter, node: NODEID) -> Value {
	my_alloc := virtual.arena_allocator(i.arena)
	fn := new(Closure, my_alloc)
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
GET_LEFT_CHILD :: proc(i: ^Interpreter, node: NODEID) -> NODEID {
	return i.nodes.first_child[node]
}
@(private = "file")
GET_ARGUMENTS_CHILD :: proc(i: ^Interpreter, node: NODEID) -> NODEID {
	fn_child := i.nodes.first_child[node]
	arg_child := i.nodes.next_sibling[fn_child]
	return arg_child
}
@(private = "file")
GET_RIGHT_CHILD :: proc(i: ^Interpreter, node: NODEID) -> NODEID {
	left := i.nodes.first_child[node]
	return i.nodes.next_sibling[left]
}
@(private = "file")
EXTRACT_PARAMS :: proc(i: ^Interpreter, node: NODEID) -> []string {
	my_alloc := virtual.arena_allocator(i.arena)
	params := make([dynamic]string, my_alloc)
	child := i.nodes.first_child[node]
	for child != 0 && i.nodes.kind[child] == .IDENTIFIER {
		append(&params, i.nodes.name[child])
		child = i.nodes.next_sibling[child]
	}
	return params[:]
}
@(private = "file")
GET_FUNCTION_BODY :: proc(i: ^Interpreter, node: NODEID) -> NODEID {
	child := i.nodes.first_child[node]
	for child != 0 && i.nodes.kind[child] == .IDENTIFIER {
		child = i.nodes.next_sibling[child]
	}
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
	case ^BreakValue:
		return false
	}
	return false
}
@(private = "file")
CALL_USER_FUNCTION :: proc(i: ^Interpreter, fn: ^Closure, args: []Value) -> Value {
	env := NEW_ENVIRONMENT(fn.closure, i.arena)
	for param, i in fn.params {
		if i < len(args) {
			ENV_SET(env, param, args[i])
		}
	}
	old_env := i.current
	i.current = env
	result := i->EVAL(fn.body)
	i.current = old_env

	if ret, ok := result.(^ReturnValue); ok {
		return ret.value
	}
	return nil // No explicit return
}
@(private = "file")
EVAL_EXPRESSION_LIST :: proc(i: ^Interpreter, node: NODEID) -> []Value {
	my_alloc := virtual.arena_allocator(i.arena)
	values := make([dynamic]Value, my_alloc)
	if node == 0 {
		return values[:]
	}
	// Check if this node is a container (like a block) or an actual argument
	if i.nodes.kind[node] == .BLOCK {
		child := i.nodes.first_child[node]
		for child != 0 {
			append(&values, i->EVAL(child))
			child = i.nodes.next_sibling[child]
		}
	} else {
		// This node is the first argument, iterate through all siblings
		child := node
		for child != 0 {
			append(&values, i->EVAL(child))
			child = i.nodes.next_sibling[child]
		}
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
			return left.(^Closure) == right.(^Closure)
		case ^ReturnValue:
			return false
		case ^BreakValue:
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
	unreachable()
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
		} else if !EVAL_COMPARE(left_val, right_val, .EQ) {
			return false
		}
	}
	return true
}
@(private = "file")
ASSIGN :: proc(i: ^Interpreter, node: NODEID) -> Value {
	lvalue := i->GET_LEFT_CHILD(node)
	rvalue := i->GET_RIGHT_CHILD(node)

	lvalue_kind := i.nodes.kind[lvalue]
	#partial switch lvalue_kind {
	case .IDENTIFIER:
		value_to_assign := i->EVAL(rvalue)
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
			table_expr_node := i->GET_LEFT_CHILD(lvalue)
			table_val := i->EVAL(table_expr_node)
			table, ok := table_val.(^Table)
			if !ok || table == nil {
				return nil
			}
			key_node := i->GET_RIGHT_CHILD(lvalue)
			key_val := i->EVAL(key_node)
			key_tag := VALUE_TO_KEY_TAG(key_val)

			// Now evaluate RHS after we have the table location
			value_to_assign := i->EVAL(rvalue)
			table.data[key_tag] = value_to_assign
			return value_to_assign

		} else if op == .BOPEN {
			table_expr_node := i->GET_LEFT_CHILD(lvalue)
			table_val := i->EVAL(table_expr_node)
			table, ok := table_val.(^Table)
			if !ok || table == nil {
				return nil
			}
			key_node := i->GET_RIGHT_CHILD(lvalue)
			key_val := i->EVAL(key_node)
			key_tag := VALUE_TO_KEY_TAG(key_val)
			// Now evaluate RHS after we have the table location
			value_to_assign := i->EVAL(rvalue)
			table.data[key_tag] = value_to_assign
			return value_to_assign
		}
	case:
	}
	return nil
}
@(rodata)
INTERPRETER_VTABLE := InterpreterVTable {
	EVAL            = EVAL,
	ASSIGN          = ASSIGN,
	GET_LEFT_CHILD  = GET_LEFT_CHILD,
	GET_RIGHT_CHILD = GET_RIGHT_CHILD,
}

