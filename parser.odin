package ouau
import "core:log"
import "core:mem/virtual"
import "core:strconv"
/*
	 ./parser.odin
	 Copyright(C) 2025 TESTMEE
	 This file defines the parser functions for Ouau.
	 @NODEID, @NODE_KIND, @NODES, @Precedence, @Parser
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
@(require_results)
NEW_PARSER :: proc(
	input: string,
	param_arena: ^virtual.Arena,
) -> (
	new_parser: Parser,
	err: OuauError,
) {
	new_parser = Parser {
		pos                        = 0,
		arena                      = param_arena,
		nodes                      = NODES{},
		current                    = TokenDefinition{},
		peek                       = TokenDefinition{},
		lexer                      = NEW_LEXER(input),
		ADVANCE                    = ADVANCE,
		EXPECT                     = EXPECT,
		NEW_NODE                   = NEW_NODE,
		PARSE_BLOCK                = PARSE_BLOCK,
		PARSE_CHUNK                = PARSE_CHUNK,
		PARSE_EXP                  = PARSE_EXP,
		PARSE_EXPLIST              = PARSE_EXPLIST,
		PARSE_STMT                 = PARSE_STMT,
		PARSE_WHILE                = PARSE_WHILE,
		PARSE_REPEAT               = PARSE_REPEAT,
		PARSE_DO                   = PARSE_DO,
		PARSE_IF                   = PARSE_IF,
		PARSE_FUNCTION             = PARSE_FUNCTION,
		PARSE_FOR                  = PARSE_FOR,
		PARSE_LOCAL                = PARSE_LOCAL,
		PARSE_GLOBAL               = PARSE_GLOBAL,
		PARSE_BREAK                = PARSE_BREAK,
		PARSE_RETURN               = PARSE_RETURN,
		PARSE_CALL                 = PARSE_CALL,
		PARSE_EXPRESSION_STATEMENT = PARSE_EXPRESSION_STATEMENT,
		PARSE_UBLOCK               = PARSE_UBLOCK,
		PARSE_PREFIX_EXP           = PARSE_PREFIX_EXP,
		PARSE_TABLE                = PARSE_TABLE,
		PARSE_PRIMARY              = PARSE_PRIMARY,
		PARSE_INFIX                = PARSE_INFIX,
		PARSE_PRECEDENCE           = PARSE_PRECEDENCE,
		CURRENT_IS_KIND            = CURRENT_IS_KIND,
		GET_CURRENT_TEXT           = GET_CURRENT_TEXT,
		SET_NODEID_TOKEN           = SET_NODEID_TOKEN,
		ADD_NODEID_CHILD           = ADD_NODEID_CHILD,
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
@(require_results)
ADVANCE :: proc(p: ^Parser, description := "") -> (err: OuauError) {
	p.current = p.peek
	next_token := p.lexer->NEXT() or_return
	log.infof("ADVANCE::peek=%v, next_token=%v", p.peek.kind, next_token.kind)
	p.peek = next_token
	return nil
}
@(require_results)
PARSE_CHUNK :: proc(p: ^Parser) -> (chunk_node: NODEID, err: OuauError) {
	log.infof("PARSE_CHUNK::starting")
	p->ADVANCE() or_return
	log.infof("PARSE_CHUNK::p.current::tok[0]=%v", p.current.kind)
	p->ADVANCE("p.current::tok[0]") or_return
	chunk_node = p->PARSE_BLOCK() or_return
	return chunk_node, nil
}
@(private = "file", require_results)
NEW_NODE :: proc(p: ^Parser, k: NODE_KIND) -> (new_nodeid: NODEID) {
	new_nodeid = cast(NODEID)len(p.nodes.kind)
	append(&p.nodes.kind, k)
	append(&p.nodes.first_child, NODEID(0))
	append(&p.nodes.next_sibling, NODEID(0))
	append(&p.nodes.token, Token{})
	append(&p.nodes.int_value, 0)
	append(&p.nodes.string_value, "")
	append(&p.nodes.name, "")
	return
}
@(private = "file")
ADD_NODEID_CHILD :: proc(p: ^Parser, parent, child: NODEID) {
	if p.nodes.first_child[parent] == 0 {
		p.nodes.first_child[parent] = child
	} else {
		n := p.nodes.first_child[parent]
		for p.nodes.next_sibling[n] != 0 {
			n = p.nodes.next_sibling[n]
		}
		p.nodes.next_sibling[n] = child
	}
}
@(private = "file", require_results)
EXPECT :: proc(p: ^Parser, kind: Token) -> (err: OuauError) {
	if p->CURRENT_IS_KIND(kind) {
		return p->ADVANCE()
	}
	return nil
}
@(private = "file")
IS_TERMINAL :: proc(p: ^Parser) -> bool {
	return(
		p.current.kind == .SEMI ||
		p.current.kind == .END ||
		p.current.kind == .ELSE ||
		p.current.kind == .ELSEIF ||
		p.current.kind == .EOF ||
		p.current.kind == .ILLEGAL \
	)
}
@(private = "file", require_results)
PARSE_BLOCK :: proc(p: ^Parser) -> (block_node: NODEID, err: OuauError) {
	block_node = p->NEW_NODE(.BLOCK)
	log.info("PARSE_BLOCK::starting", p.current.kind)
	// segfault here?
	for !p->IS_TERMINAL() {
		#partial switch p.current.kind {
		case .SEMI, .END, .ELSE, .ELSEIF:
			p->ADVANCE() or_return
			continue
		case .EOF, .ILLEGAL:
			return block_node, GET_PARSE_ERROR(p, "PARSE_BLOCK::Unexpected teriminal::()")
		case:
			child := p->PARSE_STMT() or_return
			p->ADD_NODEID_CHILD(block_node, child)
		}
	}
	return block_node, nil
}
@(private = "file", require_results)
PARSE_STMT :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	tk := p.current.kind
	#partial switch tk {
	case .WHILE:
		node = p->PARSE_WHILE() or_return
	case .REPEAT:
		node = p->PARSE_REPEAT() or_return
	case .DO:
		node = p->PARSE_DO() or_return
	case .IF:
		node = p->PARSE_IF() or_return
	case .FUNCTION:
		node = p->PARSE_FUNCTION() or_return
	case .FOR:
		node = p->PARSE_FOR() or_return
	case .LOCAL:
		node = p->PARSE_LOCAL() or_return
	case .GLOBAL:
		node = p->PARSE_GLOBAL() or_return
	case .BREAK:
		node = p->PARSE_BREAK() or_return
	case .RETURN:
		node = p->PARSE_RETURN() or_return
	case .OPEN:
		node = p->PARSE_CALL() or_return
	case:
		node = p->PARSE_EXPRESSION_STATEMENT() or_return
	}
	return node, nil
}
@(private = "file", require_results)
PARSE_CALL :: proc(p: ^Parser) -> (call_node: NODEID, err: OuauError) {
	p->EXPECT(.OPEN) or_return
	args := p->PARSE_EXPLIST() or_return
	p->EXPECT(.CLOSE) or_return
	call_node = p->NEW_NODE(.CALL)
	for arg in args { p->ADD_NODEID_CHILD(call_node, arg) }
	return call_node, nil
}
@(private = "file", require_results)
PARSE_WHILE :: proc(p: ^Parser) -> (while_node: NODEID, err: OuauError) {
	p->EXPECT(.WHILE) or_return
	while_node = p->NEW_NODE(.WHILE)
	cond := p->PARSE_EXP() or_return
	p->EXPECT(.DO) or_return
	body := p->PARSE_BLOCK() or_return
	p->EXPECT(.END) or_return
	p->ADD_NODEID_CHILD(while_node, cond)
	p->ADD_NODEID_CHILD(while_node, body)
	return while_node, nil
}
@(private = "file", require_results)
PARSE_IF :: proc(p: ^Parser) -> (if_node: NODEID, err: OuauError) {
	p->EXPECT(.IF) or_return
	if_node = p->NEW_NODE(.IF)
	cond := p->PARSE_EXP() or_return
	p->EXPECT(.THEN) or_return
	blk := p->PARSE_BLOCK() or_return
	p->ADD_NODEID_CHILD(if_node, cond)
	p->ADD_NODEID_CHILD(if_node, blk)
	for p.current.kind == .ELSEIF {
		p->ADVANCE() or_return
		econd := p->PARSE_EXP() or_return
		p->EXPECT(.THEN) or_return
		eblk := p->PARSE_BLOCK() or_return
		p->ADD_NODEID_CHILD(if_node, econd)
		p->ADD_NODEID_CHILD(if_node, eblk)
	}
	if p.current.kind == .ELSE {
		p->ADVANCE() or_return
		eblk := p->PARSE_BLOCK() or_return
		p->ADD_NODEID_CHILD(if_node, eblk)
	}
	p->EXPECT(.END) or_return
	return if_node, nil
}
@(private = "file", require_results)
PARSE_EXP :: proc(p: ^Parser) -> (expression: NODEID, err: OuauError) {
	expression = p->PARSE_PRECEDENCE(.LOWEST) or_return
	return
}
@(private = "file", require_results)
PARSE_PRECEDENCE :: proc(
	p: ^Parser,
	precedence: Precedence,
) -> (
	left_expression: NODEID,
	err: OuauError,
) {
	left_expression = p->PARSE_PREFIX_EXP() or_return
	for {
		current_prec := GET_PRECEDENCE(p.current.kind)
		if precedence >= current_prec do break
		left_expression = p->PARSE_INFIX(left_expression) or_return
	}
	return
}
@(private = "file")
GET_PRECEDENCE :: proc(tok: Token) -> Precedence {
	#partial switch tok {
	case .ASSIGN:
		return .ASSIGN
	case .EQ, .NEQ, .LT, .LE, .GT, .GE:
		return .EQUALS
	case .PLUS, .MINUS:
		return .SUM
	case .SHR, .SHL:
		return .SUM
	case .TILDE:
		return .EQUALS
	case .BAND:
		return .EQUALS
	case .BOR, .BXOR:
		return .EQUALS
	case .MUL, .DIV, .MOD:
		return .PRODUCT
	case .OR, .OROR:
		return .EQUALS
	case .AND, .ANDAND:
		return .EQUALS
	case .POW:
		return .CALL
	case .OPEN:
		return .CALL
	case .BANG:
		return .PREFIX
	case .POUND:
		return .PREFIX
	case .DOT:
		return .CALL
	case .BOPEN:
		return .INDEX
	case:
		return .LOWEST
	}
}
@(private = "file", require_results)
PARSE_INFIX :: proc(p: ^Parser, left_expression: NODEID) -> (infix_node: NODEID, err: OuauError) {
	token := p.current.kind
	#partial switch token {
	case .OPEN:
		p->ADVANCE() or_return
		args := make([dynamic]NODEID)
		if p.current.kind != .CLOSE { 	// TODO: bad grammar
			tmp_expression := p->PARSE_EXP() or_return
			append(&args, tmp_expression)
			for p.current.kind == .COMMA {
				p->ADVANCE() or_return
				tmp_expression := p->PARSE_EXP() or_return
				append(&args, tmp_expression)
			}
		}
		p->EXPECT(.CLOSE) or_return
		infix_node = p->NEW_NODE(.CALL) // create node
		p->ADD_NODEID_CHILD(infix_node, left_expression)
		for arg in args {
			p->ADD_NODEID_CHILD(infix_node, arg)
		}
		return infix_node, nil
	case .DOT:
		p->ADVANCE() or_return
		if p.current.kind == .IDENTIFIER { 	// TODO: bad grammar
			right_expression := p->NEW_NODE(.IDENTIFIER)
			p.nodes.name[right_expression] = p->GET_CURRENT_TEXT()
			p->ADVANCE() or_return
			infix_node := p->NEW_NODE(.BINARY)
			p.nodes.token[infix_node] = token // TODO: bad grammar
			p->ADD_NODEID_CHILD(infix_node, left_expression)
			p->ADD_NODEID_CHILD(infix_node, right_expression)
			return infix_node, nil
		}
	case .BOPEN:
		p->ADVANCE() or_return
		right_expression := p->PARSE_PRECEDENCE(.LOWEST) or_return
		p->EXPECT(.BCLOSE) or_return
		infix_node := p->NEW_NODE(.BINARY)
		p.nodes.token[infix_node] = token
		p->ADD_NODEID_CHILD(infix_node, left_expression)
		p->ADD_NODEID_CHILD(infix_node, right_expression)
		return infix_node, nil
	}
	p->ADVANCE() or_return
	right_expression := p->PARSE_PRECEDENCE(GET_PRECEDENCE(token)) or_return
	infix_node = p->NEW_NODE(.BINARY)
	p.nodes.token[infix_node] = token // TODO: bad grammar
	p->ADD_NODEID_CHILD(infix_node, left_expression)
	p->ADD_NODEID_CHILD(infix_node, right_expression)
	return infix_node, nil
}
@(private = "file", require_results)
PARSE_PRIMARY :: proc(p: ^Parser) -> (primary_node: NODEID, err: OuauError) {
	token_kind := p.current.kind
	#partial switch token_kind {
	case .NUMBER:
		primary_node = p->NEW_NODE(.LITERAL)
		val, _ := strconv.parse_i64(p->GET_CURRENT_TEXT())
		p.nodes.int_value[primary_node] = val
		p->ADVANCE() or_return
		return primary_node, nil
	case .STRING:
		primary_node = p->NEW_NODE(.STRING)
		p.nodes.string_value[primary_node] = p->GET_CURRENT_TEXT()
		p->ADVANCE() or_return
		return primary_node, nil
	case .IDENTIFIER:
		primary_node := p->NEW_NODE(.IDENTIFIER)
		p.nodes.name[primary_node] = p->GET_CURRENT_TEXT()
		p->ADVANCE() or_return
		return primary_node, nil
	case .NIL, .TRUE, .FALSE:
		primary_node = p->NEW_NODE(.LITERAL)
		p.nodes.string_value[primary_node] = p->GET_CURRENT_TEXT()
		p->ADVANCE() or_return
		return primary_node, nil
	case .OPEN:
		p->ADVANCE() or_return
		primary_expr := p->PARSE_EXP() or_return
		p->EXPECT(.CLOSE) or_return
		primary_node = primary_expr
		return primary_node, nil
	case .TOPEN:
		primary_node = p->PARSE_TABLE() or_return
		return primary_node, nil
	case:
	}
	return p->NEW_NODE(.INVALID), nil
}
@(private = "file", require_results)
PARSE_EXPRESSION_STATEMENT :: proc(p: ^Parser) -> (left_expression: NODEID, err: OuauError) {
	left_expression = p->PARSE_EXP() or_return
	if p->CURRENT_IS_KIND(.ASSIGN) {
		p->ADVANCE() or_return
		right_expression := p->PARSE_EXPLIST() or_return
		assign_node := p->NEW_NODE(.ASSIGN)
		p->ADD_NODEID_CHILD(assign_node, left_expression)
		for expr in right_expression {
			p->ADD_NODEID_CHILD(assign_node, expr)
		}
		return
	}
	return
}
@(private = "file")
PEEK_PRECEDENCE :: proc(p: ^Parser) -> Precedence {
	return PRECEDENCES[p.peek.kind]
}
@(private = "file")
SET_NODEID_TOKEN :: proc(p: ^Parser, node: NODEID, token: Token) {
	p.nodes.token[node] = token
}
@(private = "file", require_results)
PARSE_PREFIX_EXP :: proc(p: ^Parser) -> (prefix_node: NODEID, err: OuauError) {
	#partial switch p.current.kind {
	case .NOT, .MINUS, .POUND, .BANG:
		unary_node := p->NEW_NODE(.UNARY)
		p->SET_NODEID_TOKEN(unary_node, p.current.kind)
		p->ADVANCE("past unary operator") or_return
		right_expression := p->PARSE_PREFIX_EXP() or_return
		p->ADD_NODEID_CHILD(unary_node, right_expression)
		prefix_node = unary_node
		return prefix_node, nil
	case:
		prefix_node = p->PARSE_PRIMARY() or_return
	}
	return prefix_node, nil
}
@(private = "file", require_results)
PARSE_EXPLIST :: proc(p: ^Parser) -> (parsed_expressions: []NODEID, err: OuauError) {
	my_alloc := virtual.arena_allocator(p.arena)
	list_of_expr := make([dynamic]NODEID, 0, my_alloc)

	expression_node := p->PARSE_EXP() or_return
	log.infof("PARSE_EXPLIST::expression_node(%v)", expression_node)
	append(&list_of_expr, expression_node)

	log.infof("PARSE_EXPLIST::parsed_expressions(%v)", p.current.kind)
	#partial switch p.current.kind {
	case .COMMA:
		for p->CURRENT_IS_KIND(.COMMA) {
			p->ADVANCE() or_return
			expression_node = p->PARSE_EXP() or_return
			append(&list_of_expr, expression_node)
		}
		parsed_expressions = list_of_expr[:]
		return parsed_expressions, nil
	case:
		log.infof("PARSE_EXPLIST::parsed_expressions(%v)", list_of_expr)
		parsed_expressions = list_of_expr[:]
		log.infof("PARSE_EXPLIST::parsed_expressions(%v)", parsed_expressions)
		return parsed_expressions, nil
	}
	err = GET_PARSE_ERROR(p, "PARSE_EXPLIST::parsed_expressions")
	return parsed_expressions, err
}
@(private = "file", require_results)
PARSE_REPEAT :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	p->EXPECT(.REPEAT) or_return
	node = p->NEW_NODE(.REPEAT)
	ublock := p->PARSE_UBLOCK() or_return
	p->ADD_NODEID_CHILD(node, ublock)
	return node, nil
}
@(private = "file", require_results)
PARSE_UBLOCK :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	block := p->NEW_NODE(.BLOCK)
	for {
		#partial switch p.current.kind {
		case .SEMI:
			p->ADVANCE() or_return
			continue
		case .UNTIL:
			break
		case:
			child := p->PARSE_STMT() or_return
			p->ADD_NODEID_CHILD(block, child)
		}
	}
	p->EXPECT(.UNTIL) or_return
	cond := p->PARSE_EXP() or_return
	node = p->NEW_NODE(.UBLOCK)
	p->ADD_NODEID_CHILD(node, block)
	p->ADD_NODEID_CHILD(node, cond)
	return node, nil
}
@(private = "file", require_results)
PARSE_DO :: proc(p: ^Parser) -> (do_block_body: NODEID, err: OuauError) {
	log.infof("PARSE_DO::starting")
	log.infof("PARSE_DO::p.current::tok[0]=%v", p.current.kind)
	p->EXPECT(.DO) or_return
	log.infof("PARSE_DO::p.current::tok[0]=%v", p.current.kind)
	do_block_body = p->PARSE_BLOCK() or_return // segfault here.
	log.infof("PARSE_DO::p.current::tok[0]=%v", p.current.kind)
	p->EXPECT(.END) or_return
	return do_block_body, nil
}

@(private = "file", require_results)
PARSE_FUNCTION :: proc(p: ^Parser) -> (function_node: NODEID, err: OuauError) {
	log.infof("PARSE_FUNCTION::starting")
	p->EXPECT(.FUNCTION) or_return
	function_name := p->GET_CURRENT_TEXT()
	log.infof("PARSE_FUNCTION::name=%v", function_name)
	function_node = p->NEW_NODE(.FUNCTION)
	SET_NODE_NAME(p, function_node, function_name)
	p->ADVANCE("past 'function name'") or_return
	if p->CURRENT_IS_KIND(.OPEN) {
		log.infof("PARSE_FUNCTION::parsing parameters")
		p->ADVANCE("past '(' ") or_return
		if !p->CURRENT_IS_KIND(.CLOSE) {
			for !p->CURRENT_IS_KIND(.CLOSE) {
				log.infof("PARSE_FUNCTION::param loop, current=%v", p.current.kind)
				#partial switch p.current.kind {
				case .IDENTIFIER:
					function_parameter := p->NEW_NODE(.IDENTIFIER)
					p.nodes.name[function_parameter] = p->GET_CURRENT_TEXT()
					p->ADD_NODEID_CHILD(function_node, function_parameter)
					p->ADVANCE("past param") or_return
					if p.current.kind == .COMMA {
						p->ADVANCE("past comma to next param") or_return
					}
				case .DOTS:
					p->ADVANCE("past varargs") or_return
					break
				case:
					break
				}
			}
		}
		p->EXPECT(.CLOSE) or_return
		log.infof("PARSE_FUNCTION::finished parameters")
	}
	log.infof("PARSE_FUNCTION::parsing body")
	body := p->PARSE_BLOCK() or_return
	log.infof("PARSE_FUNCTION::expecting END")
	p->EXPECT(.END) or_return
	p->ADD_NODEID_CHILD(function_node, body)
	log.infof("PARSE_FUNCTION::finished")
	return function_node, nil
}
@(private = "file")
CURRENT_IS_KIND :: proc(p: ^Parser, kind: Token) -> bool {
	return p.current.kind == kind
}
@(private = "file", require_results)
PARSE_FOR :: proc(p: ^Parser) -> (for_node: NODEID, err: OuauError) {
	p->EXPECT(.FOR) or_return
	var_name := p->GET_CURRENT_TEXT()
	p->ADVANCE() or_return
	for_node = p->NEW_NODE(.FOR)
	p.nodes.name[for_node] = var_name
	if p->CURRENT_IS_KIND(.ASSIGN) {
		p->ADVANCE() or_return
		init := p->PARSE_EXP() or_return
		p->EXPECT(.COMMA) or_return
		limit := p->PARSE_EXP() or_return
		p->ADD_NODEID_CHILD(for_node, init)
		p->ADD_NODEID_CHILD(for_node, limit)
		if p.current.kind == .COMMA {
			p->ADVANCE() or_return
			step := p->PARSE_EXP() or_return
			p->ADD_NODEID_CHILD(for_node, step)
		}
		p->EXPECT(.DO) or_return
		body := p->PARSE_BLOCK() or_return
		p->EXPECT(.END) or_return
		p->ADD_NODEID_CHILD(for_node, body)
	} else if p->CURRENT_IS_KIND(.COMMA) {
		for p->CURRENT_IS_KIND(.COMMA) {
			p->ADVANCE() or_return
			next_var := p->NEW_NODE(.IDENTIFIER)
			p.nodes.name[next_var] = string(p.current.text)
			p->ADVANCE() or_return
			p->ADD_NODEID_CHILD(for_node, next_var)
		}
	} else if p->CURRENT_IS_KIND(.IN) {
		p->EXPECT(.IN) or_return
		iter := p->PARSE_EXPLIST() or_return
		for exp in iter { p->ADD_NODEID_CHILD(for_node, exp) }
		p->EXPECT(.DO) or_return
		body := p->PARSE_BLOCK() or_return
		p->EXPECT(.END) or_return
		p->ADD_NODEID_CHILD(for_node, body)
	}
	return for_node, nil
}
@(private = "file", require_results)
PARSE_LOCAL :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	my_alloc := virtual.arena_allocator(p.arena)
	log.infof("PARSE_LOCAL::(%v)", p.current.kind)
	p->EXPECT(.LOCAL) or_return
	node = p->NEW_NODE(.LOCAL)
	if p->CURRENT_IS_KIND(.FUNCTION) {
		function_node := p->PARSE_FUNCTION() or_return
		p->ADD_NODEID_CHILD(node, function_node)
		return
	} else {
		vars := make([dynamic]NODEID, my_alloc)
		primary_expr := p->PARSE_PRIMARY() or_return
		log.infof("PARSE_LOCAL::primary_expr(%v)", primary_expr)
		append(&vars, primary_expr)
		log.infof("PARSE_LOCAL::vars(%v)", vars)
		#partial switch p.current.kind {
		case .COMMA:
			for p->CURRENT_IS_KIND(.COMMA) {
				p->ADVANCE() or_return
				primary_expr = p->PARSE_PRIMARY() or_return
				append(&vars, primary_expr)
			}
			for v in vars {
				p->ADD_NODEID_CHILD(node, v)
			}
			if p->CURRENT_IS_KIND(.ASSIGN) {
				p->ADVANCE() or_return
				values := p->PARSE_EXPLIST() or_return
				for val in values {
					p->ADD_NODEID_CHILD(node, val)
				}
			}
		case .ASSIGN:
			log.infof("PARSE_LOCAL::ASSIGN")
			p->ADVANCE() or_return
			for v in vars {
				p->ADD_NODEID_CHILD(node, v)
			}
			values := p->PARSE_EXPLIST() or_return
			log.infof("PARSE_LOCAL::values(%v)", values)
			for val in values {
				p->ADD_NODEID_CHILD(node, val)
			}
		case:
			for v in vars {
				p->ADD_NODEID_CHILD(node, v)
			}
		}
		return
	}
	return
}
@(private = "file", require_results)
PARSE_BREAK :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	p->EXPECT(.BREAK) or_return
	node = p->NEW_NODE(.BREAK)
	return node, nil
}
@(private = "file", require_results)
PARSE_RETURN :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	p->EXPECT(.RETURN) or_return
	node = p->NEW_NODE(.RETURN)

	if p.current.kind != .SEMI && p.current.kind != .EOF {
		values := p->PARSE_EXPLIST() or_return
		for val in values do p->ADD_NODEID_CHILD(node, val)
	}

	return node, nil
}
@(private = "file", require_results)
PARSE_TABLE :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	p->EXPECT(.TOPEN) or_return
	table := p->NEW_NODE(.TABLE)
	if p.current.kind != .TCLOSE {
		for {
			if p.current.kind == .OPEN {
				p->ADVANCE() or_return
				key := p->PARSE_EXP() or_return
				p->EXPECT(.CLOSE) or_return
				p->EXPECT(.ASSIGN) or_return
				value := p->PARSE_EXP() or_return
				pair := p->NEW_NODE(.BINARY)
				p->ADD_NODEID_CHILD(pair, key)
				p->ADD_NODEID_CHILD(pair, value)
				p->ADD_NODEID_CHILD(table, pair)
			} else if p.current.kind == .IDENTIFIER && p.peek.kind == .ASSIGN {
				key := p->NEW_NODE(.IDENTIFIER)
				p.nodes.name[key] = string(p.current.text)
				p->ADVANCE() or_return
				p->EXPECT(.ASSIGN) or_return
				value := p->PARSE_EXP() or_return
				pair := p->NEW_NODE(.BINARY)
				p->ADD_NODEID_CHILD(pair, key)
				p->ADD_NODEID_CHILD(pair, value)
				p->ADD_NODEID_CHILD(table, pair)
			} else {
				value := p->PARSE_EXP() or_return
				p->ADD_NODEID_CHILD(table, value)
			}
			if p.current.kind != .COMMA && p.current.kind != .SEMI do break
			p->ADVANCE() or_return
		}
	}
	p->EXPECT(.TCLOSE) or_return
	return table, nil
}
@(private = "file", require_results)
PARSE_GLOBAL :: proc(p: ^Parser) -> (global_node: NODEID, err: OuauError) {
	my_alloc := virtual.arena_allocator(p.arena)
	p->EXPECT(.GLOBAL) or_return
	global_node = p->NEW_NODE(.GLOBAL)
	if p.current.kind == .FUNCTION {
		global_node = p->PARSE_FUNCTION() or_return // return global function
	} else {
		vars := make([dynamic]NODEID, my_alloc)
		primary_node := p->PARSE_PRIMARY() or_return
		append(&vars, primary_node)
		for p.current.kind == .COMMA {
			p->ADVANCE() or_return
			primary_node := p->PARSE_PRIMARY() or_return
			append(&vars, primary_node)
		}
		for v in vars { p->ADD_NODEID_CHILD(global_node, v) }
		if p->CURRENT_IS_KIND(.ASSIGN) {
			p->ADVANCE() or_return
			values := p->PARSE_EXPLIST() or_return
			for val in values { p->ADD_NODEID_CHILD(global_node, val) }
		}
	}
	return global_node, nil
}
@(private = "file")
SET_NODE_NAME :: proc(p: ^Parser, node: NODEID, name: string) -> (err: OuauError) {
	if p.nodes.name[node] == "" {
		p.nodes.name[node] = name
		return nil
	}
	return GET_PARSE_ERROR(p, "Name Already set for node.")
}
@(private = "file", require_results)
GET_CURRENT_TEXT :: proc(p: ^Parser) -> (text: string) {
	text = string(p.current.text)
	return
}

