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

