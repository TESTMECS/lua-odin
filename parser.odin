package ouau
import "core:mem/virtual"
import "core:strconv"
/*
	 ./parser.odin
	 Copyright(C) 2025 TESTMEE
	 This file defines the parser functions for Ouau.
*/
@(require_results)
CHUNK :: proc(p: ^Parser) -> (node: NODEID, err: ^OuauError) {
	p->ADVANCE() or_return // Init p.peek
	p->ADVANCE() or_return // Init p.current to p.peek
	node = p->BLOCK() or_return
	return node, nil
}
@(private = "file", require_results)
ADVANCE :: proc(p: ^Parser) -> (err: ^OuauError) {
	p.current = p.peek
	next_token := p.lexer->NEXT() or_return
	p.peek = next_token
	return nil
}
@(private = "file", require_results)
EXPECT :: proc(p: ^Parser, kind: Token) -> (err: ^OuauError) {
	if p->IS(kind) {
		p->ADVANCE() or_return
	}
	return nil
}
@(private = "file", require_results)
BLOCK :: proc(p: ^Parser) -> (node: NODEID, err: ^OuauError) {
	node = p->NEW_NODE(.BLOCK)
	block_loop: for {
		#partial switch p->GET_TOKEN() {
		case .SEMI:
			p->ADVANCE() or_return
			continue block_loop
		case .END:
			p->ADVANCE() or_return
			break block_loop
		case .ELSE, .ELSEIF:
			break block_loop
		case:
			stmt := p->STMT() or_return
			p->APPEND_CHILD(node, stmt)
		case .EOF:
			break block_loop
		case .ILLEGAL:
			return node, p->PARSE_ERROR("PARSE_BLOCK::Unexpected teriminal::()")
		}
	}
	return node, nil
}
@(private = "file", require_results)
STMT :: proc(p: ^Parser) -> (node: NODEID, err: ^OuauError) {
	#partial switch p->GET_TOKEN() {
	case .WHILE:
		p->EXPECT(.WHILE) or_return
		node = p->NEW_NODE(.WHILE)
		cond := p->EXP() or_return
		p->EXPECT(.DO) or_return
		body := p->BLOCK() or_return
		p->EXPECT(.END) or_return
		p->APPEND_CHILD(node, cond)
		p->APPEND_CHILD(node, body)
	case .REPEAT:
		p->EXPECT(.REPEAT) or_return
		node = p->NEW_NODE(.REPEAT)
		ublock := p->UBLOCK() or_return
		p->APPEND_CHILD(node, ublock)
		return node, nil
	case .DO:
		p->EXPECT(.DO) or_return
		node = p->BLOCK() or_return // segfault here.
		p->EXPECT(.END) or_return
	case .IF:
		p->EXPECT(.IF) or_return
		node = p->NEW_NODE(.IF)
		cond := p->EXP() or_return
		p->EXPECT(.THEN) or_return
		blk := p->BLOCK() or_return
		p->APPEND_CHILD(node, cond)
		p->APPEND_CHILD(node, blk)
		for p->IS(.ELSEIF) {
			p->ADVANCE() or_return // past 'elseif'
			econd := p->EXP() or_return
			p->EXPECT(.THEN) or_return
			eblk := p->BLOCK() or_return
			p->APPEND_CHILD(node, econd)
			p->APPEND_CHILD(node, eblk)
		}
		if p->IS(.ELSE) {
			p->ADVANCE() or_return
			eblk := p->BLOCK() or_return
			p->APPEND_CHILD(node, eblk)
		}
		p->EXPECT(.END) or_return
	case .FOR:
		p->EXPECT(.FOR) or_return
		induction_var := p->GET_TEXT()
		p->ADVANCE() or_return
		node = p->NEW_NODE(.FOR)
		p->SET_NAME(node, induction_var)
		#partial switch p->GET_TOKEN() {
		case .ASSIGN:
			p->ADVANCE() or_return
			lowerbound := p->EXP() or_return
			p->EXPECT(.COMMA) or_return
			upperbound := p->EXP() or_return
			p->APPEND_CHILD(node, lowerbound)
			p->APPEND_CHILD(node, upperbound)
			if p->IS(.COMMA) {
				p->ADVANCE() or_return
				step_var := p->EXP() or_return
				p->APPEND_CHILD(node, step_var)
			}
			p->EXPECT(.DO) or_return
			body := p->BLOCK() or_return
			p->EXPECT(.END) or_return
			p->APPEND_CHILD(node, body)
		case .COMMA:
			for p->IS(.COMMA) {
				p->ADVANCE() or_return
				next_var := p->NEW_NODE(.IDENTIFIER)
				p->SET_NAME(next_var, p->GET_TEXT())
				p->ADVANCE() or_return
				p->APPEND_CHILD(node, next_var)
			}
		case .IN:
			p->EXPECT(.IN) or_return
			iter := p->EXPLIST() or_return
			for exp in iter { p->APPEND_CHILD(node, exp) }
			p->EXPECT(.DO) or_return
			body := p->BLOCK() or_return
			p->EXPECT(.END) or_return
			p->APPEND_CHILD(node, body)
		case:
			return node, p->PARSE_ERROR("Invalid Token in For Loop")
		}
	case .LOCAL:
		my_alloc := virtual.arena_allocator(p.arena)
		p->EXPECT(.LOCAL) or_return
		node = p->NEW_NODE(.LOCAL)
		#partial switch p->GET_TOKEN() {
		case .FUNCTION:
			function_node := p->FUNCTION() or_return
			p->APPEND_CHILD(node, function_node)
			return node, nil
		case .IDENTIFIER:
			vars := make([dynamic]NODEID, my_alloc)
			primary_expr := p->PRIMARY() or_return
			append(&vars, primary_expr)
			#partial switch p->GET_TOKEN() {
			case .COMMA:
				for p->IS(.COMMA) {
					p->ADVANCE() or_return
					primary_expr = p->PRIMARY() or_return
					append(&vars, primary_expr)
				}
				for v in vars { p->APPEND_CHILD(node, v) }
				if p->IS(.ASSIGN) {
					p->ADVANCE() or_return
					values := p->EXPLIST() or_return
					for val in values {
						p->APPEND_CHILD(node, val)
					}
				}
			case .ASSIGN:
				p->ADVANCE() or_return
				for v in vars { p->APPEND_CHILD(node, v) }
				values := p->EXPLIST() or_return
				for val in values { p->APPEND_CHILD(node, val) }
			case:
				for v in vars { p->APPEND_CHILD(node, v) }
			}
			return node, nil
		case:
			return node, p->PARSE_ERROR("Invalid Token in Local Declaration")
		}
	case .GLOBAL:
		my_alloc := virtual.arena_allocator(p.arena)
		p->EXPECT(.GLOBAL) or_return
		node = p->NEW_NODE(.GLOBAL)
		if p->IS(.FUNCTION) {
			node = p->FUNCTION() or_return // return global function
		} else {
			vars := make([dynamic]NODEID, my_alloc)
			primary_node := p->PRIMARY() or_return
			append(&vars, primary_node)
			for p->IS(.COMMA) {
				p->ADVANCE() or_return
				primary_node := p->PRIMARY() or_return
				append(&vars, primary_node)
			}
			for v in vars { p->APPEND_CHILD(node, v) }
			if p->IS(.ASSIGN) {
				p->ADVANCE() or_return
				values := p->EXPLIST() or_return
				for val in values { p->APPEND_CHILD(node, val) }
			}
		}
		return node, nil
	case .BREAK:
		p->EXPECT(.BREAK) or_return
		node = p->NEW_NODE(.BREAK)
		return node, nil
	case .RETURN:
		p->EXPECT(.RETURN) or_return
		node = p->NEW_NODE(.RETURN)
		if !(p->IS(.SEMI)) && !(p->IS(.EOF)) {
			values := p->EXPLIST() or_return
			for val in values { p->APPEND_CHILD(node, val) }
		}
		return node, nil
	case .OPEN:
		p->EXPECT(.OPEN) or_return
		args := p->EXPLIST() or_return
		p->EXPECT(.CLOSE) or_return
		node = p->NEW_NODE(.CALL)
		for arg in args { p->APPEND_CHILD(node, arg) }
		return node, nil
	case .FUNCTION:
		node = p->FUNCTION() or_return
	case:
		// Expression-statement
		node = p->EXP() or_return
		if p->IS(.ASSIGN) {
			p->ADVANCE() or_return
			assign_node := p->NEW_NODE(.ASSIGN)
			p->APPEND_CHILD(assign_node, node)
			rhs := p->EXPLIST() or_return
			for expr in rhs { p->APPEND_CHILD(assign_node, expr) }
			return node, nil
		}
		return node, nil
	}
	return node, nil
}
@(private = "file", require_results)
UBLOCK :: proc(p: ^Parser) -> (node: NODEID, err: ^OuauError) {
	block := p->NEW_NODE(.BLOCK)
	ublock: for {
		#partial switch p->GET_TOKEN() {
		case .SEMI:
			p->ADVANCE() or_return
			continue ublock
		case .UNTIL:
			break ublock
		case:
			child := p->STMT() or_return
			p->APPEND_CHILD(block, child)
		}
	}
	p->EXPECT(.UNTIL) or_return
	cond := p->EXP() or_return
	node = p->NEW_NODE(.UBLOCK)
	p->APPEND_CHILD(node, block)
	p->APPEND_CHILD(node, cond)
	return node, nil
}
@(private = "file", require_results)
FUNCTION :: proc(p: ^Parser) -> (node: NODEID, err: ^OuauError) {
	p->EXPECT(.FUNCTION) or_return
	fn_name := p->GET_TEXT()
	node = p->NEW_NODE(.FUNCTION)
	p->SET_NAME(node, fn_name) or_return
	p->ADVANCE() or_return // past 'function name'
	#partial switch p->GET_TOKEN() {
	case .OPEN:
		p->ADVANCE() or_return // past '('
		if !p->IS(.CLOSE) {
			each_param: for !(p->IS(.CLOSE)) {
				#partial switch (p->GET_TOKEN()) {
				case .IDENTIFIER:
					fn_param := p->NEW_NODE(.IDENTIFIER)
					p->SET_NAME(fn_param, p->GET_TEXT())
					p->APPEND_CHILD(node, fn_param)
					p->ADVANCE() or_return // past param
					p->EXPECT(.COMMA) or_return
				case .DOTS:
					p->ADVANCE() or_return // past varargs
					break each_param
				case:
					break each_param
				}
			}
		}
		p->EXPECT(.CLOSE) or_return
	case:
		return node, p->PARSE_ERROR("Invalid Token in Function Declaration")
	}
	body := p->BLOCK() or_return
	p->EXPECT(.END) or_return
	p->APPEND_CHILD(node, body)
	return node, nil
}
@(private = "file", require_results)
PRECEDENCE :: proc(p: ^Parser, prec: Precedence) -> (lhs: NODEID, err: ^OuauError) {
	lhs = p->PREFIX() or_return
	loop: for {
		current_prec := GET_PRECEDENCE(p->GET_TOKEN())
		if prec >= current_prec { break loop }
		lhs = p->INFIX(lhs) or_return
	}
	return lhs, nil
}
@(private = "file", require_results)
GET_PRECEDENCE :: proc(t: Token) -> Precedence {
	#partial switch t {
	case .ASSIGN:
		return .ASSIGN
	case .EQ, .NEQ, .LT, .LE, .GT, .GE, .TILDE, .BOR, .BXOR, .BAND, .OR, .OROR, .AND:
		return .EQUALS
	case .PLUS, .MINUS, .SHR, .SHL:
		return .SUM
	case .MUL, .DIV, .MOD:
		return .PRODUCT
	case .POW, .OPEN, .DOT:
		return .CALL
	case .BANG, .POUND, .NOT:
		return .PREFIX
	case .BOPEN:
		return .INDEX
	case:
		return .LOWEST
	}
}
@(private = "file", require_results)
EXP :: proc(p: ^Parser) -> (exp: NODEID, err: ^OuauError) {
	exp = p->PRECEDENCE(.LOWEST) or_return
	return exp, nil
}
@(private = "file", require_results)
INFIX :: proc(p: ^Parser, lhs: NODEID) -> (infix: NODEID, err: ^OuauError) {
	my_alloc := virtual.arena_allocator(p.arena)
	#partial switch p->GET_TOKEN() {
	case .OPEN:
		p->ADVANCE() or_return // past )
		args := make([dynamic]NODEID, my_alloc)
		if !(p->IS(.CLOSE)) {
			tmp_expression := p->EXP() or_return
			append(&args, tmp_expression)
			for p->IS(.COMMA) {
				p->ADVANCE() or_return // past ,
				tmp_expression := p->EXP() or_return
				append(&args, tmp_expression)
			}
		}
		p->EXPECT(.CLOSE) or_return
		infix = p->NEW_NODE(.CALL)
		p->APPEND_CHILD(infix, lhs)
		for arg in args { p->APPEND_CHILD(infix, arg) }
		return infix, nil
	case .DOT:
		p->ADVANCE() or_return
		if p->IS(.IDENTIFIER) {
			rhs := p->NEW_NODE(.IDENTIFIER)
			p->SET_NAME(rhs, p->GET_TEXT())
			p->ADVANCE() or_return // past identifier
			infix = p->NEW_NODE(.BINARY)
			p->SET_TOKEN(infix, p->GET_TOKEN())
			p->APPEND_CHILD(infix, lhs)
			p->APPEND_CHILD(infix, rhs)
			return infix, nil
		} else {
			return 0, p->PARSE_ERROR("Invalid Identifier in Dot Expression")
		}
	case .BOPEN:
		p->ADVANCE() or_return
		rhs := p->EXP() or_return
		p->EXPECT(.BCLOSE) or_return
		infix := p->NEW_NODE(.BINARY)
		p->SET_TOKEN(infix, .BOPEN)
		p->APPEND_CHILD(infix, lhs)
		p->APPEND_CHILD(infix, rhs)
		return infix, nil
	}
	op_token := p->GET_TOKEN()
	p->ADVANCE() or_return
	rhs := p->PRECEDENCE(GET_PRECEDENCE(p->GET_TOKEN())) or_return
	infix = p->NEW_NODE(.BINARY)
	p->SET_TOKEN(infix, op_token)
	p->APPEND_CHILD(infix, lhs)
	p->APPEND_CHILD(infix, rhs)
	return infix, nil
}
@(private = "file", require_results)
PRIMARY :: proc(p: ^Parser) -> (node: NODEID, err: ^OuauError) {
	#partial switch p->GET_TOKEN() {
	case .NUMBER:
		node = p->NEW_NODE(.LITERAL)
		val, ok := strconv.parse_i64(p->GET_TEXT())
		if !ok { return 0, p->PARSE_ERROR("InvalidNumber::i64") }
		p->SET_INT(node, val)
		p->ADVANCE() or_return
		return node, nil
	case .STRING:
		node = p->NEW_NODE(.STRING)
		p->SET_STRING(node, p->GET_TEXT())
		p->ADVANCE() or_return
		return node, nil
	case .IDENTIFIER:
		node := p->NEW_NODE(.IDENTIFIER)
		p->SET_NAME(node, p->GET_TEXT())
		p->ADVANCE() or_return
		return node, nil
	case .NIL, .TRUE, .FALSE:
		node = p->NEW_NODE(.LITERAL)
		p->SET_STRING(node, p->GET_TEXT())
		p->ADVANCE() or_return
		return node, nil
	case .OPEN:
		p->ADVANCE() or_return
		node = p->EXP() or_return
		p->EXPECT(.CLOSE) or_return
		return node, nil
	case .TOPEN:
		node = p->TABLE() or_return
		return node, nil
	case:
	}
	return p->NEW_NODE(.INVALID), p->PARSE_ERROR("Invalid Token in Primary Expression")
}
@(private = "file", require_results)
PREFIX :: proc(p: ^Parser) -> (prefix_node: NODEID, err: ^OuauError) {
	#partial switch p->GET_TOKEN() {
	case .NOT, .MINUS, .POUND, .BANG:
		prefix_node = p->NEW_NODE(.UNARY)
		p->SET_TOKEN(prefix_node, p->GET_TOKEN())
		p->ADVANCE() or_return
		rhs := p->PREFIX() or_return
		p->APPEND_CHILD(prefix_node, rhs)
		return prefix_node, nil
	case:
		prefix_node = p->PRIMARY() or_return
	}
	return prefix_node, nil
}
@(private = "file", require_results)
EXPLIST :: proc(p: ^Parser) -> (parsed_expressions: []NODEID, err: ^OuauError) {
	my_alloc := virtual.arena_allocator(p.arena)
	list_of_expr := make([dynamic]NODEID, 0, my_alloc)
	expression_node := p->EXP() or_return
	append(&list_of_expr, expression_node)
	#partial switch p->GET_TOKEN() {
	case .COMMA:
		for p->IS(.COMMA) {
			p->ADVANCE() or_return
			expression_node = p->EXP() or_return
			append(&list_of_expr, expression_node)
		}
		parsed_expressions = list_of_expr[:]
		return parsed_expressions, nil
	case:
		parsed_expressions = list_of_expr[:]
		return parsed_expressions, nil
	}
	return parsed_expressions, p->PARSE_ERROR("PARSE_EXPLIST::Unexpected Token in Expression List")
}
@(private = "file", require_results)
TABLE :: proc(p: ^Parser) -> (node: NODEID, err: ^OuauError) {
	p->EXPECT(.TOPEN) or_return
	table := p->NEW_NODE(.TABLE)
	if !(p->IS(.TCLOSE)) {
		tbl_loop: for {
			if p->IS(.OPEN) {
				p->ADVANCE() or_return
				key := p->EXP() or_return
				p->EXPECT(.CLOSE) or_return
				p->EXPECT(.ASSIGN) or_return
				value := p->EXP() or_return
				pair := p->NEW_NODE(.BINARY)
				p->APPEND_CHILD(pair, key)
				p->APPEND_CHILD(pair, value)
				p->APPEND_CHILD(table, pair)
			} else if (p->IS(.IDENTIFIER) || p->IS(.STRING)) && p.peek.kind == .ASSIGN {
				key := p->PRIMARY() or_return // Parse the key (identifier or string)
				p->EXPECT(.ASSIGN) or_return
				value := p->EXP() or_return
				pair := p->NEW_NODE(.BINARY)
				p->APPEND_CHILD(pair, key)
				p->APPEND_CHILD(pair, value)
				p->APPEND_CHILD(table, pair)
			} else if p->IS(.TCLOSE) {
				break tbl_loop
			} else {
				value := p->EXP() or_return
				p->APPEND_CHILD(table, value)
			}
			if p->IS(.TCLOSE) {
				break tbl_loop
			}
			if !(p->IS(.COMMA)) && !(p->IS(.SEMI)) {
				break tbl_loop
			}
			p->ADVANCE() or_return
		}
	}
	p->EXPECT(.TCLOSE) or_return
	return table, nil
}
@(private = "file", require_results)
SET_NAME :: proc(p: ^Parser, node: NODEID, name: string) -> (err: ^OuauError) {
	if p.nodes.name[node] == "" {
		p.nodes.name[node] = name
		return nil
	}
	return p->PARSE_ERROR("Name Already set for node.")
}
@(private = "file", require_results)
SET_STRING :: proc(p: ^Parser, node: NODEID, value: string) -> (err: ^OuauError) {
	if p.nodes.string_value[node] == "" {
		p.nodes.string_value[node] = value
		return nil
	}
	return p->PARSE_ERROR("String Value Already set for node.")
}
@(private = "file", require_results)
SET_INT :: proc(p: ^Parser, node: NODEID, value: i64) -> (err: ^OuauError) {
	if p.nodes.int_value[node] == 0 {
		p.nodes.int_value[node] = value
		return nil
	}
	return p->PARSE_ERROR("Int Value Already set for node.")
}
@(private = "file")
SET_TOKEN :: proc(p: ^Parser, node: NODEID, token: Token) {
	p.nodes.token[node] = token
}
@(private = "file", require_results)
GET_TEXT :: proc(p: ^Parser) -> (text: string) {
	text = string(p.current.text)
	return
}
@(private = "file", require_results)
GET_TOKEN :: proc(p: ^Parser) -> (kind: Token) {
	return p.current.kind
}
@(private = "file", require_results)
IS :: proc(p: ^Parser, kind: Token) -> bool {
	return p.current.kind == kind
}
@(private = "file", require_results)
PEEK_PRECEDENCE :: proc(p: ^Parser) -> Precedence {
	return PRECEDENCES[p.peek.kind]
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
APPEND_CHILD :: proc(p: ^Parser, parent, child: NODEID) {
	if p.nodes.first_child[parent] == 0 {
		p.nodes.first_child[parent] = child
	} else {
		n := p.nodes.first_child[parent]
		for p.nodes.next_sibling[n] != 0 { n = p.nodes.next_sibling[n] }
		p.nodes.next_sibling[n] = child
	}
}
@(private = "file")
PARSE_ERROR :: proc(p: ^Parser, msg: string) -> ^OuauError {
	my_alloc := virtual.arena_allocator(p.arena)
	e := new(OuauError, my_alloc)
	e.kind = .ParseErr
	e.msg = msg
	e.payload = ParseErr {
		msg           = msg,
		parser_object = p,
	}
	return e
}
@(rodata)
PARSER_VTABLE := ParserVTable {
	ADVANCE      = ADVANCE,
	APPEND_CHILD = APPEND_CHILD,
	IS           = IS,
	EXPECT       = EXPECT,
	GET_TEXT     = GET_TEXT,
	GET_TOKEN    = GET_TOKEN,
	NEW_NODE     = NEW_NODE,
	BLOCK        = BLOCK,
	CHUNK        = CHUNK,
	EXP          = EXP,
	EXPLIST      = EXPLIST,
	STMT         = STMT,
	FUNCTION     = FUNCTION,
	UBLOCK       = UBLOCK,
	PREFIX       = PREFIX,
	TABLE        = TABLE,
	PRIMARY      = PRIMARY,
	INFIX        = INFIX,
	PRECEDENCE   = PRECEDENCE,
	SET_NAME     = SET_NAME,
	SET_STRING   = SET_STRING,
	SET_INT      = SET_INT,
	SET_TOKEN    = SET_TOKEN,
	PARSE_ERROR  = PARSE_ERROR,
}

