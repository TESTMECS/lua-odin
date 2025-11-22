package ouau

GCType :: enum u8 {
	STRING,
	TABLE,
	CLOSURE,
	UPVALUE,
	PROTOTYPE,
	THREAD,
}

GC_HEADER :: struct {
	marked:     bool,
	generation: u8, // 0 = young, 1 = old
	gctype:     GCType,
}

GCObject :: struct {
	using header: GC_HEADER,
}

GC_HEAP :: struct {
	young:          [dynamic]^GCObject,
	old:            [dynamic]^GCObject,
	remembered_set: [dynamic]^GCObject, // for generational WB
	gray:           [dynamic]^GCObject, // mark queue
	state:          GC_STATE,
}

GC_STATE :: enum u8 {
	IDLE,
	MARK,
	SWEEP,
}

NEW_GC_HEAP :: proc(allocator := context.allocator) -> ^GC_HEAP {
	heap := new(GC_HEAP, allocator)
	heap.young = make([dynamic]^GCObject, allocator)
	heap.old = make([dynamic]^GCObject, allocator)
	heap.remembered_set = make([dynamic]^GCObject, allocator)
	heap.gray = make([dynamic]^GCObject, allocator)
	return heap
}

