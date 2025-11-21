package ouau
import "core:mem"
ThreadState :: struct {
	globals:    ^GlobalState,
	stack:      [dynamic]Value,
	call_count: int,
	pc:         int,
	top:        int,
	base:       int,
	status:     ThreadStatus,
	call_stack: [dynamic]VMFrame,
}
GlobalState :: struct {
	builtins:     [dynamic]^Table,
	registry:     ^Table,
	thread:       ^ThreadState,
	gc_heap:      ^GC_HEAP,
	panic:        proc(state: ^ThreadState, msg: string, level: int),
	string_table: map[string]^Value,
	gc_threshold: int,
	gc_debt:      int,
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
	global_state:    ^GlobalState,
	current_thread:  ^ThreadState,
	all_threads:     [dynamic]^ThreadState,
	gc_threshold:    int,
	gc_debt:         int,
	config:          ^VM_Config,
	allocator:       mem.Allocator,
	gc_running:      bool,
	pause_threshold: int,
}
VM_Config :: struct {
	stack_size:   int,
	call_depth:   int,
	gc_threshold: int,
	max_threads:  int,
}

