package ouau

Compiler :: struct {
	instructions: [dynamic]Instruction,
	constants:    [dynamic]Value, // pool for LoadK
	const_index:  map[Value]int, // equality hashing
	max_stack:    int,
	nparams:      int,
	locals:       map[string]int, // name -> register
	local_count:  int, // next free register
	free_regs:    [dynamic]int, // stack of freed reg indices
	upvalues:     map[string]int, // name -> upval index
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

