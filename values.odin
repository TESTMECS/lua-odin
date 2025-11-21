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
	data:      map[KeyTag]Value,
	sorted:    [dynamic]KeyTag,
	dirty:     bool,
	metatable: ^Table,
	last_free: int,
}
Closure :: struct {
	is_native:   bool,
	params:      []string,
	body:        NODEID,
	closure:     ^Environment,
	native_proc: proc(args: []Value) -> Value,
	proto:       ^Prototype,
	upvalues:    [dynamic]^Upvalue,
}
Prototype :: struct {
	instructions: [dynamic]Instruction,
	constants:    [dynamic]Value,
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

