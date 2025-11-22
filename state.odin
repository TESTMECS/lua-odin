package ouau
import "core:mem"
/*
	 ./state.odin
	 Copyright(C) 2025 TESTMEE
	 Defines the global state shared across compilation/threads for Ouau.

	 <@GlobalState, @StringTable, @String|String Interning Helpers.>

	 <@Compiler, @Prototype, @UpValueDesc, @UpValue| Closure Resolutions.>

	 <@GCObject, @GCHeap, @GCState, @GC_HEADER|GC Heaps State.>

	 <@VMFrame, @CallInfo, @VM, @VM_Config|VM Configuration.>

	 <@Thread, @ThreadState, @ThreadStatus|Threads State.>
*/
STACK_LIMIT :: 1024 * 1024

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

@(require_results)
NEW_GLOBAL_STATE :: proc(allocator := context.allocator) -> ^GlobalState {
	gs := new(GlobalState, allocator)
	gs.builtins = make([dynamic]^Table, allocator)
	gs.string_table.hash = make([dynamic]^String, allocator)
	gs.string_table.size = 0
	gs.string_table.count = 0
	gs.gc = NEW_GC_HEAP(allocator)
	gs.registry = NEW_TABLE(allocator)
	gs.globals = NEW_TABLE(allocator)
	gs.gc_threshold = 1024 * 1024
	return gs
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
} // <<=
Compiler :: struct {
	instructions: [dynamic]u32,
	constants:    [dynamic]Value, // pool for LoadK
	const_index:  map[Value]int, // equality hashing
	locals:       map[string]int, // name -> register
	upvalues:     map[string]int, // name -> upval index
	nodes:        ^NODES,
	max_stack:    int,
	nparams:      int,
	local_count:  int, // next free register
	free_regs:    [dynamic]int, // stack of freed reg indices
	prototypes:   [dynamic]^Prototype, // nested function prototypes
	parent:       ^Prototype, // upvalue resolution
}
@(require_results)
NEW_COMPILER :: proc(bytecode: ^NODES, allocator := context.allocator) -> ^Compiler {
	c := new(Compiler, allocator)
	c.nodes = bytecode
	c.constants = make([dynamic]Value, allocator)
	c.const_index = make(map[Value]int, allocator)
	c.locals = make(map[string]int, allocator)
	c.upvalues = make(map[string]int, allocator)
	c.free_regs = make([dynamic]int, allocator)
	c.parent = nil
	return c
}
Prototype :: struct {
	using header: GC_HEADER,
	instructions: []u32,
	constants:    []Value,
	proto:        []^Prototype,
	upvalues:     [dynamic]^UpValueDesc,
	max_stack:    int,
	num_params:   int,
}
//=>> GC
GCType :: enum u8 {
	STRING,
	TABLE,
	CLOSURE,
	UPVALUE,
	PROTOTYPE,
	THREAD,
}

GC_HEADER :: struct {
	marked:     bool,
	generation: u8, // 0 = young, 1 = old
	gctype:     GCType,
}

GCObject :: struct {
	using header: GC_HEADER,
}
GC_HEAP :: struct {
	young:          [dynamic]^GCObject,
	old:            [dynamic]^GCObject,
	remembered_set: [dynamic]^GCObject, // for generational WB
	gray:           [dynamic]^GCObject, // mark queue
	state:          GC_STATE,
}
GC_STATE :: enum u8 {
	IDLE,
	MARK,
	SWEEP,
}
@(require_results)
NEW_GC_HEAP :: proc(allocator := context.allocator) -> ^GC_HEAP {
	heap := new(GC_HEAP, allocator)
	heap.young = make([dynamic]^GCObject, allocator)
	heap.old = make([dynamic]^GCObject, allocator)
	heap.remembered_set = make([dynamic]^GCObject, allocator)
	heap.gray = make([dynamic]^GCObject, allocator)
	return heap
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
@(require_results)
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
VM_Config :: struct {
	stack_size:   int,
	call_depth:   int,
	gc_threshold: int,
	max_threads:  int,
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
@(require_results)
NEW_THREAD :: proc(
	gs: ^GlobalState,
	stack_size: int,
	allocator := context.allocator,
) -> ^ThreadState {
	ts := new(ThreadState, allocator)
	ts.globals = gs
	ts.stack = make([dynamic]Value, allocator)
	resize(&ts.stack, stack_size)
	ts.call_stack = make([dynamic]VMFrame, allocator)
	ts.status = .OK
	ts.top = 0
	ts.base = 0
	ts.pc = 0
	ts.call_count = 0
	return ts
}

