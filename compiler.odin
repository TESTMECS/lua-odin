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
		unimplemented("TODO ASSIGN")
	case .WHILE:
		unimplemented("TODO WHILE")
	case .REPEAT:
		unimplemented("TODO REPEAT")
	case .TABLE:
		unimplemented("TODO TABLE")
	case .FUNCTION:
		return COMPILE_FUNCTION(c, nodeid)
	case .UNARY:
		return COMPILE_UNARY(c, nodeid)
	case .UBLOCK:
		unimplemented("TODO UBLOCK")
	case .BINARY:
		return COMPILE_BINARY(c, nodeid)
	case .STRING:
		return COMPILE_STRING(c, nodeid)
	case .GLOBAL:
		unimplemented("TODO GLOBAL")
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
	case:
		FREE_REG(c, left_reg)
		FREE_REG(c, right_reg)
		FREE_REG(c, dest)
		return COMPILE_ERR(c, "Unsupported binary operator", op)
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

