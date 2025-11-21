package ouau

GC_HEADER :: struct {
	marked:     bool, // TAGGED ON EVERY OBJ
	generation: u8, // 0 = young, 1 = old
}
GC_HEAP :: struct {
	young:    [dynamic]rawptr,
	old:      [dynamic]rawptr,
	memories: [dynamic]rawptr,
	set:      [dynamic]rawptr,
	graylist: [dynamic]rawptr,
	gc_state: GC_STATE,
}
GC_STATE :: enum u8 {
	IDLE,
	MARK,
	SWEEP,
}
NEW_GC_HEAP :: proc(allocator := context.allocator) -> ^GC_HEAP {
	heap := new(GC_HEAP, allocator)
	heap.young = make([dynamic]rawptr, allocator)
	heap.old = make([dynamic]rawptr, allocator)
	heap.memories = make([dynamic]rawptr, allocator)
	heap.graylist = make([dynamic]rawptr, allocator)
	heap.gc_state = .IDLE
	return heap
}

