package ouau
import "core:mem"

Memory_Pool :: struct {
	allocator:        mem.Allocator,
	// Type-specific pools
	instruction_pool: [dynamic]u32,
	value_pool:       [dynamic]Value,
	prototype_pool:   [dynamic]^Prototype,
	// Statistics
	total_allocated:  int,
	peak_usage:       int,
}

Compilation_Arena :: struct {
	base_allocator: mem.Allocator,
	temp_storage:   [dynamic][]u8,
	reset_pointers: [dynamic]^rawptr,
}

