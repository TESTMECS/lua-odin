package ouau
import "core:mem"
import "core:mem/virtual"
/*
	 ./state.odin
	 Copyright(C) 2025 TESTMEE
	 Defines the global state shared across compilation/threads for Ouau.
		
	 <@Token, @TokenDefinition, @Lexer>

	<@NODEID, @NODE_KIND, @NODES, @Precedence, @Parser, @ParserVTable>

	 <@GlobalState, @String | >

	 <@Compiler, @Prototype, @UpValueDesc, @UpValue| Closure Resolutions.>

	 <@GCObject, @GCHeap, @GCState, @GC_HEADER|GC Heaps State.>

	 <@VMFrame, @CallInfo, @VM, @VM_Config|VM Configuration.>

	 <@Thread, @ThreadState, @ThreadStatus|Threads State.>
*/
Token :: enum u8 {
	EOF,
	ILLEGAL,
	// keywords
	DO,
	END,
	IN,
	WHILE,
	REPEAT,
	UNTIL,
	FOR,
	RETURN,
	IF,
	THEN,
	ELSE,
	ELSEIF,
	FUNCTION,
	LOCAL,
	GLOBAL,
	TRUE,
	FALSE,
	NIL,
	BREAK,
	OR,
	AND,
	NOT,
	// operators
	ASSIGN,
	PLUS,
	MINUS,
	MUL,
	DIV,
	MOD,
	POW,
	DOT,
	DOTDOT,
	COMMA,
	COLON,
	SEMI,
	LT,
	LE,
	GT,
	GE,
	EQ,
	NE,
	NEQ,
	LEQ,
	GEQ,
	OROR,
	ANDAND,
	SHL,
	SHR,
	TILDE,
	BXOR,
	POUND,
	DOTS,
	BAND,
	BOR,
	BANG,
	// punctuation
	OPEN,
	CLOSE,
	// other
	IDENTIFIER,
	NUMBER,
	STRING,
	TOPEN,
	TCLOSE,
	BOPEN,
	BCLOSE,
}
@(rodata)
KEYWORDS := [?]struct {
	// Must be sorted alphabetically
	text: string,
	kind: Token,
} {
	{"and", .AND},
	{"break", .BREAK},
	{"do", .DO},
	{"else", .ELSE},
	{"elseif", .ELSEIF},
	{"end", .END},
	{"false", .FALSE},
	{"for", .FOR},
	{"function", .FUNCTION},
	{"global", .GLOBAL},
	{"if", .IF},
	{"in", .IN},
	{"local", .LOCAL},
	{"nil", .NIL},
	{"not", .NOT},
	{"or", .OR},
	{"repeat", .REPEAT},
	{"return", .RETURN},
	{"then", .THEN},
	{"true", .TRUE},
	{"until", .UNTIL},
	{"while", .WHILE},
}
LOOKUP_KEYWORD :: proc(name: string) -> (ok: bool, kind: Token) {
	// binary search
	lo := 0
	hi := len(KEYWORDS) - 1
	for lo <= hi {
		mid := (lo + hi) >> 1
		entry := KEYWORDS[mid]
		if name < entry.text {
			hi = mid - 1
		} else if name > entry.text {
			lo = mid + 1
		} else {
			return true, entry.kind
		}
	}
	return false, .IDENTIFIER
}
TokenDefinition :: struct {
	kind: Token,
	text: []u8,
}
LexerVTable :: struct {
	NEXT: proc(l: ^Lexer) -> (TokenDefinition, OuauError),
	EAT:  proc(l: ^Lexer),
}
Lexer :: struct {
	input:        []u8,
	ch:           u8, //current character
	pos:          int,
	read_pos:     int,
	using vtable: LexerVTable,
}
@(require_results)
NEW_LEXER :: proc(input: string) -> Lexer {
	l := Lexer {
		ch       = 0,
		input    = transmute([]u8)input,
		pos      = 0,
		read_pos = 0,
		vtable   = LEXER_VTABLE,
	}
	l->EAT()
	return l
}
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
ParserVTable :: struct {
	ADVANCE:      proc(p: ^Parser) -> (err: OuauError),
	APPEND_CHILD: proc(p: ^Parser, parent, child: NODEID),
	IS:           proc(p: ^Parser, kind: Token) -> bool,
	EXPECT:       proc(p: ^Parser, kind: Token) -> (err: OuauError),
	GET_TEXT:     proc(p: ^Parser) -> (text: string),
	GET_TOKEN:    proc(p: ^Parser) -> (kind: Token),
	CHUNK:        proc(p: ^Parser) -> (NODEID, OuauError),
	BLOCK:        proc(p: ^Parser) -> (NODEID, OuauError),
	EXP:          proc(p: ^Parser) -> (expression: NODEID, err: OuauError),
	EXPLIST:      proc(p: ^Parser) -> (parsed_expressions: []NODEID, err: OuauError),
	STMT:         proc(p: ^Parser) -> (NODEID, OuauError),
	FUNCTION:     proc(p: ^Parser) -> (NODEID, OuauError),
	PREFIX:       proc(p: ^Parser) -> (NODEID, OuauError),
	TABLE:        proc(p: ^Parser) -> (NODEID, OuauError),
	UBLOCK:       proc(p: ^Parser) -> (NODEID, OuauError),
	PRIMARY:      proc(p: ^Parser) -> (NODEID, OuauError),
	INFIX:        proc(p: ^Parser, left_expression: NODEID) -> (NODEID, OuauError),
	PRECEDENCE:   proc(p: ^Parser, precedence: Precedence) -> (NODEID, OuauError),
	SET_NAME:     proc(p: ^Parser, node: NODEID, name: string) -> (err: OuauError),
	SET_STRING:   proc(p: ^Parser, node: NODEID, value: string) -> (err: OuauError),
	SET_INT:      proc(p: ^Parser, node: NODEID, value: i64) -> (err: OuauError),
	NEW_NODE:     proc(p: ^Parser, k: NODE_KIND) -> (new_nodeid: NODEID),
	SET_TOKEN:    proc(p: ^Parser, node: NODEID, token: Token),
}
Parser :: struct {
	pos:          int,
	nodes:        NODES,
	lexer:        Lexer,
	current:      TokenDefinition,
	peek:         TokenDefinition,
	arena:        ^virtual.Arena,
	using vtable: ParserVTable,
}
@(require_results)
NEW_PARSER :: proc(
	input: string,
	param_arena: ^virtual.Arena,
) -> (
	new_parser: Parser,
	err: OuauError,
) {
	new_parser = Parser {
		pos     = 0,
		arena   = param_arena,
		nodes   = NODES{},
		current = TokenDefinition{},
		peek    = TokenDefinition{},
		lexer   = NEW_LEXER(input),
		vtable  = PARSER_VTABLE,
	}
	// Initalize current and peek
	first_token := new_parser.lexer->NEXT() or_return
	new_parser.peek = first_token
	// Initalize Nodes
	varena := virtual.arena_allocator(param_arena)
	new_parser.nodes.kind = make([dynamic]NODE_KIND, varena)
	new_parser.nodes.first_child = make([dynamic]NODEID, varena)
	new_parser.nodes.next_sibling = make([dynamic]NODEID, varena)
	new_parser.nodes.token = make([dynamic]Token, varena)
	new_parser.nodes.int_value = make([dynamic]i64, varena)
	new_parser.nodes.string_value = make([dynamic]string, varena)
	new_parser.nodes.name = make([dynamic]string, varena)
	return new_parser, nil
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

