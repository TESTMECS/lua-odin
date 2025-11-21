package ouau
import "core:fmt"
COMPILE_NODE :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	kind := c.nodes.kind[nodeid]

	switch kind {
	case .BLOCK:
		return COMPILE_BLOCK(c, nodeid)
	case .LITERAL:
		return COMPILE_LITERAL(c, nodeid)
	case .IDENTIFIER:
		return COMPILE_IDENTIFIER(c, nodeid)
	case .ASSIGN:
		return COMPILE_ASSIGN(c, nodeid)
	case .WHILE:
		return COMPILE_WHILE(c, nodeid)
	case .REPEAT:
		return COMPILE_REPEAT(c, nodeid)
	case .TABLE:
		return COMPILE_TABLE(c, nodeid)
	case .FUNCTION:
		return COMPILE_FUNCTION(c, nodeid)
	case .UNARY:
		return COMPILE_UNARY(c, nodeid)
	case .UBLOCK:
		return COMPILE_UBLOCK(c, nodeid)
	case .BINARY:
		return COMPILE_BINARY(c, nodeid)
	case .STRING:
		return COMPILE_STRING(c, nodeid)
	case .GLOBAL:
		return COMPILE_GLOBAL(c, nodeid)
	case .LOCAL:
		return COMPILE_LOCAL(c, nodeid)
	case .BREAK:
		unimplemented("TODO BREAK")
	case .FOR:
		unimplemented("TODO FOR")
	case .DO:
		unimplemented("TODO")
	case .CALL:
		unimplemented("TODO CALL")
	case .RETURN:
		return COMPILE_RETURN(c, nodeid)
	case .IF:
		unimplemented("TODO IF")
	case .INVALID:
		return COMPILE_ERR(c, "Invalid node", kind)
	}
	return COMPILE_ERR(c, "Unimplemented node", kind)
}
CHECK_KIND :: proc(c: ^Compiler, nodeid: NODEID, kind: NODE_KIND) -> bool {
	if c.nodes.kind[nodeid] == kind {
		return true
	}
	return false
}

