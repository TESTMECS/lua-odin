package ouau
import "core:fmt"
import "core:mem/virtual"
import "core:slice"
/*
	 ./state.odin
	 Copyright(C) 2025 TESTMEE
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
KEYWORDS := [22]struct {
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
	// Binary search for keyword, faster than switch statement.
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
	kind: Token, // Token kind like .IF or .EQ
	text: []u8, // literal lext like "if" or "=="
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
NODE_KIND :: enum u8 {
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
Precedence :: enum {
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
/* Interpreter State */
Frame :: struct {
	env:         ^Environment, // Hashable env of upvalues and locals
	return_addr: NODEID, // Return address of the frame
	result:      Value, // Result of the frame
}
Interpreter :: struct {
	globals:      map[string]Value, // Globals of the interpreter
	current:      ^Environment, // Current environment of the interpreter
	nodes:        ^NODES, // AST nodes of the interpreter
	call_stack:   [dynamic]^Frame, // Call stack of the interpreter
	arena:        ^virtual.Arena, // Arena of the interpreter
	using vtable: InterpreterVTable, // Interpreter functions
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
	values:  map[string]Value, /* Map of name -> value */
	sorted:  [dynamic]string, /* Sorted list of names */
	dirty:   bool, /* Dirty flag */
	outer:   ^Environment, /* Outer environment */
	varargs: [dynamic]Value, /* Varargs */
}
NEW_ENVIRONMENT :: proc(outer: ^Environment, varena: ^virtual.Arena) -> ^Environment {
	my_alloc := virtual.arena_allocator(varena)
	env := new(Environment, my_alloc)
	env.outer = outer
	env.values = make(map[string]Value, my_alloc)
	env.varargs = make([dynamic]Value, my_alloc)
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

