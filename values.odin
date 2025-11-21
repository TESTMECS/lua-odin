package ouau
KeyTag :: struct {
	kind: u8,
	i:    i64,
	f:    f64,
	s:    string,
	p:    rawptr,
}
Value :: union {
	bool,
	f64,
	string,
	rawptr,
	^Table,
	^Closure,
	^ReturnValue,
}
ReturnValue :: struct {
	value: Value,
}
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
Closure :: struct {
	using header: GC_HEADER,
	is_native:    bool,
	params:       []string,
	body:         NODEID,
	closure:      ^Environment,
	native_proc:  proc(args: []Value) -> Value,
	proto:        ^Prototype,
	upvalues:     [dynamic]^Upvalue,
}
Prototype :: struct {
	using header: GC_HEADER,
	instructions: []Instruction,
	constants:    []Value,
	proto:        [dynamic]^Prototype,
	upvalues:     [dynamic]^UpValueDesc,
	max_stack:    int,
	num_params:   int,
}
Upvalue :: struct {
	value:  ^Value,
	closed: ^Value,
	next:   ^Upvalue,
}
UpValueDesc :: struct {
	name:     string,
	in_stack: bool,
	index:    int,
}
VALUE_TO_KEY_TAG :: proc(v: Value) -> KeyTag {
	switch val in v {
	case bool:
		return KeyTag{kind = 3, i = cast(i64)val}
	case f64:
		return KeyTag{kind = 1, i = cast(i64)val}
	case string:
		return KeyTag{kind = 2, s = val}
	case rawptr:
		return KeyTag{kind = 4, p = val}
	case ^Table:
		return KeyTag{kind = 5, p = val}
	case ^Closure:
		return KeyTag{kind = 6, p = val}
	case ^ReturnValue:
		panic("Cannot use a return value as a table key")
	case:
		return KeyTag{kind = 0}
	}
}