COMPILE_LITERAL :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	// Check if it's a number literal
	if c.nodes.int_value[nodeid] != 0 {
		val := f64(c.nodes.int_value[nodeid])
		const_idx := ADD_CONST(c, val)
		dest := ALLOC_REG(c)
		EMITABX(c, .LOADK, u32(dest), const_idx)
		return dest
	}
	str := c.nodes.string_value[nodeid]
	if str == "nil" {
		dest := ALLOC_REG(c)
		EMITABC(c, .LOADNIL, u32(dest), 0, 0)
		return dest
	}
	if str == "true" {
		dest := ALLOC_REG(c)
		EMITABC(c, .LOADBOOL, u32(dest), 1, 0)
		return dest
	}
	if str == "false" {
		dest := ALLOC_REG(c)
		EMITABC(c, .LOADBOOL, u32(dest), 0, 0)
		return dest
	}
	// Handle empty string case
	if len(str) == 0 {
		dest := ALLOC_REG(c)
		const_idx := ADD_CONST(c, "")
		EMITABX(c, .LOADK, u32(dest), const_idx)
		return dest
	}
	return COMPILE_ERR(c, "Unknown literal type", str)
}
COMPILE_STRING :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	str := c.nodes.string_value[nodeid]
	const_idx := ADD_CONST(c, str)
	dest := ALLOC_REG(c)
	EMITABX(c, .LOADK, u32(dest), const_idx)
	return dest
}
COMPILE_LOCAL :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	// Get the first child (variable name)
	var_node := c.nodes.first_child[nodeid]
	if var_node == 0 {
		return COMPILE_ERR(c, "LOCAL node has no variable name")
	}
	// Get variable name
	if c.nodes.kind[var_node] != .IDENTIFIER {
		return COMPILE_ERR(c, "Expected identifier in LOCAL declaration")
	}
	var_name := c.nodes.name[var_node]
	// Allocate register for this variable
	reg := ALLOC_REG(c)
	c.locals[var_name] = reg
	// Check if there's an assignment (next sibling after variables)
	assign_node := var_node
	for c.nodes.next_sibling[assign_node] != 0 {
		assign_node = c.nodes.next_sibling[assign_node]
	}
	// If there's an assignment value, compile it
	if assign_node != var_node {
		value_reg := COMPILE_NODE(c, assign_node)
		if value_reg < 0 do return value_reg
		// Move the value to the variable's register
		if value_reg != reg {
			EMITABC(c, .MOVE, u32(reg), u32(value_reg), 0)
			FREE_REG(c, value_reg)
		}
	}
	return reg
}
COMPILE_IDENTIFIER :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	var_name := c.nodes.name[nodeid]
	// Check if it's a local variable
	if reg, ok := c.locals[var_name]; ok {
		dest := ALLOC_REG(c)
		EMITABC(c, .MOVE, u32(dest), u32(reg), 0)
		return dest
	}
	// Treat as global variable
	const_idx := ADD_CONST(c, var_name)
	dest := ALLOC_REG(c)
	EMITABX(c, .GETGLOBAL, u32(dest), const_idx)
	return dest
}
COMPILE_BLOCK :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	child := c.nodes.first_child[nodeid]
	last_result := -1
	for child != 0 {
		result := COMPILE_NODE(c, child)
		if result < 0 do return result
		// Free the result register unless it's the last expression
		next_child := c.nodes.next_sibling[child]
		if next_child != 0 && result >= 0 {
			FREE_REG(c, result)
		}
		 else {
			last_result = result
		}
		child = next_child
	}
	return last_result
}
COMPILE_BINARY :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	// Get left and right operands
	left := c.nodes.first_child[nodeid]
	right := c.nodes.next_sibling[left]

	if left == 0 || right == 0 {
		return COMPILE_ERR(c, "BINARY node missing operands")
	}

	left_reg := COMPILE_NODE(c, left)
	if left_reg < 0 do return left_reg

	right_reg := COMPILE_NODE(c, right)
	if right_reg < 0 {
		FREE_REG(c, left_reg)
		return right_reg
	}

	dest := ALLOC_REG(c)
	op := c.nodes.token[nodeid]

	// Map token to opcode
	#partial switch op {
	case .PLUS:
		EMITABC(c, .ADD, u32(dest), u32(left_reg), u32(right_reg))
	case .MINUS:
		EMITABC(c, .SUB, u32(dest), u32(left_reg), u32(right_reg))
	case .MUL:
		EMITABC(c, .MUL, u32(dest), u32(left_reg), u32(right_reg))
	case .DIV:
		EMITABC(c, .DIV, u32(dest), u32(left_reg), u32(right_reg))
	case .EQ:
		EMITABC(c, .EQ, 0, u32(left_reg), u32(right_reg))
		EMITABC(c, .JMP, 0, 1, 0)
		EMITABC(c, .LOADBOOL, u32(dest), 0, 1)
		EMITABC(c, .LOADBOOL, u32(dest), 1, 0)
	case .NE:
		EMITABC(c, .EQ, 0, u32(left_reg), u32(right_reg))
		EMITABC(c, .JMP, 0, 0, 0)
		EMITABC(c, .LOADBOOL, u32(dest), 0, 1)
		EMITABC(c, .LOADBOOL, u32(dest), 1, 0)
	case .LT:
		EMITABC(c, .LT, 0, u32(left_reg), u32(right_reg))
		EMITABC(c, .JMP, 0, 1, 0)
		EMITABC(c, .LOADBOOL, u32(dest), 0, 1)
		EMITABC(c, .LOADBOOL, u32(dest), 1, 0)
	case .LE:
		EMITABC(c, .LE, 0, u32(left_reg), u32(right_reg))
		EMITABC(c, .JMP, 0, 1, 0)
		EMITABC(c, .LOADBOOL, u32(dest), 0, 1)
		EMITABC(c, .LOADBOOL, u32(dest), 1, 0)
	case .ASSIGN:
		// Handle assignment: left = right
		if c.nodes.kind[left] == .IDENTIFIER {
			var_name := c.nodes.name[left]
			
			// Check if it's a local variable
			if reg, ok := c.locals[var_name]; ok {
				// Move the value to the local variable's register
				if right_reg != reg {
					EMITABC(c, .MOVE, u32(reg), u32(right_reg), 0)
				}
				FREE_REG(c, left_reg)
				FREE_REG(c, right_reg)
				FREE_REG(c, dest)
				return reg
			}
			
			// Treat as global variable assignment
			const_idx := ADD_CONST(c, var_name)
			EMITABX(c, .SETGLOBAL, u32(right_reg), const_idx)
			FREE_REG(c, left_reg)
			FREE_REG(c, right_reg)
			FREE_REG(c, dest)
			return right_reg
		}
		
		FREE_REG(c, left_reg)
		FREE_REG(c, right_reg)
		FREE_REG(c, dest)
		return COMPILE_ERR(c, "Unsupported assignment target in binary")
	case:
		FREE_REG(c, left_reg)
		FREE_REG(c, right_reg)
		FREE_REG(c, dest)
		return COMPILE_ERR(c, "Unsupported binary operator %v", op)
	}

	FREE_REG(c, left_reg)
	FREE_REG(c, right_reg)
	return dest
}

