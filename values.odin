package ouau
import "core:hash"
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
@(private)
VALUE_TO_STRING :: proc(v: Value, allocator := context.allocator) -> string {
	sb := strings.builder_make(allocator)
	defer strings.builder_destroy(&sb)
	#partial switch val in v {
	case bool:
		return val ? "true" : "false"
	case f64:
		strings.write_f64(&sb, val, 'f')
		ret_val := strings.to_string(sb)
		return ret_val
	case string:
		return val
	case rawptr:
		return "userdata"
	case ^Table:
		return "table"
	case ^Closure:
		return "closure"
	case ^ReturnValue:
		return VALUE_TO_STRING(val.value)
	case:
		return "nil"
	}
}
@(cold)
hash_keytag :: proc(k: KeyTag) -> u64 {
	using hash
	buf: [64]u8 // plenty for controlled encoding
	idx := 0

	// always encode kind first
	buf[idx] = k.kind
	idx += 1

	switch k.kind {
	case 0:
		// string
		// write length (u32)
		len := cast(u32)len(k.s)
		transmute_u32_to_bytes(buf[idx:], len)
		idx += 4
		// write string bytes
		for b, i in k.s {
			buf[idx] = k.s[i]
			idx += 1
		}
	case 1:
		// integer
		transmute_i64_to_bytes(buf[idx:], k.i)
		idx += 8

	case 2:
		// float
		bits := transmute(u64)k.f
		transmute_u64_to_bytes(buf[idx:], bits)
		idx += 8

	case 3:
		// bool (encoded from `i`)
		buf[idx] = u8(k.i & 1)
		idx += 1

	case 4:
		// pointer
		check := uintptr(k.p)
		ensure(check != 0, "Invalid Rawptr")
		transmute_u64_to_bytes(buf[idx:], cast(u64)check)
		idx += 8

	case 5:
		// table pointer
		check := uintptr(k.p)
		ensure(check != 0, "Invalid Rawptr")
		transmute_u64_to_bytes(buf[idx:], cast(u64)check)
		idx += 8

	case 6:
		// closure pointer
		check := uintptr(k.p)
		ensure(check != 0, "Invalid Rawptr")
		transmute_u64_to_bytes(buf[idx:], cast(u64)check)
		idx += 8
	}

	return fnv64a(buf[:idx])
}
@(cold)
transmute_u32_to_bytes :: proc(dst: []u8, v: u32) {
	dst[0] = u8(v >> 0)
	dst[1] = u8(v >> 8)
	dst[2] = u8(v >> 16)
	dst[3] = u8(v >> 24)
}
@(cold)
transmute_i64_to_bytes :: proc(dst: []u8, v: i64) {
	u := transmute(u64)v
	transmute_u64_to_bytes(dst, u)
}
@(cold)
transmute_u64_to_bytes :: proc(dst: []u8, v: u64) {
	for i in 0 ..< 8 {
		dst[i] = u8(v >> uint(i * 8))
	}
}

