package ouau
import "core:mem/virtual"
RegisterAllocator :: struct {
	free_regs: [dynamic]int,
	used_regs: [dynamic]int,
	max_regs:  int,
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
Local :: struct {
	name:  string,
	reg:   int, // register index
	depth: int, // depth of the local
}
Compiler :: struct {
	instructions: [dynamic]u32, // Bytecode instructions
	constants:    [dynamic]Value, // pool for LoadK instructions
	locals:       [dynamic]Local, // map of name -> register
	local_count:  int, // next register index
	upvalues:     [dynamic]UpValueDesc, // map of name -> upval index
	nodes:        ^NODES, // AST nodes
	max_stack:    int, // max stack size
	num_params:   int, // number of parameters
	scope_depth:  int, // current scope depth
	free_regs:    [dynamic]int, // stack of freed reg indices
	prototypes:   [dynamic]^Prototype, // nested function prototypes
	parent:       ^Compiler, // upvalue resolution
	arena:        ^virtual.Arena,
}

