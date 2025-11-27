package ouau
import "core:fmt"
import "core:io"
import "core:mem/virtual"
import "core:strings"
/*
	 ./values.odin
	 Copyright(C) 2025 TESTMEE
	 Values and Types for Ouau, now with errors as values.
 */
/* Type Tag for Ouau Values */
KeyTag :: struct {
	kind: u8,
	i:    i64, // integer
	f:    f64, // float
	s:    string, // string
	p:    rawptr, //userdata/table/closure/error
}
/* Ouau Values */
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
/* Ouau Break Value */
BreakValue :: struct {}
/* Ouau Return Value TODO: Remove this. */
ReturnValue :: struct {
	value: Value,
}
Prototype :: struct {
	instructions: []u32, // Prototype instructions.
	constants:    []Value, // Prototype constants.
	prototypes:   []^Prototype, // Prototype prototypes.
	upvalues:     []UpValueDesc, // Prototype upvalues.
	max_stack:    int, // Prototype max stack size.
	num_params:   int, // Prototype number of parameters.
	source_name:  string, // Prototype source name.
}
/* Ouau Closure */
Closure :: struct {
	params:       []string,
	body:         NODEID,
	closure:      ^Environment, // Variables in the closure.
	proto:        ^Prototype, // Prototype/Compilation context of the closure.
	upvalues:     [dynamic]^Upvalue, // Upvalues in the closure.
	is_native:    bool,
	has_varargs:  bool,
	varargs_name: string,
	native_proc:  proc(args: []Value) -> Value,
}
/* Ouau Table */
Table :: struct {
	data:      map[KeyTag]Value, // Dynamic part
	sorted:    [dynamic]KeyTag, // Array part, sorted
	dirty:     bool, // for Hashing
	metatable: ^Table, // Metatable
	last_free: int, // Free register
}
/* Runtime Upvalue */
Upvalue :: struct {
	open:   ^Value,
	closed: ^Value,
}
/* Up Value Descriptor::(compile-time) */
UpValueDesc :: struct {
	name:     string,
	is_local: bool, // true = local, false = upvalue or in parent
	index:    int, // register index(if in stack) or upvalue index(if not)
}
@(private)
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
/* Error Values. */
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
/* Error Kinds */
ErrorKind :: enum {
	SyntaxErr,
	ParseErr,
	EvalErr,
	CompileErr,
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

