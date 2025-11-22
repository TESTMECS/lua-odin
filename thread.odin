package ouau

STACK_LIMIT :: 1024 * 1024

Thread :: struct {
	state: ^ThreadState,
}

ThreadStatus :: enum {
	OK,
	ERR,
	YIELD,
	SUSPENDED,
}

ThreadState :: struct {
	globals:     ^GlobalState,
	stack:       [dynamic]Value,
	open_upvals: ^Upvalue,
	ci:          ^CallInfo,
	base_ci:     ^CallInfo,
	status:      ThreadStatus,
	call_count:  int,
	pc:          int,
	top:         int,
	base:        int,
	call_stack:  [dynamic]VMFrame,
}

