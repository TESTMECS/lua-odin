package ouau
import "core:strconv"
/*
	 ./parser.odin
	 Copyright(C) 2025 TESTMEE
	 This file defines the parser functions for Ouau.
	 @NODEID, @NODE_KIND, @NODES, @Precedence, @Parser
*/
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
	pos:     int,
	nodes:   NODES,
	lexer:   Lexer,
	current: Token_def,
	peek:    Token_def,
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
NODES_INIT :: proc(p: ^NODES, allocator := context.allocator) {
	//@@Initalize the Nodes with the given.
	p.kind = make([dynamic]NODE_KIND, 0)
	p.first_child = make([dynamic]NODEID, 0)
	p.next_sibling = make([dynamic]NODEID, 0)
	p.token = make([dynamic]Token, 0)
	p.int_value = make([dynamic]i64, 0)
	p.string_value = make([dynamic]string, 0)
	p.name = make([dynamic]string, 0)
}
NEW_PARSER :: proc(input: string, allocator := context.allocator) -> (p: Parser) {
	//@@Create a new parser with a new set of nodes.
	p = Parser {
		pos   = 0,
		nodes = NODES{},
		lexer = NEW_LEXER(input),
	}
	NODES_INIT(&p.nodes, allocator)
	return
}
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
ADVANCE :: proc(p: ^Parser) {
	p.current = p.peek
	p.peek = NEXT(&p.lexer)
}
ADD_CHILD :: proc(p: ^Parser, parent, child: NODEID) {
	if p.nodes.first_child[parent] == 0 {
		p.nodes.first_child[parent] = child
	}
	 else {
		n := p.nodes.first_child[parent]
		for p.nodes.next_sibling[n] != 0 {
			n = p.nodes.next_sibling[n]
		}
		p.nodes.next_sibling[n] = child
	}
}
EXPECT :: proc(p: ^Parser, kind: Token) -> bool {
	if p.current.kind == kind {
		ADVANCE(p)
		return true
	}
	return false
}
PARSE_CHUNK :: proc(p: ^Parser) -> NODEID {
	ADVANCE(p)
	ADVANCE(p)

	return PARSE_BLOCK(p)
}
PARSE_BLOCK :: proc(p: ^Parser) -> NODEID {
	block := NEW_NODE(p, .BLOCK)
	for {
		if p.current.kind == .SEMI {
			ADVANCE(p)
			continue
		}
		tk := p.current.kind
		block_end := tk == .END || tk == .ELSE || tk == .ELSEIF || tk == .EOF
		if block_end do break
		ADD_CHILD(p, block, PARSE_STMT(p))
	}
	return block
}
PARSE_STMT :: proc(p: ^Parser) -> NODEID {
	tk := p.current.kind
	if tk == .WHILE do return PARSE_WHILE(p)
	if tk == .REPEAT do return PARSE_REPEAT(p)
	if tk == .DO do return PARSE_DO(p)
	if tk == .IF do return PARSE_IF(p)
	if tk == .FUNCTION do return PARSE_FUNCTION(p)
	if tk == .FOR do return PARSE_FOR(p)
	if tk == .LOCAL do return PARSE_LOCAL(p)
	if tk == .GLOBAL do return PARSE_GLOBAL(p)
	if tk == .BREAK do return PARSE_BREAK(p)
	if tk == .RETURN do return PARSE_RETURN(p)
	if tk == .OPEN do return PARSE_CALL(p)
	return PARSE_EXPRESSION_STATEMENT(p)
}
PARSE_CALL :: proc(p: ^Parser) -> NODEID {
	EXPECT(p, .OPEN)
	args := PARSE_EXPLIST(p)
	EXPECT(p, .CLOSE)
	call := NEW_NODE(p, .CALL)
	for arg in args do ADD_CHILD(p, call, arg)
	return call
}
PARSE_WHILE :: proc(p: ^Parser) -> NODEID {
	EXPECT(p, .WHILE)
	node := NEW_NODE(p, .WHILE)
	cond := PARSE_EXP(p)
	EXPECT(p, .DO)
	body := PARSE_BLOCK(p)
	EXPECT(p, .END)
	ADD_CHILD(p, node, cond)
	ADD_CHILD(p, node, body)
	return node
}
PARSE_IF :: proc(p: ^Parser) -> NODEID {
	EXPECT(p, .IF)
	root := NEW_NODE(p, .IF)
	cond := PARSE_EXP(p)
	EXPECT(p, .THEN)
	blk := PARSE_BLOCK(p)
	ADD_CHILD(p, root, cond)
	ADD_CHILD(p, root, blk)
	for p.current.kind == .ELSEIF {
		ADVANCE(p)
		econd := PARSE_EXP(p)
		EXPECT(p, .THEN)
		eblk := PARSE_BLOCK(p)
		ADD_CHILD(p, root, econd)
		ADD_CHILD(p, root, eblk)
	}
	if p.current.kind == .ELSE {
		ADVANCE(p)
		eblk := PARSE_BLOCK(p)
		ADD_CHILD(p, root, eblk)
	}
	EXPECT(p, .END)
	return root
}
PARSE_EXP :: proc(p: ^Parser) -> NODEID {
	return PARSE_PRECEDENCE(p, .LOWEST)
}
PARSE_PRECEDENCE :: proc(p: ^Parser, precedence: Precedence) -> NODEID {
	left := PARSE_PREFIX_EXP(p)
	for {
		current_prec := GET_PRECEDENCE(p.current.kind)
		if precedence >= current_prec do break
		left = PARSE_INFIX(p, left)
	}
	return left
}
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
PARSE_INFIX :: proc(p: ^Parser, left: NODEID) -> NODEID {
	tok := p.current.kind
	if tok == .OPEN {
		ADVANCE(p)
		args := make([dynamic]NODEID)
		if p.current.kind != .CLOSE {
			append(&args, PARSE_EXP(p))
			for p.current.kind == .COMMA {
				ADVANCE(p)
				append(&args, PARSE_EXP(p))
			}
		}
		EXPECT(p, .CLOSE)
		node := NEW_NODE(p, .CALL)
		ADD_CHILD(p, node, left)
		for arg in args do ADD_CHILD(p, node, arg)
		return node
	}
	if tok == .DOT {
		ADVANCE(p)
		if p.current.kind == .IDENTIFIER {
			right := NEW_NODE(p, .IDENTIFIER)
			p.nodes.name[right] = string(p.current.text)
			ADVANCE(p)
			node := NEW_NODE(p, .BINARY)
			p.nodes.token[node] = tok
			ADD_CHILD(p, node, left)
			ADD_CHILD(p, node, right)
			return node
		}
	}
	if tok == .BOPEN {
		ADVANCE(p)
		right := PARSE_PRECEDENCE(p, .LOWEST)
		EXPECT(p, .BCLOSE)
		node := NEW_NODE(p, .BINARY)
		p.nodes.token[node] = tok
		ADD_CHILD(p, node, left)
		ADD_CHILD(p, node, right)
		return node
	}
	ADVANCE(p)
	right := PARSE_PRECEDENCE(p, GET_PRECEDENCE(tok))
	node := NEW_NODE(p, .BINARY)
	p.nodes.token[node] = tok
	ADD_CHILD(p, node, left)
	ADD_CHILD(p, node, right)
	return node
}
PARSE_PRIMARY :: proc(p: ^Parser) -> NODEID {
	tk := p.current.kind
	if tk == .NUMBER {
		id := NEW_NODE(p, .LITERAL)
		val, _ := strconv.parse_i64(string(p.current.text))
		p.nodes.int_value[id] = val
		ADVANCE(p)
		return id
	}
	if tk == .STRING {
		id := NEW_NODE(p, .STRING)
		p.nodes.string_value[id] = string(p.current.text)
		ADVANCE(p)
		return id
	}
	if tk == .IDENTIFIER {
		id := NEW_NODE(p, .IDENTIFIER)
		p.nodes.name[id] = string(p.current.text)
		ADVANCE(p)
		return id
	}
	if tk == .NIL || tk == .TRUE || tk == .FALSE {
		id := NEW_NODE(p, .LITERAL)
		p.nodes.string_value[id] = string(p.current.text)
		ADVANCE(p)
		return id
	}
	if tk == .OPEN {
		ADVANCE(p)
		exp := PARSE_EXP(p)
		EXPECT(p, .CLOSE)
		return exp
	}
	if tk == .TOPEN {
		return PARSE_TABLE(p)
	}
	return NEW_NODE(p, .INVALID)
}
PARSE_EXPRESSION_STATEMENT :: proc(p: ^Parser) -> NODEID {
	left := PARSE_EXP(p)

	if p.current.kind == .ASSIGN {
		ADVANCE(p)
		right := PARSE_EXPLIST(p)
		node := NEW_NODE(p, .ASSIGN)
		ADD_CHILD(p, node, left)
		for r in right do ADD_CHILD(p, node, r)
		return node
	}

	return left
}
PEEK_PRECEDENCE :: proc(p: ^Parser) -> Precedence {
	return PRECEDENCES[p.peek.kind]
}
PARSE_PREFIX_EXP :: proc(p: ^Parser) -> NODEID {
	tk := p.current.kind
	if tk == .NOT || tk == .MINUS || tk == .POUND || tk == .BANG {
		node := NEW_NODE(p, .UNARY)
		p.nodes.token[node] = p.current.kind
		ADVANCE(p)
		right := PARSE_PREFIX_EXP(p)
		ADD_CHILD(p, node, right)
		return node
	}
	return PARSE_PRIMARY(p)
}
PARSE_EXPLIST :: proc(p: ^Parser) -> []NODEID {
	exps := make([dynamic]NODEID)
	append(&exps, PARSE_EXP(p))
	for p.current.kind == .COMMA {
		ADVANCE(p)
		append(&exps, PARSE_EXP(p))
	}
	return exps[:]
}
PARSE_REPEAT :: proc(p: ^Parser) -> NODEID {
	EXPECT(p, .REPEAT)
	node := NEW_NODE(p, .REPEAT)
	ublock := PARSE_UBLOCK(p)
	ADD_CHILD(p, node, ublock)
	return node
}
PARSE_UBLOCK :: proc(p: ^Parser) -> NODEID {
	block := NEW_NODE(p, .BLOCK)
	for {
		if p.current.kind == .SEMI {
			ADVANCE(p)
			continue
		}
		if p.current.kind == .UNTIL do break
		ADD_CHILD(p, block, PARSE_STMT(p))
	}
	EXPECT(p, .UNTIL)
	cond := PARSE_EXP(p)
	node := NEW_NODE(p, .UBLOCK)
	ADD_CHILD(p, node, block)
	ADD_CHILD(p, node, cond)
	return node
}
PARSE_DO :: proc(p: ^Parser) -> NODEID {
	EXPECT(p, .DO)
	body := PARSE_BLOCK(p)
	EXPECT(p, .END)
	return body
}
PARSE_FUNCTION :: proc(p: ^Parser) -> NODEID {
	EXPECT(p, .FUNCTION)
	name := p.current.text
	node := NEW_NODE(p, .FUNCTION)
	p.nodes.name[node] = string(name)
	ADVANCE(p) // skip function name
	if p.current.kind == .OPEN {
		ADVANCE(p)
		if p.current.kind != .CLOSE {
			for {
				if p.current.kind == .IDENTIFIER {
					param := NEW_NODE(p, .IDENTIFIER)
					p.nodes.name[param] = string(p.current.text)
					ADD_CHILD(p, node, param)
					ADVANCE(p)
					if p.current.kind == .COMMA {
						ADVANCE(p)
					}
					 else {
						break
					}
				}
				 else if p.current.kind == .DOTS {
					// varargs
					ADVANCE(p)
					break
				}
				 else {
					break
				}
			}
		}
		EXPECT(p, .CLOSE)
	}

	body := PARSE_BLOCK(p)
	EXPECT(p, .END)
	ADD_CHILD(p, node, body)
	return node
}
PARSE_FOR :: proc(p: ^Parser) -> NODEID {
	EXPECT(p, .FOR)
	var_name := string(p.current.text)
	ADVANCE(p)

	node := NEW_NODE(p, .FOR)
	p.nodes.name[node] = var_name

	if p.current.kind == .ASSIGN {
		ADVANCE(p)
		init := PARSE_EXP(p)
		EXPECT(p, .COMMA)
		limit := PARSE_EXP(p)

		ADD_CHILD(p, node, init)
		ADD_CHILD(p, node, limit)

		if p.current.kind == .COMMA {
			ADVANCE(p)
			step := PARSE_EXP(p)
			ADD_CHILD(p, node, step)
		}

		EXPECT(p, .DO)
		body := PARSE_BLOCK(p)
		EXPECT(p, .END)
		ADD_CHILD(p, node, body)
	}
	 else if p.current.kind == .COMMA || p.current.kind == .IN {
		if p.current.kind == .COMMA {
			for p.current.kind == .COMMA {
				ADVANCE(p)
				next_var := NEW_NODE(p, .IDENTIFIER)
				p.nodes.name[next_var] = string(p.current.text)
				ADVANCE(p)
				ADD_CHILD(p, node, next_var)
			}
		}

		EXPECT(p, .IN)
		iter := PARSE_EXPLIST(p)
		for exp in iter do ADD_CHILD(p, node, exp)

		EXPECT(p, .DO)
		body := PARSE_BLOCK(p)
		EXPECT(p, .END)
		ADD_CHILD(p, node, body)
	}
	return node
}
PARSE_LOCAL :: proc(p: ^Parser) -> NODEID {
	EXPECT(p, .LOCAL)
	node := NEW_NODE(p, .LOCAL)

	if p.current.kind == .FUNCTION {
		PARSE_FUNCTION(p)
	}
	 else {
		vars := make([dynamic]NODEID)
		append(&vars, PARSE_PRIMARY(p))

		for p.current.kind == .COMMA {
			ADVANCE(p)
			append(&vars, PARSE_PRIMARY(p))
		}

		for v in vars do ADD_CHILD(p, node, v)

		if p.current.kind == .ASSIGN {
			ADVANCE(p)
			values := PARSE_EXPLIST(p)
			for val in values do ADD_CHILD(p, node, val)
		}
	}

	return node
}
PARSE_BREAK :: proc(p: ^Parser) -> NODEID {
	EXPECT(p, .BREAK)
	return NEW_NODE(p, .BREAK)
}
PARSE_RETURN :: proc(p: ^Parser) -> NODEID {
	EXPECT(p, .RETURN)
	node := NEW_NODE(p, .RETURN)

	if p.current.kind != .SEMI && p.current.kind != .EOF {
		values := PARSE_EXPLIST(p)
		for val in values do ADD_CHILD(p, node, val)
	}

	return node
}
PARSE_TABLE :: proc(p: ^Parser) -> NODEID {
	EXPECT(p, .TOPEN)
	table := NEW_NODE(p, .TABLE)
	if p.current.kind != .TCLOSE {
		for {
			if p.current.kind == .OPEN {
				ADVANCE(p)
				key := PARSE_EXP(p)
				EXPECT(p, .CLOSE)
				EXPECT(p, .ASSIGN)
				value := PARSE_EXP(p)

				pair := NEW_NODE(p, .BINARY)
				ADD_CHILD(p, pair, key)
				ADD_CHILD(p, pair, value)
				ADD_CHILD(p, table, pair)
			}
			 else if p.current.kind == .IDENTIFIER && p.peek.kind == .ASSIGN {
				key := NEW_NODE(p, .IDENTIFIER)
				p.nodes.name[key] = string(p.current.text)
				ADVANCE(p)
				EXPECT(p, .ASSIGN)
				value := PARSE_EXP(p)

				pair := NEW_NODE(p, .BINARY)
				ADD_CHILD(p, pair, key)
				ADD_CHILD(p, pair, value)
				ADD_CHILD(p, table, pair)
			}
			 else {
				value := PARSE_EXP(p)
				ADD_CHILD(p, table, value)
			}

			if p.current.kind != .COMMA && p.current.kind != .SEMI do break
			ADVANCE(p)
		}
	}
	EXPECT(p, .TCLOSE)
	return table
}
PARSE_GLOBAL :: proc(p: ^Parser) -> NODEID {
	EXPECT(p, .GLOBAL)
	node := NEW_NODE(p, .GLOBAL)

	if p.current.kind == .FUNCTION {
		PARSE_FUNCTION(p)
	}
	 else {
		vars := make([dynamic]NODEID)
		append(&vars, PARSE_PRIMARY(p))

		for p.current.kind == .COMMA {
			ADVANCE(p)
			append(&vars, PARSE_PRIMARY(p))
		}

		for v in vars do ADD_CHILD(p, node, v)

		if p.current.kind == .ASSIGN {
			ADVANCE(p)
			values := PARSE_EXPLIST(p)
			for val in values do ADD_CHILD(p, node, val)
		}
	}

	return node
}

