package ouau
ThreadState :: struct {
	globals:    ^GlobalState,
	base:       Frame,
	call_count: int,
	stack:      [dynamic]Value,
	pc:         int,
	status:     ThreadStatus,
}
GlobalState :: struct {
	builtins: [dynamic]Table,
	registry: ^Table,
	thread:   ^ThreadState,
	gc_heap:  ^GC_HEAP,
	panic:    proc(state: ^ThreadState, msg: string, level: int),
}
Thread :: struct {
	state: ^ThreadState,
}
ThreadStatus :: enum {
	OK,
	ERR,
	YIELD,
	SUSPENDED,
}
VMFrame :: struct {
	func:        ^Closure,
	return_addr: int,
	base_reg:    int,
	saved_pc:    int,
	num_results: int,
	tail_calls:  int,
}
CallInfo :: struct {
	func:     ^Closure,
	base:     int,
	saved_pc: int,
}
VM :: struct {
	global_state:   ^GlobalState,
	current_thread: ^ThreadState,
	all_threads:    [dynamic]^ThreadState,
	gc_threshold:   int,
	gc_debt:        int,
	config:         ^VM_Config,
}
VM_Config :: struct {
	stack_size:   int,
	call_depth:   int,
	gc_threshold: int,
	max_threads:  int,
}

