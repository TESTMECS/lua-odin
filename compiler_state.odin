package ouau
import "core:fmt"
Compiler :: struct {
	instructions: [dynamic]Instruction,
	constants:    [dynamic]Value, // pool for LoadK
	const_index:  map[Value]int, // equality hashing
	locals:       map[string]int, // name -> register
	upvalues:     map[string]int, // name -> upval index
	nodes:        ^NODES,
	max_stack:    int,
	nparams:      int,
	local_count:  int, // next free register
	free_regs:    [dynamic]int, // stack of freed reg indices
	prototypes:   [dynamic]^Compiler, // nested function prototypes
	parent:       ^Compiler, // upvalue resolution
}
NEW_COMPILER :: proc(p: ^Parser, allocator := context.allocator) -> ^Compiler {
	c := new(Compiler, allocator)
	c.nodes = &p.nodes
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
COMPILER_TO_PROTOTYPE :: proc(c: ^Compiler, allocator := context.allocator) -> ^Prototype {
	proto := new(Prototype, allocator)

	proto.instructions = c.instructions[:]
	proto.constants = c.constants[:]
	proto.max_stack = c.max_stack
	proto.num_params = c.nparams

	fmt.printf("Prototype len: %d\n", len(c.prototypes))
	proto.proto = make([]^Prototype, len(c.prototypes), allocator)
	for child, i in c.prototypes {
		fmt.printf("Prototype NESTED %d: %v\n", i, child)
		child_proto := COMPILER_TO_PROTOTYPE(child, allocator)
		proto.proto[i] = child_proto
	}
	proto.upvalues = make([dynamic]^UpValueDesc, allocator)
	for name, idx in c.upvalues {
		desc := new(UpValueDesc, allocator)
		desc.name = name
		desc.in_stack = true
		desc.index = idx
		append(&proto.upvalues, desc)
	}
	return proto
}

