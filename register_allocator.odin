package ouau
import "core:log"
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
	log.info("=== ALLOC_REG ===")
	if len(c.free_regs) > 0 {
		log.infof("Free registers: %v, popping...", c.free_regs)
		return pop(&c.free_regs)
	}
	r := c.local_count
	log.infof("Allocating register %v", r)
	c.local_count += 1
	if c.local_count > c.max_stack do c.max_stack = c.local_count
	return r
}
FREE_REG :: proc(c: ^Compiler, r: int) {
	log.info("=== FREE_REG ===")
	log.infof("Freeing register %v", r)
	append(&c.free_regs, r)
}

