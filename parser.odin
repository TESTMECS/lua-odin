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
	pos:              int,
	nodes:            NODES,
	lexer:            Lexer,
	current:          TokenDefinition,
	peek:             TokenDefinition,
	arena:            ^virtual.Arena,
	PARSE_CHUNK:      proc(p: ^Parser) -> (NODEID, OuauError),
	GET_CURRENT_TEXT: proc(p: ^Parser) -> (text: string),
	CURRENT_IS_KIND:  proc(p: ^Parser, kind: Token) -> bool,
	SET_NODEID_TOKEN: proc(p: ^Parser, node: NODEID, token: Token),
	ADD_NODEID_CHILD: proc(p: ^Parser, parent, child: NODEID),
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
NEW_PARSER :: proc(input: string, arena: ^virtual.Arena) -> (p: Parser) {
	p = Parser {
		pos              = 0,
		arena            = arena,
		nodes            = NODES{},
		current          = TokenDefinition{},
		peek             = TokenDefinition{},
		lexer            = NEW_LEXER(input),
		PARSE_CHUNK      = PARSE_CHUNK,
		CURRENT_IS_KIND  = CURRENT_IS_KIND,
		GET_CURRENT_TEXT = GET_CURRENT_TEXT,
		SET_NODEID_TOKEN = SET_NODEID_TOKEN,
		ADD_NODEID_CHILD = ADD_NODEID_CHILD,
	}
	NODES_INIT(&p)
	return
}
@(require_results)
ADVANCE :: proc(p: ^Parser, description := "") -> (err: OuauError) {
	p.current = p.peek
	next_token := p.lexer->NEXT() or_return
	p.peek = next_token
	return nil
}
@(require_results)
PARSE_CHUNK :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	ADVANCE(p, "p.current::tok[-1] and p.peek::tok[0]") or_return
	ADVANCE(p, "p.current::tok[0]") or_return
	block := PARSE_BLOCK(p) or_return
	return block, nil
}
@(private = "file")
NODES_INIT :: proc(p: ^Parser) {
	old_allocator := context.allocator
	context.allocator = virtual.arena_allocator(p.arena)
	defer context.allocator = old_allocator

	p.nodes.kind = make([dynamic]NODE_KIND)
	p.nodes.first_child = make([dynamic]NODEID)
	p.nodes.next_sibling = make([dynamic]NODEID)
	p.nodes.token = make([dynamic]Token)
	p.nodes.int_value = make([dynamic]i64)
	p.nodes.string_value = make([dynamic]string)
	p.nodes.name = make([dynamic]string)
}
@(private = "file")
NEW_NODE :: proc(p: ^Parser, k: NODE_KIND) -> NODEID {
	id := cast(NODEID)len(p.nodes.kind)

	append(&p.nodes.kind, k)
	append(&p.nodes.first_child, NODEID(0))
	append(&p.nodes.next_sibling, NODEID(0))
	append(&p.nodes.token, Token{})
	append(&p.nodes.int_value, 0)
	append(&p.nodes.string_value, "")
	append(&p.nodes.name, "")

	return id
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
	if p.current.kind == kind {
		return ADVANCE(p)
	}
	return nil
}

