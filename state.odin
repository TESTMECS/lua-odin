package ouau
import "core:mem"
import "core:mem/virtual"
/*
	 ./state.odin
	 Copyright(C) 2025 TESTMEE
	 Defines the global state shared across compilation/threads for Ouau.

		<@NODEID, @NODE_KIND, @NODES, @Precedence, @Parser>

	 <@GlobalState, @String | >

	 <@Compiler, @Prototype, @UpValueDesc, @UpValue| Closure Resolutions.>

	 <@GCObject, @GCHeap, @GCState, @GC_HEADER|GC Heaps State.>

	 <@VMFrame, @CallInfo, @VM, @VM_Config|VM Configuration.>

	 <@Thread, @ThreadState, @ThreadStatus|Threads State.>
*/
NODEID :: u32
NODE_KIND :: enum {
	INVALID,
	BLOCK,
	UBLOCK,
	IF,
	WHILE,
	ASSIGN,
	FUNCTION,
	CALL,
	LITERAL,
	IDENTIFIER,
	UNARY,
	BINARY,
	STRING,
	GLOBAL,
	TABLE,
	REPEAT,
	DO,
	FOR,
	LOCAL,
	RETURN,
	BREAK,
	VARARGS,
	UPVALUE,
}
NODES :: struct {
	kind:         [dynamic]NODE_KIND,
	first_child:  [dynamic]NODEID,
	next_sibling: [dynamic]NODEID,
	token:        [dynamic]Token,
	int_value:    [dynamic]i64,
	string_value: [dynamic]string,
	name:         [dynamic]string,
}
Precedence :: enum u8 {
	LOWEST,
	ASSIGN,
	EQUALS,
	LESSGREATER,
	SUM,
	PRODUCT,
	PREFIX,
	CALL,
	INDEX,
}
Parser :: struct {
	pos:                        int,
	nodes:                      NODES,
	lexer:                      Lexer,
	current:                    TokenDefinition,
	peek:                       TokenDefinition,
	arena:                      ^virtual.Arena,
	ADVANCE:                    proc(p: ^Parser, description := "") -> (err: OuauError),
	EXPECT:                     proc(p: ^Parser, kind: Token) -> (err: OuauError),
	IS_TERMINAL:                proc(p: ^Parser) -> bool,
	PARSE_CHUNK:                proc(p: ^Parser) -> (NODEID, OuauError),
	PARSE_BLOCK:                proc(p: ^Parser) -> (NODEID, OuauError),
	PARSE_STMT:                 proc(p: ^Parser) -> (NODEID, OuauError),
	PARSE_WHILE:                proc(p: ^Parser) -> (NODEID, OuauError),
	PARSE_REPEAT:               proc(p: ^Parser) -> (NODEID, OuauError),
	PARSE_DO:                   proc(p: ^Parser) -> (NODEID, OuauError),
	PARSE_IF:                   proc(p: ^Parser) -> (NODEID, OuauError),
	PARSE_FUNCTION:             proc(p: ^Parser) -> (NODEID, OuauError),
	PARSE_FOR:                  proc(p: ^Parser) -> (NODEID, OuauError),
	PARSE_LOCAL:                proc(p: ^Parser) -> (NODEID, OuauError),
	PARSE_GLOBAL:               proc(p: ^Parser) -> (NODEID, OuauError),
	PARSE_BREAK:                proc(p: ^Parser) -> (NODEID, OuauError),
	PARSE_RETURN:               proc(p: ^Parser) -> (NODEID, OuauError),
	PARSE_CALL:                 proc(p: ^Parser) -> (NODEID, OuauError),
	PARSE_EXPRESSION_STATEMENT: proc(p: ^Parser) -> (NODEID, OuauError),
	PARSE_PREFIX_EXP:           proc(p: ^Parser) -> (NODEID, OuauError),
	PARSE_TABLE:                proc(p: ^Parser) -> (NODEID, OuauError),
	PARSE_UBLOCK:               proc(p: ^Parser) -> (NODEID, OuauError),
	PARSE_PRIMARY:              proc(p: ^Parser) -> (NODEID, OuauError),
	PARSE_INFIX:                proc(p: ^Parser, left_expression: NODEID) -> (NODEID, OuauError),
	PARSE_PRECEDENCE:           proc(p: ^Parser, precedence: Precedence) -> (NODEID, OuauError),
	NEW_NODE:                   proc(p: ^Parser, k: NODE_KIND) -> (new_nodeid: NODEID),
	PARSE_EXP:                  proc(p: ^Parser) -> (expression: NODEID, err: OuauError),
	PARSE_EXPLIST:              proc(p: ^Parser) -> (parsed_expressions: []NODEID, err: OuauError),
	GET_CURRENT_TEXT:           proc(p: ^Parser) -> (text: string),
	CURRENT_IS_KIND:            proc(p: ^Parser, kind: Token) -> bool,
	SET_NODEID_TOKEN:           proc(p: ^Parser, node: NODEID, token: Token),
	ADD_NODEID_CHILD:           proc(p: ^Parser, parent, child: NODEID),
}

@(rodata)
PRECEDENCES := #partial [Token]Precedence {
	.ASSIGN = .ASSIGN,
	.EQ     = .EQUALS,
	.NE     = .EQUALS,
	.NEQ    = .EQUALS,
	.LE     = .LESSGREATER,
	.LT     = .LESSGREATER,
	.GE     = .LESSGREATER,
	.GT     = .LESSGREATER,
	.PLUS   = .SUM,
	.MINUS  = .SUM,
	.MUL    = .PRODUCT,
	.DIV    = .PRODUCT,
	.MOD    = .PRODUCT,
	.POW    = .PRODUCT,
	.POUND  = .PREFIX,
	.OPEN   = .CALL,
	.DOT    = .CALL,
	.BOPEN  = .INDEX,
	.BCLOSE = .LOWEST,
}
STACK_LIMIT :: 1024 * 1024

GlobalState :: struct {
	thread:      ^ThreadState, // Main Thread
	globals:     ^Table, // Global Table
	debug_level: int,
	builtins:    [dynamic]^Table, // builtin functions
	panic:       proc(state: ^ThreadState, msg: string, level: int),
}

@(require_results)
NEW_GLOBAL_STATE :: proc(allocator := context.allocator) -> ^GlobalState {
	gs := new(GlobalState, allocator)
	gs.builtins = make([dynamic]^Table, allocator)
	gs.globals = NEW_TABLE(allocator)
	return gs
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
	// Debug
	debug_level:  int, // 0 = off, 1 = basic, 2 = full, 3 = trace
	trace_gc:     bool,
	trace_stack:  bool,
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

