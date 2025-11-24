package ouau
import "core:mem/virtual"
import "core:strconv"
/*
	 ./parser.odin
	 Copyright(C) 2025 TESTMEE
	 This file defines the parser functions for Ouau.
*/
@(require_results)
CHUNK :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	p->ADVANCE() or_return // Init p.peek
	p->ADVANCE() or_return // Init p.current to p.peek
	node = p->BLOCK() or_return
	return node, nil
}
@(private = "file", require_results)
ADVANCE :: proc(p: ^Parser) -> (err: OuauError) {
	p.current = p.peek
	next_token := p.lexer->NEXT() or_return
	p.peek = next_token
	return nil
}
@(private = "file", require_results)
EXPECT :: proc(p: ^Parser, kind: Token) -> (err: OuauError) {
	if (p->IS(kind)) { return p->ADVANCE() }
	return nil
}
@(private = "file", require_results)
BLOCK :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	node = p->NEW_NODE(.BLOCK)
	block_loop: for {
		#partial switch p->CURRENT_TOKEN() {
		case .SEMI, .END, .ELSE, .ELSEIF:
			p->ADVANCE() or_return
			continue block_loop
		case:
			stmt := p->STMT() or_return
			p->APPEND_CHILD(node, stmt)
		case .EOF:
			break block_loop
		case .ILLEGAL:
			return node, GET_PARSE_ERROR(p, "PARSE_BLOCK::Unexpected teriminal::()")
		}
	}
	return node, nil
}
@(private = "file", require_results)
STMT :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	#partial switch p->CURRENT_TOKEN() {
	case .WHILE:
		node = p->WHILE() or_return
	case .REPEAT:
		node = p->REPEAT() or_return
	case .DO:
		node = p->DO() or_return
	case .IF:
		node = p->IF() or_return
	case .FUNCTION:
		node = p->FUNCTION() or_return
	case .FOR:
		node = p->FOR() or_return
	case .LOCAL:
		node = p->LOCAL() or_return
	case .GLOBAL:
		node = p->GLOBAL() or_return
	case .BREAK:
		node = p->BREAK() or_return
	case .RETURN:
		node = p->RETURN() or_return
	case .OPEN:
		node = p->CALL() or_return
	case:
		node = p->EXPRESSION_STATEMENT() or_return
	}
	return node, nil
}
@(private = "file", require_results)
CALL :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	p->EXPECT(.OPEN) or_return
	args := p->EXPLIST() or_return
	p->EXPECT(.CLOSE) or_return
	node = p->NEW_NODE(.CALL)
	for arg in args { p->APPEND_CHILD(node, arg) }
	return node, nil
}
@(private = "file", require_results)
WHILE :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	p->EXPECT(.WHILE) or_return
	node = p->NEW_NODE(.WHILE)
	cond := p->EXP() or_return
	p->EXPECT(.DO) or_return
	body := p->BLOCK() or_return
	p->EXPECT(.END) or_return
	p->APPEND_CHILD(node, cond)
	p->APPEND_CHILD(node, body)
	return node, nil
}
@(private = "file", require_results)
IF :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
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
	return node, nil
}
@(private = "file", require_results)
EXP :: proc(p: ^Parser) -> (exp: NODEID, err: OuauError) {
	exp = p->PRECEDENCE(.LOWEST) or_return
	return exp, nil
}
@(private = "file", require_results)
PRECEDENCE :: proc(
	p: ^Parser,
	precedence: Precedence,
) -> (
	left_expression: NODEID,
	err: OuauError,
) {
	left_expression = p->PREFIX_EXP() or_return
	loop: for {
		current_prec := GET_PRECEDENCE(p->CURRENT_TOKEN())
		if precedence >= current_prec { break loop }
		left_expression = p->INFIX(left_expression) or_return
	}
	return
}
@(private = "file", require_results)
GET_PRECEDENCE :: proc(tok: Token) -> Precedence {
	#partial switch tok {
	case .ASSIGN:
		return .ASSIGN
	case .EQ, .NEQ, .LT, .LE, .GT, .GE, .TILDE, .BOR, .BXOR, .BAND, .OR, .OROR:
		return .EQUALS
	case .PLUS, .MINUS, .SHR, .SHL:
		return .SUM
	case .MUL, .DIV, .MOD:
		return .PRODUCT
	case .POW, .OPEN, .DOT:
		return .CALL
	case .BANG, .POUND:
		return .PREFIX
	case .BOPEN:
		return .INDEX
	case:
		return .LOWEST
	}
}
@(private = "file", require_results)
INFIX :: proc(p: ^Parser, lhs: NODEID) -> (infix: NODEID, err: OuauError) {
	my_alloc := virtual.arena_allocator(p.arena)
	#partial switch p->CURRENT_TOKEN() {
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
			p->SET_NAME(rhs, p->CURRENT_TEXT())
			p->ADVANCE() or_return // past identifier
			infix = p->NEW_NODE(.BINARY)
			p->SET_NODEID_TOKEN(infix, p->CURRENT_TOKEN())
			p->APPEND_CHILD(infix, lhs)
			p->APPEND_CHILD(infix, rhs)
			return infix, nil
		} else {
			return 0, GET_PARSE_ERROR(p, "Invalid Identifier in Dot Expression")
		}
	case .BOPEN:
		p->ADVANCE() or_return
		p->EXPECT(.BCLOSE) or_return
		rhs := p->PRECEDENCE(.LOWEST) or_return
		infix := p->NEW_NODE(.BINARY)
		p->SET_NODEID_TOKEN(infix, p->CURRENT_TOKEN())
		p->APPEND_CHILD(infix, lhs)
		p->APPEND_CHILD(infix, rhs)
		return infix, nil
	}
	p->ADVANCE() or_return
	rhs := p->PRECEDENCE(GET_PRECEDENCE(p->CURRENT_TOKEN())) or_return
	infix = p->NEW_NODE(.BINARY)
	p->SET_NODEID_TOKEN(infix, p->CURRENT_TOKEN())
	p->APPEND_CHILD(infix, lhs)
	p->APPEND_CHILD(infix, rhs)
	return infix, nil
}
@(private = "file", require_results)
PRIMARY :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	#partial switch p->CURRENT_TOKEN() {
	case .NUMBER:
		node = p->NEW_NODE(.LITERAL)
		val, ok := strconv.parse_i64(p->CURRENT_TEXT())
		if !ok { return 0, GET_PARSE_ERROR(p, "InvalidNumber::i64") }
		p->SET_INT(node, val)
		p->ADVANCE() or_return
		return node, nil
	case .STRING:
		node = p->NEW_NODE(.STRING)
		p->SET_STRING(node, p->CURRENT_TEXT())
		p->ADVANCE() or_return
		return node, nil
	case .IDENTIFIER:
		node := p->NEW_NODE(.IDENTIFIER)
		p->SET_NAME(node, p->CURRENT_TEXT())
		p->ADVANCE() or_return
		return node, nil
	case .NIL, .TRUE, .FALSE:
		node = p->NEW_NODE(.LITERAL)
		p->SET_STRING(node, p->CURRENT_TEXT())
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
		return p->NEW_NODE(.INVALID), GET_PARSE_ERROR(p, "Invalid Token in Primary Expression")
	}
	unreachable()
}
@(private = "file", require_results)
EXPRESSION_STATEMENT :: proc(p: ^Parser) -> (lhs: NODEID, err: OuauError) {
	lhs = p->EXP() or_return
	if p->IS(.ASSIGN) {
		p->ADVANCE() or_return
		assign_node := p->NEW_NODE(.ASSIGN)
		p->APPEND_CHILD(assign_node, lhs)
		rhs := p->EXPLIST() or_return
		for expr in rhs { p->APPEND_CHILD(assign_node, expr) }
		return lhs, nil
	}
	return lhs, nil
}
@(private = "file", require_results)
PREFIX_EXP :: proc(p: ^Parser) -> (prefix_node: NODEID, err: OuauError) {
	#partial switch p->CURRENT_TOKEN() {
	case .NOT, .MINUS, .POUND, .BANG:
		prefix_node = p->NEW_NODE(.UNARY)
		p->SET_NODEID_TOKEN(prefix_node, p->CURRENT_TOKEN())
		p->ADVANCE() or_return
		rhs := p->PREFIX_EXP() or_return
		p->APPEND_CHILD(prefix_node, rhs)
		return prefix_node, nil
	case:
		prefix_node = p->PRIMARY() or_return
	}
	return prefix_node, nil
}
@(private = "file", require_results)
EXPLIST :: proc(p: ^Parser) -> (parsed_expressions: []NODEID, err: OuauError) {
	my_alloc := virtual.arena_allocator(p.arena)
	list_of_expr := make([dynamic]NODEID, 0, my_alloc)
	expression_node := p->EXP() or_return
	append(&list_of_expr, expression_node)
	#partial switch p->CURRENT_TOKEN() {
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
	return parsed_expressions, GET_PARSE_ERROR(
		p,
		"PARSE_EXPLIST::Unexpected Token in Expression List",
	)
}
@(private = "file", require_results)
REPEAT :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	p->EXPECT(.REPEAT) or_return
	node = p->NEW_NODE(.REPEAT)
	ublock := p->UBLOCK() or_return
	p->APPEND_CHILD(node, ublock)
	return node, nil
}
@(private = "file", require_results)
UBLOCK :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	block := p->NEW_NODE(.BLOCK)
	ublock: for {
		#partial switch p->CURRENT_TOKEN() {
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
DO :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	p->EXPECT(.DO) or_return
	node = p->BLOCK() or_return // segfault here.
	p->EXPECT(.END) or_return
	return node, nil
}
@(private = "file", require_results)
FUNCTION :: proc(p: ^Parser) -> (function_node: NODEID, err: OuauError) {
	p->EXPECT(.FUNCTION) or_return
	function_name := p->CURRENT_TEXT()
	function_node = p->NEW_NODE(.FUNCTION)
	p->SET_NAME(function_node, function_name) or_return
	p->ADVANCE() or_return // past 'function name'
	#partial switch p->CURRENT_TOKEN() {
	case .OPEN:
		p->ADVANCE() or_return // past '('
		if !p->IS(.CLOSE) {
			each_param: for !(p->IS(.CLOSE)) {
				#partial switch (p->CURRENT_TOKEN()) {
				case .IDENTIFIER:
					fn_param := p->NEW_NODE(.IDENTIFIER)
					p->SET_NAME(fn_param, p->CURRENT_TEXT())
					p->APPEND_CHILD(function_node, fn_param)
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
		return function_node, GET_PARSE_ERROR(p, "Invalid Token in Function Declaration")
	}
	body := p->BLOCK() or_return
	p->EXPECT(.END) or_return
	p->APPEND_CHILD(function_node, body)
	return function_node, nil
}
@(private = "file", require_results)
FOR :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	p->EXPECT(.FOR) or_return
	induction_var := p->CURRENT_TEXT()
	p->ADVANCE() or_return
	node = p->NEW_NODE(.FOR)
	p->SET_NAME(node, induction_var)
	#partial switch p->CURRENT_TOKEN() {
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
			p->SET_NAME(next_var, p->CURRENT_TEXT())
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
		return node, GET_PARSE_ERROR(p, "Invalid Token in For Loop")
	}
	unreachable()
}
@(private = "file", require_results)
LOCAL :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	my_alloc := virtual.arena_allocator(p.arena)
	p->EXPECT(.LOCAL) or_return
	node = p->NEW_NODE(.LOCAL)
	#partial switch p->CURRENT_TOKEN() {
	case .FUNCTION:
		function_node := p->FUNCTION() or_return
		p->APPEND_CHILD(node, function_node)
		return node, nil
	case .IDENTIFIER:
		vars := make([dynamic]NODEID, my_alloc)
		primary_expr := p->PRIMARY() or_return
		append(&vars, primary_expr)
		#partial switch p->CURRENT_TOKEN() {
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
		return node, GET_PARSE_ERROR(p, "Invalid Token in Local Declaration")
	}
	unreachable()
}
@(private = "file", require_results)
BREAK :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	p->EXPECT(.BREAK) or_return
	node = p->NEW_NODE(.BREAK)
	return node, nil
}
@(private = "file", require_results)
RETURN :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	p->EXPECT(.RETURN) or_return
	node = p->NEW_NODE(.RETURN)
	if !(p->IS(.SEMI)) && !(p->IS(.EOF)) {
		values := p->EXPLIST() or_return
		for val in values { p->APPEND_CHILD(node, val) }
	}
	return node, nil
}
@(private = "file", require_results)
TABLE :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	p->EXPECT(.TOPEN) or_return
	table := p->NEW_NODE(.TABLE)
	if !(p->IS(.TCLOSE)) {
		loop: for {
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
			} else if p->IS(.IDENTIFIER) && p->IS(.ASSIGN) {
				key := p->NEW_NODE(.IDENTIFIER)
				p->SET_NAME(key, p->CURRENT_TEXT())
				p->ADVANCE() or_return
				p->EXPECT(.ASSIGN) or_return
				value := p->EXP() or_return
				pair := p->NEW_NODE(.BINARY)
				p->APPEND_CHILD(pair, key)
				p->APPEND_CHILD(pair, value)
				p->APPEND_CHILD(table, pair)
			} else {
				value := p->EXP() or_return
				p->APPEND_CHILD(table, value)
			}
			if !(p->IS(.COMMA)) && !(p->IS(.SEMI)) {
				break loop
			}
			p->ADVANCE() or_return
		}
	}
	p->EXPECT(.TCLOSE) or_return
	return table, nil
}
@(private = "file", require_results)
GLOBAL :: proc(p: ^Parser) -> (global_node: NODEID, err: OuauError) {
	my_alloc := virtual.arena_allocator(p.arena)
	p->EXPECT(.GLOBAL) or_return
	global_node = p->NEW_NODE(.GLOBAL)
	if p->IS(.FUNCTION) {
		global_node = p->FUNCTION() or_return // return global function
	} else {
		vars := make([dynamic]NODEID, my_alloc)
		primary_node := p->PRIMARY() or_return
		append(&vars, primary_node)
		for p->IS(.COMMA) {
			p->ADVANCE() or_return
			primary_node := p->PRIMARY() or_return
			append(&vars, primary_node)
		}
		for v in vars {
			p->APPEND_CHILD(global_node, v)
		}
		if p->IS(.ASSIGN) {
			p->ADVANCE() or_return
			values := p->EXPLIST() or_return
			for val in values {
				p->APPEND_CHILD(global_node, val)
			}
		}
	}
	return global_node, nil
}
@(private = "file", require_results)
SET_NAME :: proc(p: ^Parser, node: NODEID, name: string) -> (err: OuauError) {
	if p.nodes.name[node] == "" {
		p.nodes.name[node] = name
		return nil
	}
	return GET_PARSE_ERROR(p, "Name Already set for node.")
}
@(private = "file", require_results)
SET_STRING :: proc(p: ^Parser, node: NODEID, value: string) -> (err: OuauError) {
	if p.nodes.string_value[node] == "" {
		p.nodes.string_value[node] = value
		return nil
	}
	return GET_PARSE_ERROR(p, "String Value Already set for node.")
}
@(private = "file", require_results)
SET_INT :: proc(p: ^Parser, node: NODEID, value: i64) -> (err: OuauError) {
	if p.nodes.int_value[node] == 0 {
		p.nodes.int_value[node] = value
		return nil
	}
	return GET_PARSE_ERROR(p, "Int Value Already set for node.")
}
@(private = "file")
SET_NODEID_TOKEN :: proc(p: ^Parser, node: NODEID, token: Token) {
	p.nodes.token[node] = token
}
@(private = "file", require_results)
CURRENT_TEXT :: proc(p: ^Parser) -> (text: string) {
	text = string(p.current.text)
	return
}
@(private = "file", require_results)
CURRENT_TOKEN :: proc(p: ^Parser) -> (kind: Token) {
	return p.current.kind
}
@(private = "file", require_results)
IS :: proc(p: ^Parser, kind: Token) -> bool {
	return p.current.kind == kind
}
@(private = "file", require_results)
IS_TERMINAL :: proc(p: ^Parser) -> bool {
	return(
		p->CURRENT_TOKEN() == .SEMI ||
		p->CURRENT_TOKEN() == .END ||
		p->CURRENT_TOKEN() == .ELSE ||
		p->CURRENT_TOKEN() == .ELSEIF ||
		p->CURRENT_TOKEN() == .EOF ||
		p->CURRENT_TOKEN() == .ILLEGAL \
	)
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
		for p.nodes.next_sibling[n] != 0 {
			n = p.nodes.next_sibling[n]
		}
		p.nodes.next_sibling[n] = child
	}
}
@(rodata)
PARSER_VTABLE := ParserVTable {
	ADVANCE              = ADVANCE,
	APPEND_CHILD         = APPEND_CHILD,
	IS                   = IS,
	EXPECT               = EXPECT,
	CURRENT_TEXT         = CURRENT_TEXT,
	CURRENT_TOKEN        = CURRENT_TOKEN,
	IS_TERMINAL          = IS_TERMINAL,
	NEW_NODE             = NEW_NODE,
	BLOCK                = BLOCK,
	CHUNK                = CHUNK,
	EXP                  = EXP,
	EXPLIST              = EXPLIST,
	STMT                 = STMT,
	WHILE                = WHILE,
	REPEAT               = REPEAT,
	DO                   = DO,
	IF                   = IF,
	FUNCTION             = FUNCTION,
	FOR                  = FOR,
	LOCAL                = LOCAL,
	GLOBAL               = GLOBAL,
	BREAK                = BREAK,
	RETURN               = RETURN,
	CALL                 = CALL,
	EXPRESSION_STATEMENT = EXPRESSION_STATEMENT,
	UBLOCK               = UBLOCK,
	PREFIX_EXP           = PREFIX_EXP,
	TABLE                = TABLE,
	PRIMARY              = PRIMARY,
	INFIX                = INFIX,
	PRECEDENCE           = PRECEDENCE,
	SET_NAME             = SET_NAME,
	SET_STRING           = SET_STRING,
	SET_INT              = SET_INT,
	SET_NODEID_TOKEN     = SET_NODEID_TOKEN,
}