@(private = "file", require_results)
PARSE_BLOCK :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	block := NEW_NODE(p, .BLOCK)

	for {
		if p.current.kind == .SEMI {
			ADVANCE(p) or_return
			continue
		}

		tk := p.current.kind

		block_end := tk == .END || tk == .ELSE || tk == .ELSEIF || tk == .EOF
		if block_end do break

		child := PARSE_STMT(p) or_return
		p->ADD_NODEID_CHILD(block, child)
	}

	return block, nil
}
@(private = "file", require_results)
PARSE_STMT :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	tk := p.current.kind
	log.infof("PARSE_STMT:: %v", tk)
	#partial switch tk {
	case .WHILE:
		node = PARSE_WHILE(p) or_return
	case .REPEAT:
		node = PARSE_REPEAT(p) or_return
	case .DO:
		node = PARSE_DO(p) or_return
	case .IF:
		node = PARSE_IF(p) or_return
	case .FUNCTION:
		node = PARSE_FUNCTION(p) or_return
	case .FOR:
		node = PARSE_FOR(p) or_return
	case .LOCAL:
		node = PARSE_LOCAL(p) or_return
	case .GLOBAL:
		node = PARSE_GLOBAL(p) or_return
	case .BREAK:
		node = PARSE_BREAK(p) or_return
	case .RETURN:
		node = PARSE_RETURN(p) or_return
	case .OPEN:
		node = PARSE_CALL(p) or_return
	}
	return PARSE_EXPRESSION_STATEMENT(p)
}
@(private = "file", require_results)
PARSE_CALL :: proc(p: ^Parser) -> (call_node: NODEID, err: OuauError) {
	EXPECT(p, .OPEN) or_return
	args := PARSE_EXPLIST(p) or_return
	EXPECT(p, .CLOSE) or_return
	call_node = NEW_NODE(p, .CALL)
	for arg in args do p->ADD_NODEID_CHILD(call_node, arg)
	return call_node, nil
}
@(private = "file", require_results)
PARSE_WHILE :: proc(p: ^Parser) -> (while_node: NODEID, err: OuauError) {
	EXPECT(p, .WHILE) or_return
	while_node = NEW_NODE(p, .WHILE)
	cond := PARSE_EXP(p) or_return
	EXPECT(p, .DO) or_return
	body := PARSE_BLOCK(p) or_return
	EXPECT(p, .END) or_return
	p->ADD_NODEID_CHILD(while_node, cond)
	p->ADD_NODEID_CHILD(while_node, body)
	return while_node, nil
}
@(private = "file", require_results)
PARSE_IF :: proc(p: ^Parser) -> (if_node: NODEID, err: OuauError) {
	EXPECT(p, .IF) or_return
	if_node = NEW_NODE(p, .IF)
	cond := PARSE_EXP(p) or_return
	EXPECT(p, .THEN) or_return
	blk := PARSE_BLOCK(p) or_return
	p->ADD_NODEID_CHILD(if_node, cond)
	p->ADD_NODEID_CHILD(if_node, blk)
	for p.current.kind == .ELSEIF {
		ADVANCE(p) or_return
		econd := PARSE_EXP(p) or_return
		EXPECT(p, .THEN) or_return
		eblk := PARSE_BLOCK(p) or_return
		p->ADD_NODEID_CHILD(if_node, econd)
		p->ADD_NODEID_CHILD(if_node, eblk)
	}
	if p.current.kind == .ELSE {
		ADVANCE(p) or_return
		eblk := PARSE_BLOCK(p) or_return
		p->ADD_NODEID_CHILD(if_node, eblk)
	}
	EXPECT(p, .END) or_return
	return if_node, nil
}
@(private = "file", require_results)
PARSE_EXP :: proc(p: ^Parser) -> (expression: NODEID, err: OuauError) {
	expression = PARSE_PRECEDENCE(p, .LOWEST) or_return
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
	left_expression = PARSE_PREFIX_EXP(p) or_return
	for {
		current_prec := GET_PRECEDENCE(p.current.kind)
		if precedence >= current_prec do break
		left_expression = PARSE_INFIX(p, left_expression) or_return
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
		return .INDEX
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
		// (
		ADVANCE(p) or_return
		args := make([dynamic]NODEID)
		if p.current.kind != .CLOSE { 	// TODO: bad grammar
			tmp_expression := PARSE_EXP(p) or_return
			append(&args, tmp_expression)
			for p.current.kind == .COMMA {
				ADVANCE(p) or_return
				tmp_expression := PARSE_EXP(p) or_return
				append(&args, tmp_expression)
			}
		}
		EXPECT(p, .CLOSE) or_return
		infix_node = NEW_NODE(p, .CALL) // create node
		p->ADD_NODEID_CHILD(infix_node, left_expression)
		for arg in args do p->ADD_NODEID_CHILD(infix_node, arg)
		return infix_node, nil
	case .DOT:
		// .
		ADVANCE(p) or_return
		if p.current.kind == .IDENTIFIER { 	// TODO: bad grammar
			right_expression := NEW_NODE(p, .IDENTIFIER)

			p.nodes.name[right_expression] = p->GET_CURRENT_TEXT()
			ADVANCE(p) or_return
			infix_node := NEW_NODE(p, .BINARY)
			p.nodes.token[infix_node] = token // TODO: bad grammar
			p->ADD_NODEID_CHILD(infix_node, left_expression)
			p->ADD_NODEID_CHILD(infix_node, right_expression)
			return infix_node, nil
		}
	case .BOPEN:
		// [
		ADVANCE(p) or_return
		right_expression := PARSE_PRECEDENCE(p, .LOWEST) or_return
		EXPECT(p, .BCLOSE) or_return

		infix_node := NEW_NODE(p, .BINARY)
		p.nodes.token[infix_node] = token

		p->ADD_NODEID_CHILD(infix_node, left_expression)
		p->ADD_NODEID_CHILD(infix_node, right_expression)
		return infix_node, nil
	}
	ADVANCE(p) or_return
	right_expression := PARSE_PRECEDENCE(p, GET_PRECEDENCE(token)) or_return
	infix_node = NEW_NODE(p, .BINARY)
	p.nodes.token[infix_node] = token // TODO: bad grammar
	p->ADD_NODEID_CHILD(infix_node, left_expression)
	p->ADD_NODEID_CHILD(infix_node, right_expression)
	return infix_node, nil
}
@(private = "file", require_results)
PARSE_PRIMARY :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	tk := p.current.kind

	if tk == .NUMBER {
		id := NEW_NODE(p, .LITERAL)
		val, _ := strconv.parse_i64(p->GET_CURRENT_TEXT())
		p.nodes.int_value[id] = val
		ADVANCE(p) or_return

		return id, nil
	}

	if tk == .STRING {
		id := NEW_NODE(p, .STRING)
		p.nodes.string_value[id] = p->GET_CURRENT_TEXT()
		ADVANCE(p) or_return

		return id, nil
	}

	if tk == .IDENTIFIER {
		id := NEW_NODE(p, .IDENTIFIER)
		p.nodes.name[id] = p->GET_CURRENT_TEXT()
		ADVANCE(p) or_return

		return id, nil
	}

	if tk == .NIL || tk == .TRUE || tk == .FALSE {
		id := NEW_NODE(p, .LITERAL)
		p.nodes.string_value[id] = p->GET_CURRENT_TEXT()
		ADVANCE(p) or_return

		return id, nil
	}
	if tk == .OPEN {
		ADVANCE(p) or_return
		exp := PARSE_EXP(p) or_return
		EXPECT(p, .CLOSE) or_return
		return exp, nil
	}
	if tk == .TOPEN {
		node = PARSE_TABLE(p) or_return
	}
	// TODO: check
	return NEW_NODE(p, .INVALID), nil
}
@(private = "file", require_results)
PARSE_EXPRESSION_STATEMENT :: proc(p: ^Parser) -> (left_expression: NODEID, err: OuauError) {
	left_expression = PARSE_EXP(p) or_return

	if p.current.kind == .ASSIGN {
		ADVANCE(p) or_return
		right_expression := PARSE_EXPLIST(p) or_return

		assign_node := NEW_NODE(p, .ASSIGN)
		p->ADD_NODEID_CHILD(assign_node, left_expression)

		for expr in right_expression do p->ADD_NODEID_CHILD(assign_node, expr)

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
		unary_node := NEW_NODE(p, .UNARY)
		p->SET_NODEID_TOKEN(unary_node, p.current.kind)
		ADVANCE(p, "past unary operator") or_return
		right_expression := PARSE_PREFIX_EXP(p) or_return
		p->ADD_NODEID_CHILD(prefix_node, right_expression)
		prefix_node = unary_node
		return prefix_node, nil
	case:
		prefix_node = PARSE_PRIMARY(p) or_return
	}
	return prefix_node, nil
}
// TODO:
@(private = "file", require_results)
PARSE_EXPLIST :: proc(p: ^Parser) -> (parsed_expressions: []NODEID, err: OuauError) {
	old_allocator := context.allocator
	context.allocator = virtual.arena_allocator(p.arena)
	defer context.allocator = old_allocator
	expression_list := make([dynamic]NODEID)

	expression_node := PARSE_EXP(p) or_return
	append(&expression_list, expression_node)

	for p->CURRENT_IS_KIND(.COMMA) {
		ADVANCE(p) or_return
		expression_node = PARSE_EXP(p) or_return
		append(&expression_list, expression_node)
	}

	parsed_expressions = expression_list[:]
	return []NODEID{}, nil
}
@(private = "file", require_results)
PARSE_REPEAT :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	EXPECT(p, .REPEAT) or_return
	node = NEW_NODE(p, .REPEAT)
	ublock := PARSE_UBLOCK(p) or_return
	p->ADD_NODEID_CHILD(node, ublock)
	return node, nil
}
@(private = "file", require_results)
PARSE_UBLOCK :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	block := NEW_NODE(p, .BLOCK)
	for {
		#partial switch p.current.kind {
		case .SEMI:
			ADVANCE(p) or_return
			continue
		case .UNTIL:
			break
		case:
			child := PARSE_STMT(p) or_return
			p->ADD_NODEID_CHILD(block, child)
		}
	}
	EXPECT(p, .UNTIL) or_return
	cond := PARSE_EXP(p) or_return
	node = NEW_NODE(p, .UBLOCK)
	p->ADD_NODEID_CHILD(node, block)
	p->ADD_NODEID_CHILD(node, cond)
	return node, nil
}
@(private = "file", require_results)
PARSE_DO :: proc(p: ^Parser) -> (do_block_body: NODEID, err: OuauError) {
	EXPECT(p, .DO) or_return
	do_block_body = PARSE_BLOCK(p) or_return
	EXPECT(p, .END) or_return
	return do_block_body, nil
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
@(private = "file", require_results)
PARSE_FUNCTION :: proc(p: ^Parser) -> (function_node: NODEID, err: OuauError) {
	EXPECT(p, .FUNCTION) or_return

	function_name := p->GET_CURRENT_TEXT()
	function_node = NEW_NODE(p, .FUNCTION)
	SET_NODE_NAME(p, function_node, function_name)

	ADVANCE(p, "past 'function name'") or_return
	if p->CURRENT_IS_KIND(.OPEN) {
		ADVANCE(p, "past '(' ") or_return
		if p->CURRENT_IS_KIND(.CLOSE) {
			for {
				#partial switch p.current.kind {
				case .IDENTIFIER:
					function_parameter := NEW_NODE(p, .IDENTIFIER)
					p.nodes.name[function_parameter] = p->GET_CURRENT_TEXT()
					p->ADD_NODEID_CHILD(function_node, function_parameter)
					ADVANCE(p, "past param") or_return
					if p.current.kind == .COMMA {
						ADVANCE(p, "past comma to next param") or_return
					} else {
						break
					}
				case .DOTS:
					// varargs, TODO:
					ADVANCE(p, "past varargs") or_return
					break
				case:
					break
				}
			}
		}
		EXPECT(p, .CLOSE) or_return
	}
	body := PARSE_BLOCK(p) or_return
	EXPECT(p, .END) or_return
	p->ADD_NODEID_CHILD(function_node, body)
	return function_node, nil
}

