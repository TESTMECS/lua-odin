package ouau
import "core:fmt"
import "core:mem/virtual"
/*
*	 ./compiler.odin
*	 Copyright(C) 2025 TESTMEE
*	 Defines the compiler functions for Ouau.
*/
Register_Allocator :: struct {
	free_regs: [dynamic]int,
	used_regs: [dynamic]int,
	max_regs:  int,
}
ALLOC_REG :: proc(c: ^Compiler) -> int {
	if len(c.free_regs) > 0 {
		return pop(&c.free_regs)
	}
	r := len(c.locals)
	if r > c.max_stack { c.max_stack = r }
	return r
}
FREE_REG :: proc(c: ^Compiler, r: int) {
	append(&c.free_regs, r)
}
COMPILE_NODE :: proc(c: ^Compiler, nodeid: NODEID) -> (register_idx: int) {
	/* TODO: Compiler err|nil::(-1) for now. */
	kind := c.nodes.kind[nodeid]
	switch kind {
	case .DO:
		child := c.nodes.first_child[nodeid]
		COMPILE_NODE(c, child)
	case .BREAK:
		unimplemented("TODO")
	case .VARARGS:
		unimplemented("TODO")
	case .BLOCK:
		c->BEGIN_SCOPE()
		defer c->END_SCOPE()
		last_result := -1
		for child := c.nodes.first_child[nodeid]; child != 0; child = c.nodes.next_sibling[child] {
			if last_result >= 0 {
				FREE_REG(c, last_result)
			}
			last_result = COMPILE_NODE(c, child)
		}
		return last_result
	case .LITERAL:
		return COMPILE_LITERAL(c, nodeid)
	case .IDENTIFIER:
		name := c.nodes.name[nodeid]
		local_reg := c->FIND_LOCAL(name)
		if local_reg >= 0 {
			dest := ALLOC_REG(c)
			EMITABC(c, .MOVE, u32(dest), u32(local_reg), 0)
			return dest
		}
		upval_idx := c->RESOLVE_UPVALUE(name)
		if upval_idx >= 0 {
			dest := ALLOC_REG(c)
			EMITABC(c, .GETUPVAL, u32(dest), u32(upval_idx), 0)
			return dest
		}
		// Must be a global
		dest := ALLOC_REG(c)
		name_idx := ADD_CONST(c, name)
		EMITABX(c, .GETGLOBAL, u32(dest), name_idx)
		return dest
	case .ASSIGN:
		target := c.nodes.first_child[nodeid]
		value := c.nodes.next_sibling[target]
		target_name := c.nodes.name[target]
		value_reg := COMPILE_NODE(c, value)
		local_reg := c->FIND_LOCAL(target_name)
		if local_reg >= 0 {
			if value_reg != local_reg {
				EMITABC(c, .MOVE, u32(local_reg), u32(value_reg), 0)
			}
			FREE_REG(c, value_reg)
			return local_reg
		}
		// Check if it's an upvalue
		upval_idx := c->RESOLVE_UPVALUE(target_name)
		if upval_idx >= 0 {
			EMITABC(c, .SETUPVAL, u32(upval_idx), u32(value_reg), 0)
			FREE_REG(c, value_reg)
			return value_reg
		}
		// Must be a global
		name_idx := ADD_CONST(c, target_name)
		EMITABX(c, .SETGLOBAL, u32(name_idx), u32(value_reg))
		FREE_REG(c, value_reg)
		return value_reg
	case .WHILE:
		unimplemented("TODO")
	case .REPEAT:
		unimplemented("TODO")
	case .TABLE:
		dest := ALLOC_REG(c)
		c->EMITABC(.NEWTABLE, u32(dest), 0, 0)
		child := c.nodes.first_child[nodeid]
		element_index := 1
		for child != 0 {
			// key-value pair(Binary node with ASSIGN token)
			if c.nodes.kind[child] == .BINARY && c.nodes.token[child] == .ASSIGN {
				key_node := c.nodes.first_child[child]
				value_node := c.nodes.next_sibling[key_node]
				if key_node == 0 || value_node == 0 {
					FREE_REG(c, dest)
					return -1
				}
				// Compile Key
				key_reg := COMPILE_NODE(c, key_node)
				if key_reg < 0 {
					FREE_REG(c, dest)
					return key_reg
				}
				// Compile Value
				value_reg := COMPILE_NODE(c, value_node)
				if value_reg < 0 {
					FREE_REG(c, dest)
					FREE_REG(c, key_reg)
					return value_reg
				}
				// Set table[key] = value
				c->EMITABC(.SETTABLE, u32(dest), u32(key_reg), u32(value_reg))
				FREE_REG(c, key_reg)
				FREE_REG(c, value_reg)
			} else {
				value_reg := COMPILE_NODE(c, child)
				if value_reg < 0 {
					FREE_REG(c, dest)
					return value_reg
				}
				index_reg := ALLOC_REG(c)
				index_const := c->ADD_CONST(f64(element_index))
				c->EMITABX(.LOADK, u32(index_reg), index_const)
				c->EMITABC(.SETTABLE, u32(dest), u32(index_reg), u32(value_reg))
				FREE_REG(c, index_reg)
				FREE_REG(c, value_reg)
				element_index += 1
			}
			child = c.nodes.next_sibling[child]
		}
		return dest
	case .FUNCTION:
		my_alloc := virtual.arena_allocator(c.arena)
		function_name := c.nodes.name[nodeid]
		params_node := c.nodes.first_child[nodeid]
		body_node := c.nodes.next_sibling[params_node]
		child := NEW_COMPILER(c.nodes, c.parent, c.arena)
		param := c.nodes.first_child[params_node]
		for param != 0 {
			name := c.nodes.name[param]
			child->DECLARE_LOCAL(name)
			child.num_params += 1
			param = c.nodes.next_sibling[param]
		}
		// Compile function body
		COMPILE_NODE(&child, body_node)
		// Ensure function body returns
		EMITABC(&child, .RETURN, 0, 1, 0)
		// Create prototype
		proto := new(Prototype, my_alloc)
		proto.instructions = child.instructions[:]
		proto.constants = child.constants[:]
		proto.prototypes = child.prototypes[:]
		proto.upvalues = child.upvalues[:]
		proto.max_stack = child.max_stack
		proto.num_params = child.num_params
		// Add to parent's prototypes
		proto_idx := len(c.prototypes)
		append(&c.prototypes, proto)
		dest := ALLOC_REG(c)
		EMITABX(c, .CLOSURE, u32(dest), u32(proto_idx))
		// Emit Upvalue capture instructions
		for uv in child.upvalues {
			if uv.is_local {
				// Capture upvalue from current stack.
				EMITABC(c, .MOVE, 0, u32(uv.index), 0)
			} else {
				// Capture upvalue from parent closure.
				EMITABC(c, .GETUPVAL, u32(uv.index), 0, 0)
			}
		}
		// If named function, store as global or local
		if function_name != "" {
			// Check if declaring as local
			if c.nodes.kind[nodeid] == .LOCAL {
				local_reg := DECLARE_LOCAL(c, function_name)
				if dest != local_reg {
					EMITABC(c, .MOVE, u32(local_reg), u32(dest), 0)
					FREE_REG(c, dest)
					return local_reg
				}
			} else {
				// Store as global
				name_idx := ADD_CONST(c, function_name)
				EMITABX(c, .SETGLOBAL, u32(dest), name_idx)
			}
		}
		return dest
	case .UNARY:
		operand := c.nodes.first_child[nodeid]
		if operand == 0 { return -1 }
		operand_reg := COMPILE_NODE(c, operand)
		if operand_reg < 0 { return operand_reg }
		dest := ALLOC_REG(c)
		op := c.nodes.token[nodeid]
		#partial switch op {
		case .MINUS:
			c->EMITABC(.UNM, u32(dest), u32(operand_reg), 0)
		case .NOT:
			c->EMITABC(.NOT, u32(dest), u32(operand_reg), 0)
		case:
			FREE_REG(c, operand_reg)
			FREE_REG(c, dest)
			return -1
		}
		FREE_REG(c, operand_reg)
		return dest
	case .UBLOCK:
		child := c.nodes.first_child[nodeid]
		last_result := -1
		for child != 0 {
			result := COMPILE_NODE(c, child)
			if result < 0 {
				return result
			}
			next_child := c.nodes.next_sibling[child]
			if next_child != 0 && result >= 0 {
				FREE_REG(c, result)
			} else {
				last_result = result
			}
			child = next_child
		}
		return last_result
	case .BINARY:
		op := c.nodes.token[nodeid]
		left := c.nodes.first_child[nodeid]
		right := c.nodes.next_sibling[left]
		left_reg := COMPILE_NODE(c, left)
		right_reg := COMPILE_NODE(c, right)
		dest := ALLOC_REG(c)
		// Map binary operators to opcodes
		Opcode: Opcodes
		#partial switch op {
		case .EQ:
			c->EMITABC(.EQ, 0, u32(left_reg), u32(right_reg))
			c->EMITABC(.JMP, 0, 1, 0)
			c->EMITABC(.LOADBOOL, u32(dest), 0, 1)
			c->EMITABC(.LOADBOOL, u32(dest), 1, 0)
		case .NE:
			c->EMITABC(.EQ, 0, u32(left_reg), u32(right_reg))
			c->EMITABC(.JMP, 0, 0, 0)
			c->EMITABC(.LOADBOOL, u32(dest), 0, 1)
			c->EMITABC(.LOADBOOL, u32(dest), 1, 0)
		case .LT:
			c->EMITABC(.LT, 0, u32(left_reg), u32(right_reg))
			c->EMITABC(.JMP, 0, 1, 0)
			c->EMITABC(.LOADBOOL, u32(dest), 0, 1)
			c->EMITABC(.LOADBOOL, u32(dest), 1, 0)
		case .LE:
			c->EMITABC(.LE, 0, u32(left_reg), u32(right_reg))
			c->EMITABC(.JMP, 0, 1, 0)
			c->EMITABC(.LOADBOOL, u32(dest), 0, 1)
			c->EMITABC(.LOADBOOL, u32(dest), 1, 0)
		case .PLUS:
			c->EMITABC(.ADD, u32(dest), u32(left_reg), u32(right_reg))
		case .MINUS:
			c->EMITABC(.SUB, u32(dest), u32(left_reg), u32(right_reg))
		case .MUL:
			c->EMITABC(.MUL, u32(dest), u32(left_reg), u32(right_reg))
		case .DIV:
			c->EMITABC(.DIV, u32(dest), u32(left_reg), u32(right_reg))
		case .ASSIGN:
			/*TODO: Not sure if this is correct.*/
			value_reg := COMPILE_NODE(c, right)
			target_kind := c.nodes.kind[left]
			#partial switch target_kind {
			case .IDENTIFIER:
				/* Simple assignment local k = v */
				target_name := c.nodes.name[left]
				// Check if its a local variable
				local_reg := c->FIND_LOCAL(target_name)
				if local_reg >= 0 {
					// Store to local
					if value_reg != local_reg {
						EMITABC(c, .MOVE, u32(local_reg), u32(value_reg), 0)
					}
					FREE_REG(c, value_reg)
					return local_reg
				}
				// Check if its an upvalue
				upval_idx := c->RESOLVE_UPVALUE(target_name)
				if upval_idx >= 0 {
					// Store to upvalue
					EMITABC(c, .SETUPVAL, u32(value_reg), u32(upval_idx), 0)
					FREE_REG(c, value_reg)
					return value_reg
				}
				// Must be a global
				name_idx := c->ADD_CONST(target_name)
				c->EMITABX(.SETGLOBAL, u32(value_reg), name_idx)
				FREE_REG(c, value_reg)
				return value_reg
			case:
				fmt.printf("ASSIGN: Unknown target kind %v\n", target_kind)
				FREE_REG(c, value_reg)
				return -1
			}
		}
		FREE_REG(c, left_reg)
		FREE_REG(c, right_reg)
		return dest
	case .STRING:
		str := c.nodes.string_value[nodeid]
		const_idx := c->ADD_CONST(str)
		dest := ALLOC_REG(c)
		c->EMITABX(.LOADK, u32(dest), const_idx)
		return dest
	case .GLOBAL:
		var_node := c.nodes.first_child[nodeid]
		if var_node == 0 {
			return -1
		}
		if c.nodes.kind[var_node] != .IDENTIFIER {
			return -1
		}
		var_name := c.nodes.name[var_node]
		assign_node := var_node
		for c.nodes.next_sibling[assign_node] != 0 {
			assign_node = c.nodes.next_sibling[assign_node]
		}
		if assign_node != var_node {
			value_reg := COMPILE_NODE(c, assign_node)
			if value_reg < 0 {
				return value_reg
			}
			func_const_idx := c->ADD_CONST(var_name)
			c->EMITABX(.SETGLOBAL, u32(value_reg), func_const_idx)
			FREE_REG(c, value_reg)
			return value_reg
		}
		return -1
	case .LOCAL:
		name := c.nodes.name[nodeid]
		init_node := c.nodes.first_child[nodeid]
		dest := c->DECLARE_LOCAL(name)
		if init_node != 0 {
			value_reg := COMPILE_NODE(c, init_node)
			if value_reg != dest {
				EMITABC(c, .MOVE, u32(dest), u32(value_reg), 0)
				FREE_REG(c, value_reg)
			}
		} else {
			// Initialize to nil
			EMITABC(c, .LOADNIL, u32(dest), 0, 0)
		}
		return dest
	case .FOR:
		var_name := c.nodes.name[nodeid]
		start_val := c.nodes.first_child[nodeid]
		end_val := c.nodes.next_sibling[start_val]
		body := c.nodes.next_sibling[end_val]
		if start_val == 0 || end_val == 0 || body == 0 { return -1 }
		var_reg := ALLOC_REG(c)
		start_reg := COMPILE_NODE(c, start_val)
		if start_reg < 0 { return start_reg }
		end_reg := COMPILE_NODE(c, end_val)
		if end_reg < 0 {
			FREE_REG(c, start_reg)
			return end_reg
		}
		step_reg := ALLOC_REG(c)
		one_const := c->ADD_CONST(1)
		c->EMITABX(.LOADK, u32(step_reg), one_const)
		c->EMITABC(.MOVE, u32(var_reg), u32(start_reg), 0)
		loop_start := len(c.instructions)
		c->EMITABC(.LE, 0, u32(var_reg), u32(end_reg))
		exit_jmp := EMIT_JUMP(c)
		body_result := COMPILE_NODE(c, body)
		if body_result < 0 {
			FREE_REG(c, start_reg)
			FREE_REG(c, end_reg)
			FREE_REG(c, step_reg)
			return body_result
		}
		if body_result >= 0 {
			FREE_REG(c, body_result)
		}
		c->EMITABC(.ADD, u32(var_reg), u32(var_reg), u32(step_reg))
		// Jump back to loop start
		back_jmp := EMIT_JUMP(c)
		PATCH_JUMP(c, back_jmp, loop_start)
		PATCH_JUMP(c, exit_jmp, len(c.instructions))
		FREE_REG(c, start_reg)
		FREE_REG(c, end_reg)
		FREE_REG(c, step_reg)
		return -1 // for loops don't produce a value
	case .CALL:
		function_node := c.nodes.first_child[nodeid]
		function_reg := COMPILE_NODE(c, function_node)
		arg_count := 0
		arg := c.nodes.next_sibling[function_node]
		for arg != 0 {
			arg_reg := COMPILE_NODE(c, arg)
			arg_count += 1
			arg = c.nodes.next_sibling[arg]
		}
		dest := ALLOC_REG(c)
		EMITABC(c, .CALL, u32(function_reg), u32(arg_count + 1), 2) // 1 return value
		// move result to dest if needed
		if dest != function_reg {
			EMITABC(c, .MOVE, u32(dest), u32(function_reg), 0)
		}
		return dest
	case .RETURN:
		// Compile return value if any
		value_node := c.nodes.first_child[nodeid]
		if value_node != 0 {
			value_reg := COMPILE_NODE(c, value_node)
			EMITABC(c, .RETURN, u32(value_reg), 1, 0) // 1 = return 1 value
			FREE_REG(c, value_reg)
		} else {
			EMITABC(c, .RETURN, 0, 0, 0) // 0 = return 0 values
		}
		return -1
	case .IF:
		cond := c.nodes.first_child[nodeid]
		then := c.nodes.next_sibling[cond]
		if cond == 0 || then == 0 { return -1 }
		cond_reg := COMPILE_NODE(c, cond)
		if cond_reg < 0 { return cond_reg }
		else_jmp := EMIT_JUMP(c)
		FREE_REG(c, cond_reg)
		then_result := COMPILE_NODE(c, then)
		if then_result < 0 { return then_result }
		if then_result >= 0 { FREE_REG(c, then_result) }
		end_jmp := EMIT_JUMP(c)
		PATCH_JUMP(c, else_jmp, len(c.instructions))
		next := c.nodes.next_sibling[then]
		if next != 0 {
			else_result := COMPILE_NODE(c, next)
			if else_result < 0 { return else_result }
			if else_result >= 0 { FREE_REG(c, else_result) }
		}
		PATCH_JUMP(c, end_jmp, len(c.instructions))
		return -1
	case .INVALID:
		return -1
	}
	return -1
}
@(private = "file")
COMPILE_LITERAL :: proc(c: ^Compiler, nodeid: NODEID) -> int {
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
	return -1
}
@(private = "file")
ADD_CONST :: proc(c: ^Compiler, v: Value) -> u32 {
	idx := u32(len(c.constants))
	append(&c.constants, v)
	return idx
}
@(private = "file")
EMITABC :: proc(compiler: ^Compiler, op: Opcodes, a, b, cvar: u32) -> int {
	inst := MAKE_ABC(u32(op), a, b, cvar)
	pc := len(compiler.instructions)
	append(&compiler.instructions, inst)
	return pc
}
@(private = "file")
EMITABX :: proc(c: ^Compiler, op: Opcodes, a, bx: u32) -> int {
	inst := MAKE_ABX(u32(op), a, bx)
	pc := len(c.instructions)
	append(&c.instructions, inst)
	return pc
}
@(private = "file")
EMITASBX :: proc(c: ^Compiler, op: Opcodes, a: u32, sbx: i32) -> int {
	inst := MAKE_ASBX(u32(op), a, sbx)
	pc := len(c.instructions)
	append(&c.instructions, inst)
	return pc
}
@(private = "file")
EMIT_JUMP :: proc(c: ^Compiler) -> int {
	return EMITASBX(c, .JMP, 0, 0)
}
@(private = "file")
PATCH_JUMP :: proc(c: ^Compiler, pc_slot: int, target_pc: int) {
	offset := target_pc - (pc_slot + 1)
	op, a, _ := DECODE_ASBX(c.instructions[pc_slot])
	c.instructions[pc_slot] = MAKE_ASBX(u32(op), u32(a), i32(offset))
}
RESOLVE_VAR :: proc(c: ^Compiler, name: string) -> (reg: int, is_local: bool, upval_idx: int) {
	// Check local variables in current function
	for i := len(c.locals) - 1; i >= 0; i -= 1 {
		if c.locals[i].name == name {
			return c.locals[i].reg, true, -1
		}
	}
	// Check if it's an upvalue
	upval_idx = RESOLVE_UPVALUE(c, name)
	if upval_idx >= 0 {
		return -1, false, upval_idx
	}
	// Not found - will be treated as global
	return -1, false, -1
}
// Resolve upvalue by walking up the compiler chain
RESOLVE_UPVALUE :: proc(c: ^Compiler, name: string) -> int {
	if c.parent == nil {
		return -1 // Not found
	}
	// Check if it's a local in the immediate parent
	for i := len(c.parent.locals) - 1; i >= 0; i -= 1 {
		if c.parent.locals[i].name == name {
			return ADD_UPVALUE(c, name, true, c.parent.locals[i].reg)
		}
	}
	// Recursively check parent's upvalues
	parent_upval := RESOLVE_UPVALUE(c.parent, name)
	if parent_upval >= 0 {
		// Found in ancestor - add as upvalue referencing parent's upvalue
		return ADD_UPVALUE(c, name, false, parent_upval)
	}
	return -1
}
// Add an upvalue to this function
@(private = "file")
ADD_UPVALUE :: proc(c: ^Compiler, name: string, in_stack: bool, index: int) -> int {
	// Check if we already have this upvalue
	for uv, i in c.upvalues {
		if uv.name == name && uv.is_local == in_stack && uv.index == index {
			return i
		}
	}
	// Add new upvalue
	desc := UpValueDesc {
		name     = name,
		is_local = in_stack,
		index    = index,
	}
	my_alloc := virtual.arena_allocator(c.arena)
	append(&c.upvalues, desc)
	return len(c.upvalues) - 1
}
// Declare a local variable
@(private = "file")
DECLARE_LOCAL :: proc(c: ^Compiler, name: string) -> int {
	reg := ALLOC_REG(c)
	local := Local {
		name  = name,
		depth = c.scope_depth,
		reg   = reg,
	}
	append(&c.locals, local)
	return reg
}
// Find local variable by name
@(private = "file")
FIND_LOCAL :: proc(c: ^Compiler, name: string) -> int {
	for i := len(c.locals) - 1; i >= 0; i -= 1 {
		if c.locals[i].name == name {
			return c.locals[i].reg
		}
	}
	return -1
}
// Enter a new scope
@(private = "file")
BEGIN_SCOPE :: proc(c: ^Compiler) {
	c.scope_depth += 1
}
// Exit a scope and remove locals
@(private = "file")
END_SCOPE :: proc(c: ^Compiler) {
	c.scope_depth -= 1
	// Remove locals from this scope
	for len(c.locals) > 0 && c.locals[len(c.locals) - 1].depth > c.scope_depth {
		pop(&c.locals)
	}
}
@(rodata)
COMPILER_VTABLE := CompilerVTable {
	BEGIN_SCOPE     = BEGIN_SCOPE,
	END_SCOPE       = END_SCOPE,
	DECLARE_LOCAL   = DECLARE_LOCAL,
	RESOLVE_VAR     = RESOLVE_VAR,
	EMIT_JUMP       = EMIT_JUMP,
	PATCH_JUMP      = PATCH_JUMP,
	EMITABC         = EMITABC,
	EMITABX         = EMITABX,
	EMITASBX        = EMITASBX,
	ADD_CONST       = ADD_CONST,
	ADD_UPVALUE     = ADD_UPVALUE,
	FIND_LOCAL      = FIND_LOCAL,
	RESOLVE_UPVALUE = RESOLVE_UPVALUE,
}