COMPILE_UNARY :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	// Get the operand
	operand := c.nodes.first_child[nodeid]
	if operand == 0 {
		return COMPILE_ERR(c, "UNARY node missing operand")
	}

	operand_reg := COMPILE_NODE(c, operand)
	if operand_reg < 0 do return operand_reg

	dest := ALLOC_REG(c)
	op := c.nodes.token[nodeid]

	// Map token to opcode
	#partial switch op {
	case .MINUS:
		EMITABC(c, .UNM, u32(dest), u32(operand_reg), 0)
	case .NOT:
		EMITABC(c, .NOT, u32(dest), u32(operand_reg), 0)
	case:
		FREE_REG(c, operand_reg)
		FREE_REG(c, dest)
		return COMPILE_ERR(c, "Unsupported unary operator", op)
	}

	FREE_REG(c, operand_reg)
	return dest
}

COMPILE_RETURN :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	// Get the first child (return value, if any)
	child := c.nodes.first_child[nodeid]

	if child == 0 {
		// Return with no values
		EMITABC(c, .RETURN, 0, 1, 0)
		return -1
	}

	// Compile the return value
	value_reg := COMPILE_NODE(c, child)
	if value_reg < 0 do return value_reg

	// Return with one value
	EMITABC(c, .RETURN, u32(value_reg), 2, 0)
	FREE_REG(c, value_reg)
	return -1
}
COMPILE_FUNCTION :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	// Create a new compiler for the function prototype
	func_compiler := NEW_COMPILER(nil, context.allocator)
	func_compiler.parent = c
	func_compiler.nodes = c.nodes

	// Get function name
	func_name := c.nodes.name[nodeid]

	// Get parameters and body
	child := c.nodes.first_child[nodeid]
	param_count := 0

	// Process parameters (identifiers before the body)
	for child != 0 && c.nodes.kind[child] == .IDENTIFIER {
		param_name := c.nodes.name[child]
		param_reg := ALLOC_REG(func_compiler)
		func_compiler.locals[param_name] = param_reg
		param_count += 1
		child = c.nodes.next_sibling[child]
	}

	func_compiler.nparams = param_count

	// The remaining child should be the function body
	if child == 0 {
		return COMPILE_ERR(c, "FUNCTION node missing body")
	}

	// Compile the function body
	body_result := COMPILE_NODE(func_compiler, child)
	// RETURN statements return -1, which is fine for function bodies
	// Only treat as error if it's a different negative value
	if body_result < -1 do return body_result

	// Add return instruction at the end if not already present
	EMITABC(func_compiler, .RETURN, 0, 1, 0)

	// Add function prototype to the parent's prototypes
	proto_idx := u32(len(c.prototypes))
	append(&c.prototypes, func_compiler)

	// Create closure in parent
	dest := ALLOC_REG(c)
	EMITABX(c, .CLOSURE, u32(dest), proto_idx)

	// For now, also store the function as a global
	func_const_idx := ADD_CONST(c, func_name)
	EMITABX(c, .SETGLOBAL, u32(dest), func_const_idx)

	return dest
}

