package ouau

import "core:fmt"

Compiler :: struct {
	instructions: [dynamic]u32,
	constants:    [dynamic]Value, // pool for LoadK
	const_index:  map[Value]int, // equality hashing
	locals:       map[string]int, // name -> register
	upvalues:     map[string]int, // name -> upval index
	nodes:        ^NODES,
	max_stack:    int,
	nparams:      int,
	local_count:  int, // next free register
	free_regs:    [dynamic]int, // stack of freed reg indices
	prototypes:   [dynamic]^Prototype, // nested function prototypes
	parent:       ^Prototype, // upvalue resolution
}

Prototype :: struct {
	using header: GC_HEADER,
	instructions: []u32,
	constants:    []Value,
	proto:        []^Prototype,
	upvalues:     [dynamic]^UpValueDesc,
	max_stack:    int,
	num_params:   int,
}

NEW_COMPILER :: proc(bytecode: ^NODES, allocator := context.allocator) -> ^Compiler {
	c := new(Compiler, allocator)
	c.nodes = bytecode
	c.constants = make([dynamic]Value, allocator)
	c.const_index = make(map[Value]int, allocator)
	c.locals = make(map[string]int, allocator)
	c.upvalues = make(map[string]int, allocator)
	c.free_regs = make([dynamic]int, allocator)
	c.parent = nil
	return c
}

COMPILE_ERR :: proc(c: ^Compiler, msg: string, xtra: ..any) -> int {
	if len(xtra) == 0 {
		fmt.println(msg)
	}
	 else {
		fmt.printfln(msg, xtra)
	}
	return -1
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

