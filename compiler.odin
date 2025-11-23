package ouau
import "core:log"
/*
*	 ./compiler.odin
*	 Copyright(C) 2025 TESTMEE
*	 Defines the compiler functions for Ouau.
*/
COMPILE_NODE :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	kind := c.nodes.kind[nodeid]
	log.infof("Compiling node %v", kind)
	switch kind {
	case .DO:
		unreachable()
	case .BREAK:
		unimplemented("TODO")
	case .VARARGS:
		unimplemented("TODO")
	case .UPVALUE:
		unimplemented("TODO")
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
	case .FOR:
		return COMPILE_FOR(c, nodeid)
	case .CALL:
		return COMPILE_CALL(c, nodeid)
	case .RETURN:
		return COMPILE_RETURN(c, nodeid)
	case .IF:
		return COMPILE_IF(c, nodeid)
	case .INVALID:
		return COMPILE_ERR(c, "Invalid node", kind)
	}
	return COMPILE_ERR(c, "Unimplemented node", kind)
}
@(private = "file")
CHECK_KIND :: proc(c: ^Compiler, nodeid: NODEID, kind: NODE_KIND) -> bool {
	if c.nodes.kind[nodeid] == kind {
		return true
	}
	return false
}
@(private = "file")
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
@(private = "file")
COMPILE_STRING :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	str := c.nodes.string_value[nodeid]
	const_idx := ADD_CONST(c, str)
	dest := ALLOC_REG(c)
	EMITABX(c, .LOADK, u32(dest), const_idx)
	return dest
}
@(private = "file")
COMPILE_LOCAL :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	var_node := c.nodes.first_child[nodeid] // Get the first child(namelist or function)
	log.infof("Compiling LOCAL node %v", c.nodes.kind[var_node] == .FUNCTION)

	if var_node == 0 do return COMPILE_ERR(c, "LOCAL node has no variable name or function definition.")
	if c.nodes.kind[var_node] != .IDENTIFIER do return COMPILE_ERR(c, "Expected identifier in LOCAL declaration") // Should be function as well but fix later.

	var_name := c.nodes.name[var_node]
	log.infof("Compiling LOCAL node with name::%v", var_name)

	reg := ALLOC_REG(c)
	c.locals[var_name] = reg
	// Check if there's an assignment (next sibling after variables)
	assign_node := var_node
	log.infof("assign_node::%v", c.nodes.name[assign_node])
	for c.nodes.next_sibling[assign_node] != 0 {
		assign_node = c.nodes.next_sibling[assign_node]
	}
	// If there's an assignment value, compile it
	if assign_node != var_node {
		value_reg := COMPILE_NODE(c, assign_node)
		if value_reg < 0 do return value_reg
		if value_reg != reg {
			EMITABC(c, .MOVE, u32(reg), u32(value_reg), 0)
			FREE_REG(c, value_reg)
		}
	}
	return reg
}
@(private = "file")
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
@(private = "file")
COMPILE_BLOCK :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	child := c.nodes.first_child[nodeid] // Get first child
	assert(child != nodeid, "First child of BLOCK is itself")

	last_result := -1 // Assume no result

	for child != 0 {
		result := COMPILE_NODE(c, child) // Compile child

		if result < 0 && c.nodes.kind[child] != .RETURN && c.nodes.kind[child] != .FUNCTION {
			// RETURN and FUNCTION statements return -1, which is not an error in blocks
			return result
		}

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
@(private = "file")
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
@(private = "file")
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
@(private = "file")
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
@(private = "file")
COMPILE_FUNCTION :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	func_name := c.nodes.name[nodeid]

	// Get function body (first child)
	body := c.nodes.first_child[nodeid]
	if body == 0 {
		return COMPILE_ERR(c, "FUNCTION node missing body")
	}

	prototype := new(Prototype, context.allocator)
	function_compiler := NEW_COMPILER(c.nodes, context.allocator)
	saved_locals := c.locals
	saved_local_count := c.local_count

	function_compiler.locals = make(map[string]int, context.allocator)
	function_compiler.local_count = 0

	body_result := COMPILE_NODE(function_compiler, body)

	// For functions, body_result < 0 is normal (due to RETURN), so don't return early
	prototype.instructions = function_compiler.instructions[:]
	prototype.constants = function_compiler.constants[:]
	prototype.max_stack = function_compiler.max_stack
	prototype.num_params = 0

	proto_index := len(c.prototypes)
	append(&c.prototypes, prototype)

	c.locals = saved_locals
	c.local_count = saved_local_count

	dest := ALLOC_REG(c)
	EMITABX(c, .CLOSURE, u32(dest), u32(proto_index))

	function_const_idx := ADD_CONST(c, func_name)
	EMITABX(c, .SETGLOBAL, u32(dest), function_const_idx)

	FREE_REG(c, dest)

	return dest
}
@(private = "file")
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
@(private = "file")
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
	EMITABC(c, .TEST, u32(cond_reg), 0, 0) // Test if condition is false
	back_jump := EMIT_JUMP(c)
	PATCH_JUMP(c, back_jump, loop_start)
	// Free condition register
	FREE_REG(c, cond_reg)
	return -1 // Repeat loops don't produce a value
}
@(private = "file")
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
@(private = "file")
COMPILE_CALL :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	// Get function and arguments
	func := c.nodes.first_child[nodeid]
	args := c.nodes.next_sibling[func]
	if func == 0 {
		return COMPILE_ERR(c, "CALL node missing function")
	}
	// Compile function expression
	func_reg := COMPILE_NODE(c, func)
	if func_reg < 0 do return func_reg
	// Count and compile arguments
	arg_count := 0
	arg := args
	for arg != 0 {
		arg_reg := COMPILE_NODE(c, arg)
		if arg_reg < 0 {
			FREE_REG(c, func_reg)
			return arg_reg
		}
		// Move argument to consecutive registers starting from func_reg + 1
		EMITABC(c, .MOVE, u32(func_reg + arg_count + 1), u32(arg_reg), 0)
		FREE_REG(c, arg_reg)
		arg_count += 1
		arg = c.nodes.next_sibling[arg]
	}
	// Emit CALL instruction
	// A = func_reg, B = num_args + 1, C = num_results + 1
	EMITABC(c, .CALL, u32(func_reg), u32(arg_count + 1), u32(2))
	// Return value is in func_reg
	FREE_REG(c, func_reg)
	return func_reg
}
@(private = "file")
COMPILE_IF :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	// Get condition, then branch, and optional elseif/else branches
	condition := c.nodes.first_child[nodeid]
	then_branch := c.nodes.next_sibling[condition]
	if condition == 0 || then_branch == 0 {
		return COMPILE_ERR(c, "IF node missing condition or then branch")
	}
	// Compile condition
	cond_reg := COMPILE_NODE(c, condition)
	if cond_reg < 0 do return cond_reg
	// If condition is false, jump to else/elseif/end
	else_jump := EMIT_JUMP(c)
	// Free condition register
	FREE_REG(c, cond_reg)
	// Compile then branch
	then_result := COMPILE_NODE(c, then_branch)
	if then_result < 0 do return then_result
	// Free then result register if any
	if then_result >= 0 do FREE_REG(c, then_result)
	// Jump to end after then branch (if there's an else/elseif)
	end_jump := EMIT_JUMP(c)
	// Patch else jump to here (else/elseif section)
	PATCH_JUMP(c, else_jump, len(c.instructions))
	// Check for elseif/else branches
	next_branch := c.nodes.next_sibling[then_branch]
	if next_branch != 0 {
		// Compile elseif/else branches
		else_result := COMPILE_NODE(c, next_branch)
		if else_result < 0 do return else_result
		// Free else result register if any
		if else_result >= 0 do FREE_REG(c, else_result)
	}
	// Patch end jump to here
	PATCH_JUMP(c, end_jump, len(c.instructions))
	return -1 // If statements don't produce a value
}
@(private = "file")
COMPILE_FOR :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	// Get loop variable name from node
	var_name := c.nodes.name[nodeid]
	// Get start, end, and body from children
	start_val := c.nodes.first_child[nodeid]
	end_val := c.nodes.next_sibling[start_val]
	body := c.nodes.next_sibling[end_val]
	if start_val == 0 || end_val == 0 || body == 0 {
		return COMPILE_ERR(c, "FOR node missing required components")
	}
	// Allocate register for loop variable
	var_reg := ALLOC_REG(c)
	c.locals[var_name] = var_reg
	// Compile start value
	start_reg := COMPILE_NODE(c, start_val)
	if start_reg < 0 do return start_reg
	// Compile end value
	end_reg := COMPILE_NODE(c, end_val)
	if end_reg < 0 {
		FREE_REG(c, start_reg)
		return end_reg
	}
	// Default step is 1
	step_reg := ALLOC_REG(c)
	one_const := ADD_CONST(c, 1.0)
	EMITABX(c, .LOADK, u32(step_reg), one_const)
	// Initialize loop variable
	EMITABC(c, .MOVE, u32(var_reg), u32(start_reg), 0)
	// Record loop start for jump back
	loop_start := len(c.instructions)
	// Check if loop variable <= end value (for positive step)
	// This is a simplified version - real Lua for loops are more complex
	EMITABC(c, .LE, 0, u32(var_reg), u32(end_reg))
	// Jump to end if condition is false
	exit_jump := EMIT_JUMP(c)
	// Compile loop body
	body_result := COMPILE_NODE(c, body)
	if body_result < 0 {
		FREE_REG(c, start_reg)
		FREE_REG(c, end_reg)
		FREE_REG(c, step_reg)
		return body_result
	}
	// Free body result register if any
	if body_result >= 0 do FREE_REG(c, body_result)
	// Increment loop variable: var = var + step
	EMITABC(c, .ADD, u32(var_reg), u32(var_reg), u32(step_reg))
	// Jump back to condition check
	back_jump := EMIT_JUMP(c)
	PATCH_JUMP(c, back_jump, loop_start)
	// Patch exit jump to here
	PATCH_JUMP(c, exit_jump, len(c.instructions))
	// Clean up
	FREE_REG(c, start_reg)
	FREE_REG(c, end_reg)
	FREE_REG(c, step_reg)
	return -1 // For loops don't produce a value
}
@(private = "file")
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
@(private = "file")
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
@(private = "file")
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