@(private = "file")
CURRENT_IS_KIND :: proc(p: ^Parser, kind: Token) -> bool {
	return p.current.kind == kind
}
@(private = "file", require_results)
PARSE_FOR :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	EXPECT(p, .FOR) or_return
	var_name := p->GET_CURRENT_TEXT()
	ADVANCE(p) or_return

	node = NEW_NODE(p, .FOR)
	p.nodes.name[node] = var_name

	if p->CURRENT_IS_KIND(.ASSIGN) {
		ADVANCE(p) or_return
		init := PARSE_EXP(p) or_return
		EXPECT(p, .COMMA) or_return
		limit := PARSE_EXP(p) or_return
		p->ADD_NODEID_CHILD(node, init)
		p->ADD_NODEID_CHILD(node, limit)
		if p.current.kind == .COMMA {
			ADVANCE(p) or_return
			step := PARSE_EXP(p) or_return
			p->ADD_NODEID_CHILD(node, step)
		}
		EXPECT(p, .DO) or_return
		body := PARSE_BLOCK(p) or_return
		EXPECT(p, .END) or_return
		p->ADD_NODEID_CHILD(node, body)
	} else if p->CURRENT_IS_KIND(.COMMA) {
		for p->CURRENT_IS_KIND(.COMMA) {
			ADVANCE(p) or_return
			next_var := NEW_NODE(p, .IDENTIFIER)
			p.nodes.name[next_var] = string(p.current.text)
			ADVANCE(p) or_return
			p->ADD_NODEID_CHILD(node, next_var)
		}
	} else if p->CURRENT_IS_KIND(.IN) {
		EXPECT(p, .IN) or_return
		iter := PARSE_EXPLIST(p) or_return
		for exp in iter do p->ADD_NODEID_CHILD(node, exp)
		EXPECT(p, .DO) or_return
		body := PARSE_BLOCK(p) or_return
		EXPECT(p, .END) or_return
		p->ADD_NODEID_CHILD(node, body)
	}
	return node, nil
}
@(private = "file", require_results)
PARSE_LOCAL :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	old_allocator := context.allocator
	context.allocator = virtual.arena_allocator(p.arena)
	defer context.allocator = old_allocator

	EXPECT(p, .LOCAL) or_return
	node = NEW_NODE(p, .LOCAL)
	if p->CURRENT_IS_KIND(.FUNCTION) {
		function_node := PARSE_FUNCTION(p) or_return
		p->ADD_NODEID_CHILD(node, function_node)
		return
	} else {
		vars := make([dynamic]NODEID)
		primary_expr := PARSE_PRIMARY(p) or_return
		append(&vars, primary_expr)

		for p->CURRENT_IS_KIND(.COMMA) {
			ADVANCE(p) or_return
			primary_expr = PARSE_PRIMARY(p) or_return
			append(&vars, primary_expr)
		}

		for v in vars do p->ADD_NODEID_CHILD(node, v)

		if p.current.kind == .ASSIGN {
			ADVANCE(p) or_return
			values := PARSE_EXPLIST(p) or_return
			for val in values do p->ADD_NODEID_CHILD(node, val)
		}
	}

	return
}
@(private = "file", require_results)
PARSE_BREAK :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	EXPECT(p, .BREAK) or_return
	node = NEW_NODE(p, .BREAK)
	return node, nil
}
@(private = "file", require_results)
PARSE_RETURN :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	EXPECT(p, .RETURN) or_return
	node = NEW_NODE(p, .RETURN)

	if p.current.kind != .SEMI && p.current.kind != .EOF {
		values := PARSE_EXPLIST(p) or_return
		for val in values do p->ADD_NODEID_CHILD(node, val)
	}

	return node, nil
}
@(private = "file", require_results)
PARSE_TABLE :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	EXPECT(p, .TOPEN) or_return
	table := NEW_NODE(p, .TABLE)

	if p.current.kind != .TCLOSE {

		for {

			if p.current.kind == .OPEN {
				ADVANCE(p) or_return
				key := PARSE_EXP(p) or_return
				EXPECT(p, .CLOSE) or_return
				EXPECT(p, .ASSIGN) or_return
				value := PARSE_EXP(p) or_return
				pair := NEW_NODE(p, .BINARY)
				p->ADD_NODEID_CHILD(pair, key)
				p->ADD_NODEID_CHILD(pair, value)
				p->ADD_NODEID_CHILD(table, pair)
			} else if p.current.kind == .IDENTIFIER && p.peek.kind == .ASSIGN {
				key := NEW_NODE(p, .IDENTIFIER)
				p.nodes.name[key] = string(p.current.text)
				ADVANCE(p) or_return
				EXPECT(p, .ASSIGN) or_return
				value := PARSE_EXP(p) or_return

				pair := NEW_NODE(p, .BINARY)
				p->ADD_NODEID_CHILD(pair, key)
				p->ADD_NODEID_CHILD(pair, value)
				p->ADD_NODEID_CHILD(table, pair)
			} else {
				value := PARSE_EXP(p) or_return
				p->ADD_NODEID_CHILD(table, value)
			}

			if p.current.kind != .COMMA && p.current.kind != .SEMI do break

			ADVANCE(p) or_return
		}
	}
	EXPECT(p, .TCLOSE) or_return
	return table, nil
}
@(private = "file", require_results)
PARSE_GLOBAL :: proc(p: ^Parser) -> (global_node: NODEID, err: OuauError) {
	old_allocator := context.allocator
	context.allocator = virtual.arena_allocator(p.arena)
	defer context.allocator = old_allocator

	EXPECT(p, .GLOBAL) or_return
	global_node = NEW_NODE(p, .GLOBAL)

	if p.current.kind == .FUNCTION {
		global_node = PARSE_FUNCTION(p) or_return // return global function
	} else {
		vars := make([dynamic]NODEID)

		primary_node := PARSE_PRIMARY(p) or_return
		append(&vars, primary_node)

		for p.current.kind == .COMMA {
			ADVANCE(p) or_return
			primary_node := PARSE_PRIMARY(p) or_return
			append(&vars, primary_node)
		}

		for v in vars do p->ADD_NODEID_CHILD(global_node, v)

		if p.current.kind == .ASSIGN {
			ADVANCE(p) or_return
			values := PARSE_EXPLIST(p) or_return
			for val in values do p->ADD_NODEID_CHILD(global_node, val)
		}
	}
	return global_node, nil
}