COMPILE_ASSIGN :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	// Get left and right operands
	left := c.nodes.first_child[nodeid]
	right := c.nodes.next_sibling[left]
	
	if left == 0 || right == 0 {
		return COMPILE_ERR(c, "ASSIGN node missing operands")
	}
	
	// Compile the right side (value)
	value_reg := COMPILE_NODE(c, right)
	if value_reg < 0 do return value_reg
	
	// Handle assignment to variable
	if c.nodes.kind[left] == .IDENTIFIER {
		var_name := c.nodes.name[left]
		
		// Check if it's a local variable
		if reg, ok := c.locals[var_name]; ok {
			// Move the value to the local variable's register
			if value_reg != reg {
				EMITABC(c, .MOVE, u32(reg), u32(value_reg), 0)
			}
			FREE_REG(c, value_reg)
			return reg
		}
		
		// Treat as global variable assignment
		const_idx := ADD_CONST(c, var_name)
		EMITABX(c, .SETGLOBAL, u32(value_reg), const_idx)
		FREE_REG(c, value_reg)
		return value_reg
	}
	
	// Handle assignment to table field (e.g., table.field = value)
	if c.nodes.kind[left] == .BINARY && c.nodes.token[left] == .DOT {
		// Get table and field
		table_node := c.nodes.first_child[left]
		field_node := c.nodes.next_sibling[table_node]
		
		if table_node == 0 || field_node == 0 {
			FREE_REG(c, value_reg)
			return COMPILE_ERR(c, "Table assignment missing table or field")
		}
		
		// Compile table
		table_reg := COMPILE_NODE(c, table_node)
		if table_reg < 0 {
			FREE_REG(c, value_reg)
			return table_reg
		}
		
		// Compile field
		field_reg := COMPILE_NODE(c, field_node)
		if field_reg < 0 {
			FREE_REG(c, value_reg)
			FREE_REG(c, table_reg)
			return field_reg
		}
		
		// Set table[field] = value
		EMITABC(c, .SETTABLE, u32(table_reg), u32(field_reg), u32(value_reg))
		
		FREE_REG(c, table_reg)
		FREE_REG(c, field_reg)
		FREE_REG(c, value_reg)
		return value_reg
	}
	
	FREE_REG(c, value_reg)
	return COMPILE_ERR(c, "Unsupported assignment target")
}

COMPILE_REPEAT :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	// Get body (first child)
	body := c.nodes.first_child[nodeid]
	
	if body == 0 {
		return COMPILE_ERR(c, "REPEAT node missing body")
	}
	
	// The condition is the next sibling of the REPEAT node
	condition := c.nodes.next_sibling[nodeid]
	
	if condition == 0 {
		return COMPILE_ERR(c, "REPEAT node missing condition")
	}
	
	// Record the start of the loop (where body starts)
	loop_start := len(c.instructions)
	
	// Compile the loop body first
	body_result := COMPILE_NODE(c, body)
	if body_result < 0 do return body_result
	
	// Free body result register if any
	if body_result >= 0 do FREE_REG(c, body_result)
	
	// Compile the condition
	cond_reg := COMPILE_NODE(c, condition)
	if cond_reg < 0 do return cond_reg
	
	// If condition is false, jump back to loop start
	// In Lua, repeat-until continues when condition is false
	EMITABC(c, .TEST, u32(cond_reg), 0, 0)  // Test if condition is false
	back_jump := EMIT_JUMP(c)
	PATCH_JUMP(c, back_jump, loop_start)
	
	// Free condition register
	FREE_REG(c, cond_reg)
	
	return -1 // Repeat loops don't produce a value
}

COMPILE_UBLOCK :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	// UBLOCK is likely an "unscoped block" - similar to BLOCK but without creating a new scope
	// For now, treat it the same as BLOCK
	child := c.nodes.first_child[nodeid]
	last_result := -1
	for child != 0 {
		result := COMPILE_NODE(c, child)
		if result < 0 do return result
		// Free the result register unless it's the last expression
		next_child := c.nodes.next_sibling[child]
		if next_child != 0 && result >= 0 {
			FREE_REG(c, result)
		}
		 else {
			last_result = result
		}
		child = next_child
	}
	return last_result
}

