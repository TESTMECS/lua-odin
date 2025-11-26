package ouau
import "core:fmt"
import "core:hash"
import "core:io"
import "core:mem/virtual"
import "core:strings"
/*
	 ./values.odin
	 Copyright(C) 2025 TESTMEE
	 Values and Types for Ouau, now with errors as values.
 */
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
	^BreakValue,
	^OuauError,
}
BreakValue :: struct {}
ReturnValue :: struct {
	value: Value,
}
Closure :: struct {
	params:      []string,
	body:        NODEID,
	closure:     ^Environment,
	proto:       ^Prototype,
	upvalues:    [dynamic]^Upvalue,
	is_native:   bool,
	native_proc: proc(args: []Value) -> Value,
}
Table :: struct {
	data:      map[KeyTag]Value,
	sorted:    [dynamic]KeyTag,
	dirty:     bool,
	metatable: ^Table,
	last_free: int,
}
NEW_TABLE :: proc(allocator := context.allocator) -> ^Table {
	table := new(Table, allocator)
	table.data = make(map[KeyTag]Value, allocator)
	table.sorted = make([dynamic]KeyTag, allocator)
	table.dirty = false
	table.metatable = nil
	table.last_free = 0
	return table
}
Upvalue :: struct {
	open:   ^Value,
	closed: ^Value,
}
UpValueDesc :: struct {
	is_local: bool,
	index:    int,
}
VALUE_TO_KEY_TAG :: proc(v: Value) -> KeyTag {
	switch val in v {
	case f64:
		return KeyTag{kind = 1, i = cast(i64)val}
	case string:
		return KeyTag{kind = 2, s = val}
	case bool:
		return KeyTag{kind = 3, i = cast(i64)val}
	case rawptr:
		return KeyTag{kind = 4, p = val}
	case ^Table:
		return KeyTag{kind = 5, p = val}
	case ^Closure:
		return KeyTag{kind = 6, p = val}
	case ^OuauError:
		return KeyTag{kind = 7, p = val}
	case ^ReturnValue:
		panic("Cannot use a return value as a table key")
	case ^BreakValue:
		panic("Cannot use a break value as a table key")
	case:
		return KeyTag{kind = 0}
	}
}
@(private)
VALUE_TO_STRING :: proc(v: Value, varena: ^virtual.Arena) -> string {
	my_alloc := virtual.arena_allocator(varena)
	sb := strings.builder_make(my_alloc)
	#partial switch val in v {
	case bool:
		return val ? "true" : "false"
	case f64:
		strings.write_f64(&sb, val, 'g')
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
		return "return value"
	case ^BreakValue:
		return "break"
	case ^OuauError:
		return fmt.tprintf("(%v): %s", val.kind, val.msg)
	case:
		return "nil"
	}
}
// Error Values.
OuauError :: struct {
	kind:    ErrorKind,
	msg:     string,
	payload: union {
		SyntaxErr,
		ParseErr,
		EvalErr,
		AllocatorErr,
		IOErr,
	},
	cause:   ^OuauError, // for chained errors
}
ErrorKind :: enum {
	SyntaxErr,
	ParseErr,
	EvalErr,
	AllocatorErr,
	IOErr,
}
AllocatorErr :: struct {
	err: virtual.Allocator_Error,
}
IOErr :: struct {
	err: io.Error,
}
IO_ERROR :: proc(err: io.Error, my_msg: string, v: ^virtual.Arena) -> ^OuauError {
	my_alloc := virtual.arena_allocator(v)
	e := new(OuauError, my_alloc)
	e.kind = .IOErr
	e.msg = my_msg
	e.payload = IOErr {
		err = err,
	}
	return e
}
SyntaxErr :: struct {
	pos:  int,
	kind: Token,
	text: string,
}
ParseErr :: struct {
	msg:           string,
	parser_object: ^Parser,
}
EvalErr :: struct {
	msg:       string,
	evaluator: ^Interpreter,
}
@(cold)
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

