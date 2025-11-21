package ouau

Compiler :: struct {
	instructions: [dynamic]Instruction,
	constants:    [dynamic]Value, // pool for LoadK
	const_index:  map[Value]int, // equality hashing
	locals:       map[string]int, // name -> register
	upvalues:     map[string]int, // name -> upval index
	interpreter:  ^Interpreter,
	max_stack:    int,
	nparams:      int,
	local_count:  int, // next free register
	free_regs:    [dynamic]int, // stack of freed reg indices
	prototypes:   [dynamic]^Compiler, // nested function prototypes
	parent:       ^Compiler, // upvalue resolution
}
OuauCompiler :: struct {
	current: ^Compiler,
}
ALLOC_REG :: proc(c: ^Compiler) -> int {
	if len(c.free_regs) > 0 {
		return pop(&c.free_regs)
	}
	r := c.local_count
	c.local_count += 1
	if c.local_count > c.max_stack do c.max_stack = c.local_count
	return r
}
FREE_REG :: proc(c: ^Compiler, r: int) {
	append(&c.free_regs, r)
}
ADD_CONST :: proc(c: ^Compiler, v: Value) -> u32 {
	idx := u32(len(c.constants))
	append(&c.constants, v)
	return idx
}
EMITABC :: proc(compiler: ^Compiler, op: Opcodes, a, b, c: u32) -> int {
	inst := MAKE_ABC(u32(op), a, b, c)
	pc := len(compiler.instructions)
	append(&compiler.instructions, inst)
	return pc
}
EMITABX :: proc(c: ^Compiler, op: Opcodes, a, bx: u32) -> int {
	inst := MAKE_ABX(u32(op), a, bx)
	pc := len(c.instructions)
	append(&c.instructions, inst)
	return pc
}
EMITASBX :: proc(c: ^Compiler, op: Opcodes, a: u32, sbx: i32) -> int {
	inst := MAKE_ASBX(u32(op), a, sbx)
	pc := len(c.instructions)
	append(&c.instructions, inst)
	return pc
}
EMIT_JUMP :: proc(c: ^Compiler) -> int {
	return EMITASBX(c, .JMP, 0, 0)
}
PATCH_JUMP :: proc(c: ^Compiler, pc_slot: int, target_pc: int) {
	offset := target_pc - (pc_slot + 1)
	op, a, _ := DECODE_ASBX(c.instructions[pc_slot])
	c.instructions[pc_slot] = MAKE_ASBX(u32(op), u32(a), i32(offset))
}
COMPILE_NODE :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	kind := c.interpreter.nodes.kind[nodeid]
	#partial switch kind {
	case .LITERAL:
		reg := ALLOC_REG(c)
		val := unimplemented("TODO") // build value
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
			return idx // alread in register
		}
		// err
		panic("Variable undefined")
	case .ASSIGN:
		lhs := COMPILE_NODE(c, c.interpreter.nodes.first_child[nodeid])
		rhs := COMPILE_NODE(c, c.interpreter.nodes.next_sibling[nodeid])
		rhs_reg := unimplemented("TODO") // compile rhs
		if CHECK_KIND(c, lhs, .IDENTIFIER) {
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
		switch op {
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

