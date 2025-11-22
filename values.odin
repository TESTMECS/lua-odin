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
Closure :: struct {
	using header: GC_HEADER,
	is_native:    bool,
	params:       []string,
	body:         NODEID,
	closure:      ^Environment,
	proto:        ^Prototype,
	upvalues:     [dynamic]^Upvalue,
	native_proc:  proc(args: []Value) -> Value,
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

compare_keytag :: proc(a, b: KeyTag) -> bool {
	if a.kind != b.kind {
		return a.kind < b.kind
	}
	switch a.kind {
	case 0:
		if a.s != b.s {
			return a.s < b.s // lexicographic
		}
		return false // equal

	case 1:
		return a.i < b.i

	case 2:
		return a.f < b.f // handles +/-inf, NaN rules consistent

	case 3:
		return (a.i & 1) < (b.i & 1)

	case 4:
		checka := uintptr(a.p)
		ensure(checka != 0, "Invalid Rawptr")
		checkb := uintptr(b.p)
		ensure(checkb != 0, "Invalid Rawptr")
		return cast(u64)checka < cast(u64)checkb

	case 5:
		checka := uintptr(a.p)
		ensure(checka != 0, "Invalid Rawptr")
		checkb := uintptr(b.p)
		ensure(checkb != 0, "Invalid Rawptr")
		return cast(u64)checka < cast(u64)checkb

	case 6:
		checka := uintptr(a.p)
		ensure(checka != 0, "Invalid Rawptr")
		checkb := uintptr(b.p)
		ensure(checkb != 0, "Invalid Rawptr")
		return cast(u64)checka < cast(u64)checkb
	}
	return false
}

