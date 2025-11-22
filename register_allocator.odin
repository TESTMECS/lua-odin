package ouau
/*
	 ./register_allocator.odin
	 Copyright(C) 2025 TESTMEE
	 Defines the register allocator functions for Ouau.
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
	r := c.local_count
	c.local_count += 1
	if c.local_count > c.max_stack do c.max_stack = c.local_count
	return r
}
FREE_REG :: proc(c: ^Compiler, r: int) {
	append(&c.free_regs, r)
}

