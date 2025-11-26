package ouau
import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:slice"
/*
	 ./state.odin
	 Copyright(C) 2025 TESTMEE
	 Defines all the state across lexing, parsing, evaluation, compilation, and VM for Ouau. 
*/
Token :: enum u8 {
	EOF,
	ILLEGAL,
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
	BAND,
	BOR,
	BANG,
	OPEN,
	CLOSE,
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
	// Must be sorted alphabetically for binary search to work.
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
	EAT:                          proc(l: ^Lexer),
	PEEK:                         proc(l: ^Lexer) -> u8,
	NEXT:                         proc(l: ^Lexer) -> (TokenDefinition, ^OuauError),
	GET_TOKEN:                    proc(
		l: ^Lexer,
		type: Token,
		start: int,
		length: int,
	) -> TokenDefinition,
	SKIP_WHITESPACE:              proc(l: ^Lexer),
	CREATE_NUMBER:                proc(l: ^Lexer) -> TokenDefinition,
	CREATE_IDENTIFIER_OR_KEYWORD: proc(l: ^Lexer) -> TokenDefinition,
	SYNTAX_ERROR:                 proc(
		l: ^Lexer,
		my_msg: string,
		token: TokenDefinition,
	) -> ^OuauError,
}
Lexer :: struct {
	input:        []u8,
	ch:           u8, //current character
	pos:          int,
	read_pos:     int,
	arena:        ^virtual.Arena,
	using vtable: LexerVTable,
}
@(require_results)
NEW_LEXER :: proc(input: string, varena: ^virtual.Arena) -> Lexer {
	l := Lexer {
		ch       = 0,
		input    = transmute([]u8)input,
		pos      = 0,
		read_pos = 0,
		arena    = varena,
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
}
NODES :: struct {
	kind:         [dynamic]NODE_KIND,
	first_child:  [dynamic]NODEID,
	next_sibling: [dynamic]NODEID,
	token:        [dynamic]Token,
	int_value:    [dynamic]f64,
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
	ADVANCE:      proc(p: ^Parser) -> (err: ^OuauError),
	APPEND_CHILD: proc(p: ^Parser, parent, child: NODEID),
	IS:           proc(p: ^Parser, kind: Token) -> bool,
	EXPECT:       proc(p: ^Parser, kind: Token) -> (err: ^OuauError),
	GET_TEXT:     proc(p: ^Parser) -> (text: string),
	GET_TOKEN:    proc(p: ^Parser) -> (kind: Token),
	CHUNK:        proc(p: ^Parser) -> (NODEID, ^OuauError),
	BLOCK:        proc(p: ^Parser) -> (NODEID, ^OuauError),
	EXP:          proc(p: ^Parser) -> (expression: NODEID, err: ^OuauError),
	EXPLIST:      proc(p: ^Parser) -> (parsed_expressions: []NODEID, err: ^OuauError),
	STMT:         proc(p: ^Parser) -> (NODEID, ^OuauError),
	FUNCTION:     proc(p: ^Parser) -> (NODEID, ^OuauError),
	PREFIX:       proc(p: ^Parser) -> (NODEID, ^OuauError),
	TABLE:        proc(p: ^Parser) -> (NODEID, ^OuauError),
	UBLOCK:       proc(p: ^Parser) -> (NODEID, ^OuauError),
	PRIMARY:      proc(p: ^Parser) -> (NODEID, ^OuauError),
	INFIX:        proc(p: ^Parser, left_expression: NODEID) -> (NODEID, ^OuauError),
	PRECEDENCE:   proc(p: ^Parser, precedence: Precedence) -> (NODEID, ^OuauError),
	SET_NAME:     proc(p: ^Parser, node: NODEID, name: string) -> (err: ^OuauError),
	SET_STRING:   proc(p: ^Parser, node: NODEID, value: string) -> (err: ^OuauError),
	SET_INT:      proc(p: ^Parser, node: NODEID, value: f64) -> (err: ^OuauError),
	NEW_NODE:     proc(p: ^Parser, k: NODE_KIND) -> (new_nodeid: NODEID),
	SET_TOKEN:    proc(p: ^Parser, node: NODEID, token: Token),
	PARSE_ERROR:  proc(p: ^Parser, msg: string) -> ^OuauError,
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
	err: ^OuauError,
) {
	new_parser = Parser {
		pos     = 0,
		arena   = param_arena,
		nodes   = NODES{},
		current = TokenDefinition{},
		peek    = TokenDefinition{},
		lexer   = NEW_LEXER(input, param_arena),
		vtable  = PARSER_VTABLE,
	}
	// Initalize nodes
	my_alloc := virtual.arena_allocator(param_arena)
	new_parser.nodes.kind = make([dynamic]NODE_KIND, my_alloc)
	new_parser.nodes.first_child = make([dynamic]NODEID, my_alloc)
	new_parser.nodes.next_sibling = make([dynamic]NODEID, my_alloc)
	new_parser.nodes.token = make([dynamic]Token, my_alloc)
	new_parser.nodes.int_value = make([dynamic]f64, my_alloc)
	new_parser.nodes.string_value = make([dynamic]string, my_alloc)
	new_parser.nodes.name = make([dynamic]string, my_alloc)
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
Frame :: struct {
	env:         ^Environment,
	return_addr: NODEID,
	result:      Value,
}
InterpreterVTable :: struct {
	INTERPRET:   proc(i: ^Interpreter, root: NODEID) -> (result: Value),
	EVAL:        proc(i: ^Interpreter, node: NODEID) -> Value,
	ASSIGN:      proc(i: ^Interpreter, node: NODEID) -> Value,
	GET_CHILD:   proc(i: ^Interpreter, node: NODEID) -> NODEID,
	GET_GCHILD:  proc(i: ^Interpreter, node: NODEID) -> NODEID,
	GET_SIBLING: proc(i: ^Interpreter, node: NODEID) -> NODEID,
	EVAL_ERROR:  proc(i: ^Interpreter, msg: string) -> ^OuauError,
}
Interpreter :: struct {
	globals:      map[string]Value,
	current:      ^Environment,
	nodes:        ^NODES,
	call_stack:   [dynamic]^Frame,
	arena:        ^virtual.Arena,
	using vtable: InterpreterVTable,
}
@(require_results)
NEW_INTERPRETER :: proc(nodes: ^NODES, varena: ^virtual.Arena) -> Interpreter {
	my_alloc := virtual.arena_allocator(varena)
	i := Interpreter {
		globals    = make(map[string]Value, my_alloc),
		current    = NEW_ENVIRONMENT(nil, varena),
		call_stack = make([dynamic]^Frame, my_alloc),
		arena      = varena,
		nodes      = nodes,
		vtable     = INTERPRETER_VTABLE,
	}
	INIT_BUILTINS(&i, varena)
	return i
}
INIT_BUILTINS :: proc(i: ^Interpreter, varena: ^virtual.Arena) {
	my_alloc := virtual.arena_allocator(varena)
	print_fn := new(Closure, my_alloc)
	print_fn.is_native = true
	print_fn.native_proc = BUILTIN_PRINT
	i.globals["print"] = print_fn
}
BUILTIN_PRINT :: proc(args: []Value) -> Value {
	for arg in args {
		fmt.print(arg)
	}
	fmt.println()
	return nil
}
Environment :: struct {
	values:  map[string]Value,
	sorted:  [dynamic]string,
	dirty:   bool,
	outer:   ^Environment,
	varargs: []Value,
}
NEW_ENVIRONMENT :: proc(outer: ^Environment, varena: ^virtual.Arena) -> ^Environment {
	my_alloc := virtual.arena_allocator(varena)
	env := new(Environment, my_alloc)
	env.outer = outer
	env.values = make(map[string]Value, my_alloc)
	return env
}
ENV_GET :: proc(env: ^Environment, name: string) -> (Value, bool) {
	my_env := env // assign to local to avoid shadowing.
	for my_env != nil {
		if v, ok := my_env.values[name]; ok {
			return v, true
		}
		my_env = my_env.outer
	}
	return nil, false
}
ENV_SET :: proc(env: ^Environment, name: string, v: Value) {
	env.values[name] = v
	env.dirty = true
}
ENV_SET_UPWARD :: proc(env: ^Environment, name: string, v: Value) {
	my_env := env // assign to local to avoid shadowing.
	for my_env != nil {
		if _, ok := my_env.values[name]; ok {
			my_env.values[name] = v
			my_env.dirty = true
			return
		}
		my_env = my_env.outer
	}
	env.values[name] = v
	env.dirty = true
}
ENV_RESORT :: proc(env: ^Environment) {
	if !env.dirty do return
	env_len := len(env.sorted)
	clear(&env.sorted)
	resize(&env.sorted, env_len)
	for k in env.values {
		append(&env.sorted, k)
	}
	slice.sort_by(env.sorted[:], proc(a, b: string) -> bool {
		return a < b
	})
	env.dirty = false
}
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
	arena:        ^virtual.Arena,
}
@(require_results)
NEW_COMPILER :: proc(my_nodes: ^NODES, arena: ^virtual.Arena) -> ^Compiler {
	my_alloc := virtual.arena_allocator(arena)
	c := new(Compiler)
	c.nodes = my_nodes
	c.constants = make([dynamic]Value, my_alloc)
	c.const_index = make(map[Value]int, my_alloc)
	c.locals = make(map[string]int, my_alloc)
	c.upvalues = make(map[string]int, my_alloc)
	c.free_regs = make([dynamic]int, my_alloc)
	c.prototypes = make([dynamic]^Prototype, my_alloc)
	c.parent = nil
	return c
}
Prototype :: struct {
	instructions: [dynamic]u32,
	constants:    [dynamic]Value,
	proto:        [dynamic]^Prototype,
	upvalues:     [dynamic]^UpValueDesc,
	max_stack:    int,
	num_params:   int,
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