COMPILE_WHILE :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	// Get condition and body
	condition := c.nodes.first_child[nodeid]
	body := c.nodes.next_sibling[condition]
	
	if condition == 0 || body == 0 {
		return COMPILE_ERR(c, "WHILE node missing condition or body")
	}
	
	// Record the start of the loop (where condition is evaluated)
	loop_start := len(c.instructions)
	
	// Compile the condition
	cond_reg := COMPILE_NODE(c, condition)
	if cond_reg < 0 do return cond_reg
	
	// If condition is false, jump to end of loop
	exit_jump := EMIT_JUMP(c)
	
	// Free condition register
	FREE_REG(c, cond_reg)
	
	// Compile the loop body
	body_result := COMPILE_NODE(c, body)
	if body_result < 0 do return body_result
	
	// Free body result register if any
	if body_result >= 0 do FREE_REG(c, body_result)
	
	// Jump back to condition evaluation
	back_jump := EMIT_JUMP(c)
	PATCH_JUMP(c, back_jump, loop_start)
	
	// Patch the exit jump to jump to here (after the loop)
	PATCH_JUMP(c, exit_jump, len(c.instructions))
	
	return -1 // While loops don't produce a value
}

COMPILE_GLOBAL :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	// Get the first child (variable name)
	var_node := c.nodes.first_child[nodeid]
	if var_node == 0 {
		return COMPILE_ERR(c, "GLOBAL node has no variable name")
	}
	// Get variable name
	if c.nodes.kind[var_node] != .IDENTIFIER {
		return COMPILE_ERR(c, "Expected identifier in GLOBAL declaration")
	}
	var_name := c.nodes.name[var_node]
	// Check if there's an assignment (next sibling after variables)
	assign_node := var_node
	for c.nodes.next_sibling[assign_node] != 0 {
		assign_node = c.nodes.next_sibling[assign_node]
	}
	// If there's an assignment value, compile it
	if assign_node != var_node {
		value_reg := COMPILE_NODE(c, assign_node)
		if value_reg < 0 do return value_reg
		// Store the value as a global
		func_const_idx := ADD_CONST(c, var_name)
		EMITABX(c, .SETGLOBAL, u32(value_reg), func_const_idx)
		FREE_REG(c, value_reg)
		return value_reg
	}
	return COMPILE_ERR(c, "GLOBAL declaration missing assignment value")
}

COMPILE_TABLE :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	// Create a new table
	dest := ALLOC_REG(c)
	EMITABC(c, .NEWTABLE, u32(dest), 0, 0)

	// Process table elements
	child := c.nodes.first_child[nodeid]
	element_index := 1

	for child != 0 {
		// Check if this is a key-value pair (BINARY node with ASSIGN token)
		if c.nodes.kind[child] == .BINARY && c.nodes.token[child] == .ASSIGN {
			// Get key and value
			key_node := c.nodes.first_child[child]
			value_node := c.nodes.next_sibling[key_node]

			if key_node == 0 || value_node == 0 {
				FREE_REG(c, dest)
				return COMPILE_ERR(c, "Table key-value pair missing key or value")
			}

			// Compile key
			key_reg := COMPILE_NODE(c, key_node)
			if key_reg < 0 {
				FREE_REG(c, dest)
				return key_reg
			}

			// Compile value
			value_reg := COMPILE_NODE(c, value_node)
			if value_reg < 0 {
				FREE_REG(c, dest)
				FREE_REG(c, key_reg)
				return value_reg
			}

			// Set table[key] = value
			EMITABC(c, .SETTABLE, u32(dest), u32(key_reg), u32(value_reg))

			FREE_REG(c, key_reg)
			FREE_REG(c, value_reg)
		}
		 else {
			// Array-style element (just a value)
			value_reg := COMPILE_NODE(c, child)
			if value_reg < 0 {
				FREE_REG(c, dest)
				return value_reg
			}

			// Use index as key
			index_reg := ALLOC_REG(c)
			index_const := ADD_CONST(c, f64(element_index))
			EMITABX(c, .LOADK, u32(index_reg), index_const)

			// Set table[index] = value
			EMITABC(c, .SETTABLE, u32(dest), u32(index_reg), u32(value_reg))

			FREE_REG(c, index_reg)
			FREE_REG(c, value_reg)
			element_index += 1
		}

		child = c.nodes.next_sibling[child]
	}

	return dest
}

