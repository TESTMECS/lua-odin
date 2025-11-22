package ouau

Table :: struct {
	using header: GC_HEADER,
	data:         map[KeyTag]Value,
	sorted:       [dynamic]KeyTag,
	dirty:        bool,
	metatable:    ^Table,
	last_free:    int,
}
NEW_TABLE :: proc(allocator := context.allocator) -> ^Table {
	table := new(Table, allocator)
	table.header.marked = false
	table.header.generation = 0
	table.data = make(map[KeyTag]Value, allocator)
	table.sorted = make([dynamic]KeyTag, allocator)
	table.dirty = false
	table.metatable = nil
	table.last_free = 0
	return table
}

