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
NEW_VM :: proc(config: ^VM_Config, allocator := context.allocator) -> ^VM {
	vm := new(VM, allocator)
	vm.config = config
	vm.allocator = allocator
	vm.global_state = NEW_GLOBAL_STATE(allocator)
	vm.current_thread = NEW_THREAD(vm.global_state, config.stack_size, allocator)
	vm.all_threads = make([dynamic]^ThreadState, allocator)
	append(&vm.all_threads, vm.current_thread)
	return vm
}
NEW_GLOBAL_STATE :: proc(allocator := context.allocator) -> ^GlobalState {
	gs := new(GlobalState, allocator)
	gs.builtins = make([dynamic]^Table, allocator)
	gs.string_table = make(map[string]^Value, allocator)
	gs.gc_heap = NEW_GC_HEAP(allocator)
	gs.registry = NEW_TABLE(allocator)
	gs.gc_threshold = 1024 * 1024
	return gs
}
NEW_THREAD :: proc(
	gs: ^GlobalState,
	stack_size: int,
	allocator := context.allocator,
) -> ^ThreadState {
	ts := new(ThreadState, allocator)
	ts.globals = gs
	ts.stack = make([dynamic]Value, stack_size, allocator)
	ts.call_stack = make([dynamic]VMFrame, allocator)
	ts.status = .OK
	ts.top = 0
	ts.base = 0
	ts.pc = 0
	return ts
}

