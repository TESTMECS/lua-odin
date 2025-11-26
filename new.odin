package ouau
import "core:mem/virtual"
/*
	 ./new.odin
	 Copyright(C) 2025 TESTMEE
	 Defines the compiler functions for Ouau.
*/
// Resolve a variable - checks locals, then upvalues, then globals
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
DECLARE_LOCAL :: proc(c: ^Compiler, name: string, reg: int) {
	my_alloc := virtual.arena_allocator(c.arena)
	local := Local {
		name  = name,
		depth = c.scope_depth,
		reg   = reg,
	}
	append(&c.locals, local)
}
// Enter a new scope
BEGIN_SCOPE :: proc(c: ^Compiler) {
	c.scope_depth += 1
}
// Exit a scope and remove locals
END_SCOPE :: proc(c: ^Compiler) {
	c.scope_depth -= 1
	// Remove locals from this scope
	for len(c.locals) > 0 && c.locals[len(c.locals) - 1].depth > c.scope_depth {
		pop(&c.locals)
	}
}

