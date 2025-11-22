package ouau
// Globalstate
GlobalState :: struct {
	thread:       ^ThreadState,
	registry:     ^Table,
	string_table: StringTable,
	gc:           ^GC_HEAP,
	globals:      ^Table,
	panic:        proc(state: ^ThreadState, msg: string, level: int),
	builtins:     [dynamic]^Table, // builtin functions
	gc_threshold: int,
}
StringTable :: struct {
	hash:  [dynamic]^String,
	size:  int,
	count: int,
}
String :: struct {
	using header: GC_HEADER,
	next:         ^String,
	hash:         u32,
	data:         string,
}

