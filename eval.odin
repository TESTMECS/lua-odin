package ouau
import "core:fmt"
import "core:math"
import "core:mem/virtual"
import "core:strconv"
import "core:strings"
/*
*	 ./eval.odin
*	 Copyright(C) 2025 TESTMEE
*/
InterpreterVTable :: struct {
	INTERPRET:   proc(i: ^Interpreter, root: NODEID) -> (result: Value),
	EVAL:        proc(i: ^Interpreter, node: NODEID) -> Value,
	ASSIGN:      proc(i: ^Interpreter, node: NODEID) -> Value,
	GET_CHILD:   proc(i: ^Interpreter, node: NODEID) -> NODEID,
	GET_GCHILD:  proc(i: ^Interpreter, node: NODEID) -> NODEID,
	GET_SIBLING: proc(i: ^Interpreter, node: NODEID) -> NODEID,
	EVAL_ERROR:  proc(i: ^Interpreter, msg: string) -> ^OuauError,
}
@(require_results)
INTERPRET :: proc(i: ^Interpreter, root: NODEID) -> (result: Value) {
	for c := i->GET_CHILD(root); c != 0; c = i->GET_SIBLING(c) {
		v := i->EVAL(c)
		if ret, ok := v.(^ReturnValue); ok {
			return ret.value
		}
		result = v
	}
	return result
}
@(private = "file")
EVAL :: proc(i: ^Interpreter, node: NODEID) -> Value {
	my_alloc := virtual.arena_allocator(i.arena)
	kind := i.nodes.kind[node]
	#partial switch kind {
	case .INVALID:
		return i->EVAL_ERROR("Invalid Node.")
	case .BLOCK:
		last_result: Value
		for c := i->GET_CHILD(node); c != 0; c = i->GET_SIBLING(c) {
			v := i->EVAL(c)
			if _, ok := v.(^ReturnValue); ok { return v }
			last_result = v
		}
		return last_result
	case .UBLOCK:
		c := i->GET_CHILD(node)
		block_result := i->EVAL(c)
		if block_result != nil { return block_result }
		c = i->GET_SIBLING(c)
		condition := i->EVAL(c)
		return condition
	case .IF:
		c := i->GET_CHILD(node)
		cond := i->EVAL(c)
		c = i->GET_SIBLING(c)
		if IS_TRUTHY(cond) {
			return i->EVAL(c)
		} else {
			c = i->GET_SIBLING(c) // Move from if-body to first elseif-condition
			for c != 0 {
				cond_node := c
				body_node := i->GET_SIBLING(cond_node)
				if body_node == 0 { // This is an 'else' block
					return i->EVAL(cond_node)
				}
				
				cond := i->EVAL(cond_node)
				if IS_TRUTHY(cond) {
					return i->EVAL(body_node)
				}
				
				c = i->GET_SIBLING(body_node) // Move to next elseif-condition
			}
		}
		return nil
	case .WHILE:
		cond := i->GET_CHILD(node)
		body := i->GET_SIBLING(cond)
		for IS_TRUTHY(i->EVAL(cond)) {
			result := i->EVAL(body)
			if _, ok := result.(^BreakValue); ok {
				return nil
			}
		}
		return nil
	case .REPEAT:
		c := i->GET_CHILD(node)
		for {
			block_result := i->EVAL(c)
			if block_result != nil { return block_result }
			condition := i->EVAL(i->GET_GCHILD(c))
			if IS_TRUTHY(condition) { break }
		}
		return nil
	case .DO:
		c := i->GET_CHILD(node)
		return i->EVAL(c)
	case .FOR:
		var_name := i.nodes.name[node]
		c := i->GET_CHILD(node)
		init := i->EVAL(c)
		c = i->GET_SIBLING(c)
		limit := i->EVAL(c)
		c = i->GET_SIBLING(c)
		step: Value = 1.0
		if c != 0 && i.nodes.kind[c] != .BLOCK {
			step = i->EVAL(c)
			c = i->GET_SIBLING(c)
		}
		ENV_SET(i.current, var_name, init)
		for {
			current_val, _ := ENV_GET(i.current, var_name)
			if (step.(f64) > 0 && current_val.(f64) > limit.(f64)) ||
			   (step.(f64) < 0 && current_val.(f64) < limit.(f64)) {
				break
			}
			body_result := i->EVAL(c)
			if _, ok := body_result.(^ReturnValue); ok {
				return body_result
			}
			current_val, _ = ENV_GET(i.current, var_name)
			ENV_SET(i.current, var_name, current_val.(f64) + step.(f64))
		}
		return nil
	case .LOCAL:
		c := i->GET_CHILD(node)
		vars := make([dynamic]string, my_alloc)
		for c != 0 && i.nodes.kind[c] == .IDENTIFIER {
			append(&vars, i.nodes.name[c])
			c = i->GET_SIBLING(c)
		}
		values := make([dynamic]Value, my_alloc)
		for c != 0 {
			val := i->EVAL(c)
			append(&values, val)
			c = i->GET_SIBLING(c)
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
		c := i->GET_CHILD(node)
		val: Value
		if c != 0 {
			val = i->EVAL(c)
		} else {
			val = nil
		}
		ret_val := new(ReturnValue, my_alloc)
		ret_val.value = val
		return ret_val
	case .CALL:
		fn_child := i->GET_CHILD(node)
		fn_val := i->EVAL(fn_child)
		if fn_val == nil { return nil }
		fn_val_closure, ok := fn_val.(^Closure)
		if !ok { return nil }
		arg_child := GET_ARGUMENTS_CHILD(i, node)
		args := EVAL_EXPRESSION_LIST(i, arg_child)
		if fn_val_closure.is_native {
			return fn_val_closure.native_proc(args)
		} else {
			return CALL_USER_FUNCTION(i, fn_val_closure, args)
		}
	case .UNARY:
		c := i->GET_CHILD(node)
		operand := i->EVAL(c)
		op := i.nodes.token[node]
		#partial switch op {
		case .MINUS:
			return -operand.(f64)
		case .NOT:
			return !IS_TRUTHY(operand)
		case .BANG:
			return f64(~(i64(operand.(f64))))
		case .POUND:
			switch val in operand {
			case string:
				return f64(len(val))
			case ^Table:
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
			case bool, f64, rawptr, ^Closure, ^ReturnValue, ^BreakValue, ^OuauError:
				return nil
			case:
				return nil
			}
		case:
			return nil
		}
	case .BINARY:
		left := i->EVAL(i->GET_CHILD(node))
		right := i->EVAL(i->GET_GCHILD(node))
		op := i.nodes.token[node]
		#partial switch op {
		case .ASSIGN:
			return i->ASSIGN(node)
		case .EQ:
			return EVAL_COMPARE(left, right, .EQ)
		case .NEQ:
			return EVAL_COMPARE(left, right, .NEQ)
		case .LT:
			return EVAL_COMPARE(left, right, .LT)
		case .LE:
			return EVAL_COMPARE(left, right, .LE)
		case .GT:
			return EVAL_COMPARE(left, right, .GT)
		case .GE:
			return EVAL_COMPARE(left, right, .GE)
		case .OR:
			if IS_TRUTHY(left) {
				return left
			} else {
				right := i->EVAL(i->GET_GCHILD(node))
				return right
			}
		case .AND:
			if !IS_TRUTHY(left) {
				return left
			} else {
				right := i->EVAL(i->GET_GCHILD(node))
				return right
			}
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
			right_node_id := i->GET_GCHILD(node)
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
			right_node_id := i->GET_GCHILD(node)
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
		// TODO: Use Lua type array/hash
		table.data = make(map[KeyTag]Value, my_alloc)
		for c := i->GET_CHILD(node); c != 0; c = i->GET_SIBLING(c) {
			if i.nodes.kind[c] == .BINARY {
				key := i->EVAL(i->GET_CHILD(c))
				value := i->EVAL(i->GET_GCHILD(c))
				key_tag := VALUE_TO_KEY_TAG(key)
				table.data[key_tag] = value
			} else {
				// Normal Array 1,2,3
				key_tag := KeyTag {
					kind = 1,
					i    = cast(i64)len(table.data) + 1,
				}
				value := i->EVAL(c)
				table.data[key_tag] = value
			}
		}
		return table
	case .GLOBAL:
		c := i->GET_CHILD(node)
		vars := make([dynamic]string, my_alloc)
		for c != 0 && i.nodes.kind[c] == .IDENTIFIER {
			append(&vars, i.nodes.name[c])
			c = i->GET_SIBLING(c)
		}
		values := make([dynamic]Value, my_alloc)
		for c != 0 {
			val := i->EVAL(c)
			append(&values, val)
			c = i->GET_SIBLING(c)
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
		literal_string := i.nodes.string_value[node]
		if literal_string != "" && len(literal_string) > 0 {
			value, is_integer, ok := PARSE_NUMBER(literal_string)
			if ok {
				return value
			}
		}
		switch literal_string {
		case "true":
			return true
		case "false":
			return false
		case "nil":
			return nil
		case:
			return f64(i.nodes.int_value[node])
		}
	}
	return nil
}
PARSE_NUMBER :: proc(text: string) -> (value: f64, is_integer: bool, ok: bool) {
	// Check for hexadecimal
	if len(text) >= 2 && text[0] == '0' && (text[1] == 'x' || text[1] == 'X') {
		hex_val, hex_ok := strconv.parse_u64(text[2:], 16)
		return f64(hex_val), true, hex_ok
	}
	// Check if it's an integer (no decimal point, no exponent)
	is_int := true
	for ch in text {
		if ch == '.' || ch == 'e' || ch == 'E' {
			is_int = false
			break
		}
	}
	if is_int {
		// Parse as integer first
		int_val, int_ok := strconv.parse_i64(text, 10)
		if int_ok {
			return f64(int_val), true, true
		}
	}
	// Parse as float
	float_val, float_ok := strconv.parse_f64(text)
	return float_val, false, float_ok
}
@(private = "file")
EVAL_FUNCTION :: proc(i: ^Interpreter, node: NODEID) -> Value {
	my_alloc := virtual.arena_allocator(i.arena)
	fn := new(Closure, my_alloc)
	fn.is_native = false
	fn.params = EXTRACT_PARAMS(i, node)
	fn.has_varargs, fn.varargs_name = GET_VARARGS_INFO(i, node)
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
GET_CHILD :: proc(i: ^Interpreter, node: NODEID) -> NODEID {
	return i.nodes.first_child[node]
}
@(private = "file")
GET_ARGUMENTS_CHILD :: proc(i: ^Interpreter, node: NODEID) -> NODEID {
	fn_child := i.nodes.first_child[node]
	arg_child := i.nodes.next_sibling[fn_child]
	return arg_child
}
@(private = "file")
GET_SIBLING :: proc(i: ^Interpreter, node: NODEID) -> NODEID {
	return i.nodes.next_sibling[node]
}
@(private = "file")
GET_GCHILD :: proc(i: ^Interpreter, node: NODEID) -> NODEID {
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
GET_VARARGS_INFO :: proc(i: ^Interpreter, node: NODEID) -> (has_varargs: bool, name: string) {
	child := i.nodes.first_child[node]
	for child != 0 {
		if i.nodes.kind[child] == .VARARGS {
			return true, i.nodes.name[child]
		}
		child = i.nodes.next_sibling[child]
	}
	return false, ""
}
@(private = "file")
GET_FUNCTION_BODY :: proc(i: ^Interpreter, node: NODEID) -> NODEID {
	child := i->GET_CHILD(node)
	for child != 0 && (i.nodes.kind[child] == .IDENTIFIER || i.nodes.kind[child] == .VARARGS) {
		child = i->GET_SIBLING(child)
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
	case ^OuauError:
		return false
	}
	return false
}
@(private = "file")
CALL_USER_FUNCTION :: proc(i: ^Interpreter, fn: ^Closure, args: []Value) -> Value {
	env := NEW_ENVIRONMENT(fn.closure, i.arena)
	// Set regular parameters
	for param, idx in fn.params {
		if idx < len(args) {
			ENV_SET(env, param, args[idx])
		} else {
			ENV_SET(env, param, nil)
		}
	}
	// Set varargs if function has them
	if fn.has_varargs {
		my_alloc := virtual.arena_allocator(i.arena)
		varargs_table := new(Table, my_alloc)
		varargs_table.data = make(map[KeyTag]Value, my_alloc)
		start_idx := len(fn.params)
		for idx in start_idx ..< len(args) {
			key_tag := KeyTag {
				kind = 1,
				i    = cast(i64)(idx - start_idx) + 1,
			}
			varargs_table.data[key_tag] = args[idx]
		}
		ENV_SET(env, fn.varargs_name, varargs_table)
	}
	old_env := i.current
	i.current = env
	result := i->EVAL(fn.body)
	i.current = old_env
	if ret, ok := result.(^ReturnValue); ok {
		return ret.value
	}
	return nil
}
@(private = "file")
EVAL_EXPRESSION_LIST :: proc(i: ^Interpreter, node: NODEID) -> []Value {
	my_alloc := virtual.arena_allocator(i.arena)
	values := make([dynamic]Value, my_alloc)
	if node == 0 { return values[:] }
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
		case ^OuauError:
			return left.(^OuauError) == right.(^OuauError)
		}
	case .NEQ:
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
	if left == right { return true }
	if left == nil || right == nil { return false }
	if len(left.data) != len(right.data) { return false }
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
	lvalue := i->GET_CHILD(node)
	rvalue := i->GET_GCHILD(node)
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
		i.globals[name] = value_to_assign
		return value_to_assign
	case .BINARY:
		op := i.nodes.token[lvalue]
		if op == .DOT {
			table_expr_node := i->GET_CHILD(lvalue)
			table_val := i->EVAL(table_expr_node)
			table, ok := table_val.(^Table)
			if !ok || table == nil {
				return i->EVAL_ERROR("Expected table in dot expression")
			}
			key_node := i->GET_GCHILD(lvalue)
			key_val := i.nodes.name[key_node]
			key_tag := VALUE_TO_KEY_TAG(key_val)
			// Now evaluate RHS after we have the table location
			value_to_assign := i->EVAL(rvalue)
			table.data[key_tag] = value_to_assign
			return value_to_assign
		} else if op == .BOPEN {
			table_expr_node := i->GET_CHILD(lvalue)
			table_val := i->EVAL(table_expr_node)
			table, ok := table_val.(^Table)
			if !ok || table == nil {
				return i->EVAL_ERROR("Expected table in dot expression")
			}
			key_node := i->GET_GCHILD(lvalue)
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
@(private = "file")
EVAL_ERROR :: proc(i: ^Interpreter, msg: string) -> ^OuauError {
	my_alloc := virtual.arena_allocator(i.arena)
	e := new(OuauError, my_alloc)
	e.kind = .EvalErr
	e.msg = msg
	e.payload = EvalErr {
		evaluator = i,
	}
	fmt.eprintfln("|Eval Error::Msg::(%s)|", msg)
	fmt.eprintfln("|Call Stack::(%v)|", i.call_stack)
	fmt.eprintfln("|Globals::(%v)|", i.globals)
	return e
}
@(rodata)
INTERPRETER_VTABLE := InterpreterVTable {
	INTERPRET   = INTERPRET,
	EVAL        = EVAL,
	ASSIGN      = ASSIGN,
	GET_CHILD   = GET_CHILD,
	GET_GCHILD  = GET_GCHILD,
	GET_SIBLING = GET_SIBLING,
	EVAL_ERROR  = EVAL_ERROR,
}

