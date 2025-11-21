package ouau
COMPILE_NODE :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	kind := c.interpreter.nodes.kind[nodeid]
	#partial switch kind {
	case .LITERAL:
		reg := ALLOC_REG(c)
		val: Value
		k := ADD_CONST(c, val)
		EMITABX(c, .LOADK, u32(reg), u32(k))
		return reg
	case .IDENTIFIER:
		name := c.interpreter.nodes.name[nodeid]
		val: Value
		if valueis, ok := c.interpreter.globals[name]; ok {
			val = valueis
			reg := ALLOC_REG(c)
			EMITABX(c, .GETGLOBAL, u32(reg), u32(ADD_CONST(c, val)))
		}
		 else if idx, ok := c.locals[name]; ok {
			return idx // already in register
		}
		COMPILE_ERR(c, "Variable undefined", name)
	case .ASSIGN:
		lhs := COMPILE_NODE(c, c.interpreter.nodes.first_child[nodeid])
		rhs := COMPILE_NODE(c, c.interpreter.nodes.next_sibling[nodeid])
		rhs_reg := 0
		val: Value
		if CHECK_KIND(c, c.interpreter.nodes.first_child[nodeid], .IDENTIFIER) {
			name := c.interpreter.nodes.name[nodeid]
			if local_idx, ok := c.locals[name]; ok {
				EMITABC(c, .MOVE, u32(local_idx), u32(rhs_reg), u32(0))
			}
			 else {
				EMITABX(c, .SETGLOBAL, u32(rhs_reg), u32(ADD_CONST(c, val)))
			}
		}
	case .BINARY:
		left_reg := COMPILE_NODE(c, c.interpreter.nodes.first_child[nodeid])
		right_reg := COMPILE_NODE(c, c.interpreter.nodes.next_sibling[nodeid])
		op := c.interpreter.nodes.token[nodeid]
		#partial switch op {
		case .PLUS:
			EMITABC(c, .ADD, u32(left_reg), u32(left_reg), u32(right_reg))
			FREE_REG(c, right_reg)
			return left_reg
		case .EQ:
			unimplemented("TODO BINARY EQ")
		}
	case .CALL:
		unimplemented("TODO CALL")
	case .RETURN:
		unimplemented("TODO RETURN")
	case .IF:
		cond := COMPILE_NODE(c, c.interpreter.nodes.first_child[nodeid])
		jmp_false := EMIT_JUMP(c)
		FREE_REG(c, cond)
		then := COMPILE_NODE(c, c.interpreter.nodes.next_sibling[nodeid])
		jmp_end := EMIT_JUMP(c)
		PATCH_JUMP(c, jmp_false, len(c.instructions))
		has_else := true
		if has_else {COMPILE_NODE(c, c.interpreter.nodes.next_sibling[nodeid])}
		PATCH_JUMP(c, jmp_end, len(c.instructions))
		return -1
	}
	return -1
}
CHECK_KIND :: proc(c: ^Compiler, nodeid: NODEID, kind: NODE_KIND) -> bool {
	if c.interpreter.nodes.kind[nodeid] == kind {
		return true
	}
	return false
}

