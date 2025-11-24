package ouau
import "core:mem/virtual"
import "core:strconv"
/*
	 ./parser.odin
	 Copyright(C) 2025 TESTMEE
	 This file defines the parser functions for Ouau.
*/
@(require_results)
PARSE_CHUNK :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	p->ADVANCE() or_return // Init p.peek
	p->ADVANCE() or_return // Init p.current to p.peek
	node = p->PARSE_BLOCK() or_return
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
	if p->CURRENT_IS(kind) { return p->ADVANCE() }
	return nil
}
@(private = "file", require_results)
PARSE_BLOCK :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	node = p->NEW_NODE(.BLOCK)
	block_loop: for {
		#partial switch p->CURRENT_TOKEN() {
		case .SEMI, .END, .ELSE, .ELSEIF:
			p->ADVANCE() or_return
			continue block_loop
		case .ILLEGAL:
			return node, GET_PARSE_ERROR(p, "PARSE_BLOCK::Unexpected teriminal::()")
		case .EOF:
			break block_loop
		case:
			child := p->PARSE_STMT() or_return
			p->APPEND_NODEID_CHILD(node, child)
		}
	}
	return node, nil
}
@(private = "file", require_results)
PARSE_STMT :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	#partial switch p->CURRENT_TOKEN() {
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
	for arg in args { p->APPEND_NODEID_CHILD(call_node, arg) }
	return call_node, nil
}
@(require_results)
PARSE_WHILE :: proc(p: ^Parser) -> (while_node: NODEID, err: OuauError) {
	p->EXPECT(.WHILE) or_return
	while_node = p->NEW_NODE(.WHILE)
	cond := p->PARSE_EXP() or_return
	p->EXPECT(.DO) or_return
	body := p->PARSE_BLOCK() or_return
	p->EXPECT(.END) or_return
	p->APPEND_NODEID_CHILD(while_node, cond)
	p->APPEND_NODEID_CHILD(while_node, body)
	return while_node, nil
}
@(private = "file", require_results)
PARSE_IF :: proc(p: ^Parser) -> (if_node: NODEID, err: OuauError) {
	p->EXPECT(.IF) or_return
	if_node = p->NEW_NODE(.IF)
	cond := p->PARSE_EXP() or_return
	p->EXPECT(.THEN) or_return
	blk := p->PARSE_BLOCK() or_return
	p->APPEND_NODEID_CHILD(if_node, cond)
	p->APPEND_NODEID_CHILD(if_node, blk)
	for p->CURRENT_IS(.ELSEIF) {
		p->ADVANCE() or_return // past 'elseif'
		econd := p->PARSE_EXP() or_return
		p->EXPECT(.THEN) or_return
		eblk := p->PARSE_BLOCK() or_return
		p->APPEND_NODEID_CHILD(if_node, econd)
		p->APPEND_NODEID_CHILD(if_node, eblk)
	}
	if p->CURRENT_IS(.ELSE) {
		p->ADVANCE() or_return
		eblk := p->PARSE_BLOCK() or_return
		p->APPEND_NODEID_CHILD(if_node, eblk)
	}
	p->EXPECT(.END) or_return
	return if_node, nil
}
@(private = "file", require_results)
PARSE_EXP :: proc(p: ^Parser) -> (exp: NODEID, err: OuauError) {
	exp = p->PARSE_PRECEDENCE(.LOWEST) or_return
	return exp, nil
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
	loop: for {
		current_prec := GET_PRECEDENCE(p->CURRENT_TOKEN())
		if precedence >= current_prec { break loop }
		left_expression = p->PARSE_INFIX(left_expression) or_return
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
PARSE_INFIX :: proc(p: ^Parser, lhs: NODEID) -> (infix: NODEID, err: OuauError) {
	my_alloc := virtual.arena_allocator(p.arena)
	#partial switch p->CURRENT_TOKEN() {
	case .OPEN:
		p->ADVANCE() or_return // past )
		args := make([dynamic]NODEID, my_alloc)
		if !(p->CURRENT_IS(.CLOSE)) {
			tmp_expression := p->PARSE_EXP() or_return
			append(&args, tmp_expression)
			for p->CURRENT_IS(.COMMA) {
				p->ADVANCE() or_return // past ,
				tmp_expression := p->PARSE_EXP() or_return
				append(&args, tmp_expression)
			}
		}
		p->EXPECT(.CLOSE) or_return
		infix = p->NEW_NODE(.CALL)
		p->APPEND_NODEID_CHILD(infix, lhs)
		for arg in args { p->APPEND_NODEID_CHILD(infix, arg) }
		return infix, nil
	case .DOT:
		p->ADVANCE() or_return
		#partial switch p->CURRENT_TOKEN() {
		case .IDENTIFIER:
			rhs := p->NEW_NODE(.IDENTIFIER)
			p->SET_NODEID_NAME(rhs, p->CURRENT_TEXT())
			p->ADVANCE() or_return // past identifier
			infix = p->NEW_NODE(.BINARY)
			p->SET_NODEID_TOKEN(infix, p->CURRENT_TOKEN())
			p->APPEND_NODEID_CHILD(infix, lhs)
			p->APPEND_NODEID_CHILD(infix, rhs)
			return infix, nil
		case:
			return 0, GET_PARSE_ERROR(p, "Invalid Identifier in Dot Expression")
		}
	case .BOPEN:
		p->ADVANCE() or_return
		p->EXPECT(.BCLOSE) or_return
		rhs := p->PARSE_PRECEDENCE(.LOWEST) or_return
		infix := p->NEW_NODE(.BINARY)
		p->SET_NODEID_TOKEN(infix, p->CURRENT_TOKEN())
		p->APPEND_NODEID_CHILD(infix, lhs)
		p->APPEND_NODEID_CHILD(infix, rhs)
		return infix, nil
	}
	p->ADVANCE() or_return
	rhs := p->PARSE_PRECEDENCE(GET_PRECEDENCE(p->CURRENT_TOKEN())) or_return
	infix = p->NEW_NODE(.BINARY)
	p->SET_NODEID_TOKEN(infix, p->CURRENT_TOKEN())
	p->APPEND_NODEID_CHILD(infix, lhs)
	p->APPEND_NODEID_CHILD(infix, rhs)
	return infix, nil
}
@(private = "file", require_results)
PARSE_PRIMARY :: proc(p: ^Parser) -> (primary_node: NODEID, err: OuauError) {
	#partial switch p->CURRENT_TOKEN() {
	case .NUMBER:
		primary_node = p->NEW_NODE(.LITERAL)
		val, ok := strconv.parse_i64(p->CURRENT_TEXT())
		if !ok { return 0, GET_PARSE_ERROR(p, "InvalidNumber::i64") }
		p->SET_INT_VALUE(primary_node, val)
		p->ADVANCE() or_return
		return primary_node, nil
	case .STRING:
		primary_node = p->NEW_NODE(.STRING)
		p->SET_STRING_VALUE(primary_node, p->CURRENT_TEXT())
		p->ADVANCE() or_return
		return primary_node, nil
	case .IDENTIFIER:
		primary_node := p->NEW_NODE(.IDENTIFIER)
		p->SET_NODEID_NAME(primary_node, p->CURRENT_TEXT())
		p->ADVANCE() or_return
		return primary_node, nil
	case .NIL, .TRUE, .FALSE:
		primary_node = p->NEW_NODE(.LITERAL)
		p->SET_STRING_VALUE(primary_node, p->CURRENT_TEXT())
		p->ADVANCE() or_return
		return primary_node, nil
	case .OPEN:
		p->ADVANCE() or_return
		primary_node = p->PARSE_EXP() or_return
		p->EXPECT(.CLOSE) or_return
		return primary_node, nil
	case .TOPEN:
		primary_node = p->PARSE_TABLE() or_return
		return primary_node, nil
	case:
	}
	return p->NEW_NODE(.INVALID), nil
}
@(private = "file", require_results)
PARSE_EXPRESSION_STATEMENT :: proc(p: ^Parser) -> (lhs: NODEID, err: OuauError) {
	lhs = p->PARSE_EXP() or_return
	if p->CURRENT_IS(.ASSIGN) {
		p->ADVANCE() or_return
		assign_node := p->NEW_NODE(.ASSIGN)
		p->APPEND_NODEID_CHILD(assign_node, lhs)
		rhs := p->PARSE_EXPLIST() or_return
		for expr in rhs { p->APPEND_NODEID_CHILD(assign_node, expr) }
		return lhs, nil
	}
	return lhs, nil
}
@(private = "file", require_results)
PARSE_PREFIX_EXP :: proc(p: ^Parser) -> (prefix_node: NODEID, err: OuauError) {
	#partial switch p->CURRENT_TOKEN() {
	case .NOT, .MINUS, .POUND, .BANG:
		prefix_node = p->NEW_NODE(.UNARY)
		p->SET_NODEID_TOKEN(prefix_node, p->CURRENT_TOKEN())
		p->ADVANCE() or_return
		rhs := p->PARSE_PREFIX_EXP() or_return
		p->APPEND_NODEID_CHILD(prefix_node, rhs)
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
	append(&list_of_expr, expression_node)
	#partial switch p->CURRENT_TOKEN() {
	case .COMMA:
		for p->CURRENT_IS(.COMMA) {
			p->ADVANCE() or_return
			expression_node = p->PARSE_EXP() or_return
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
PARSE_REPEAT :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	p->EXPECT(.REPEAT) or_return
	node = p->NEW_NODE(.REPEAT)
	ublock := p->PARSE_UBLOCK() or_return
	p->APPEND_NODEID_CHILD(node, ublock)
	return node, nil
}
@(private = "file", require_results)
PARSE_UBLOCK :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	block := p->NEW_NODE(.BLOCK)
	ublock: for {
		#partial switch p->CURRENT_TOKEN() {
		case .SEMI:
			p->ADVANCE() or_return
			continue ublock
		case .UNTIL:
			break ublock
		case:
			child := p->PARSE_STMT() or_return
			p->APPEND_NODEID_CHILD(block, child)
		}
	}
	p->EXPECT(.UNTIL) or_return
	cond := p->PARSE_EXP() or_return
	node = p->NEW_NODE(.UBLOCK)
	p->APPEND_NODEID_CHILD(node, block)
	p->APPEND_NODEID_CHILD(node, cond)
	return node, nil
}
@(private = "file", require_results)
PARSE_DO :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	p->EXPECT(.DO) or_return
	node = p->PARSE_BLOCK() or_return // segfault here.
	p->EXPECT(.END) or_return
	return node, nil
}
@(private = "file", require_results)
PARSE_FUNCTION :: proc(p: ^Parser) -> (function_node: NODEID, err: OuauError) {
	p->EXPECT(.FUNCTION) or_return
	function_name := p->CURRENT_TEXT()
	function_node = p->NEW_NODE(.FUNCTION)
	p->SET_NODEID_NAME(function_node, function_name) or_return
	p->ADVANCE() or_return // past 'function name'
	#partial switch p->CURRENT_TOKEN() {
	case .OPEN:
		p->ADVANCE() or_return // past '('
		if !p->CURRENT_IS(.CLOSE) {
			fn_parameters: for !p->CURRENT_IS(.CLOSE) {
				#partial switch p->CURRENT_TOKEN() {
				case .IDENTIFIER:
					function_parameter := p->NEW_NODE(.IDENTIFIER)
					p->SET_NODEID_NAME(function_parameter, p->CURRENT_TEXT())
					p->APPEND_NODEID_CHILD(function_node, function_parameter)
					p->ADVANCE() or_return // past param
					p->EXPECT(.COMMA) or_return
				case .DOTS:
					p->ADVANCE() or_return // past varargs
					break fn_parameters
				case:
					break fn_parameters
				}
			}
		}
		p->EXPECT(.CLOSE) or_return
	case:
		return function_node, GET_PARSE_ERROR(p, "Invalid Token in Function Declaration")
	}
	body := p->PARSE_BLOCK() or_return
	p->EXPECT(.END) or_return
	p->APPEND_NODEID_CHILD(function_node, body)
	return function_node, nil
}
@(private = "file", require_results)
PARSE_FOR :: proc(p: ^Parser) -> (for_node: NODEID, err: OuauError) {
	p->EXPECT(.FOR) or_return
	var_name := p->CURRENT_TEXT()
	p->ADVANCE() or_return
	for_node = p->NEW_NODE(.FOR)
	p->SET_NODEID_NAME(for_node, var_name)
	#partial switch p->CURRENT_TOKEN() {
	case .ASSIGN:
		p->ADVANCE() or_return
		init := p->PARSE_EXP() or_return
		p->EXPECT(.COMMA) or_return
		limit := p->PARSE_EXP() or_return
		p->APPEND_NODEID_CHILD(for_node, init)
		p->APPEND_NODEID_CHILD(for_node, limit)
		if p->CURRENT_IS(.COMMA) {
			p->ADVANCE() or_return
			step := p->PARSE_EXP() or_return
			p->APPEND_NODEID_CHILD(for_node, step)
		}
		p->EXPECT(.DO) or_return
		body := p->PARSE_BLOCK() or_return
		p->EXPECT(.END) or_return
		p->APPEND_NODEID_CHILD(for_node, body)
	case .COMMA:
		for p->CURRENT_IS(.COMMA) {
			p->ADVANCE() or_return
			next_var := p->NEW_NODE(.IDENTIFIER)
			p->SET_NODEID_NAME(next_var, p->CURRENT_TEXT())
			p->ADVANCE() or_return
			p->APPEND_NODEID_CHILD(for_node, next_var)
		}
	case .IN:
		p->EXPECT(.IN) or_return
		iter := p->PARSE_EXPLIST() or_return
		for exp in iter { p->APPEND_NODEID_CHILD(for_node, exp) }
		p->EXPECT(.DO) or_return
		body := p->PARSE_BLOCK() or_return
		p->EXPECT(.END) or_return
		p->APPEND_NODEID_CHILD(for_node, body)
	case:
		return for_node, GET_PARSE_ERROR(p, "Invalid Token in For Loop")
	}
	unreachable()
}
@(private = "file", require_results)
PARSE_LOCAL :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	my_alloc := virtual.arena_allocator(p.arena)
	p->EXPECT(.LOCAL) or_return
	node = p->NEW_NODE(.LOCAL)
	#partial switch p->CURRENT_TOKEN() {
	case .FUNCTION:
		function_node := p->PARSE_FUNCTION() or_return
		p->APPEND_NODEID_CHILD(node, function_node)
		return node, nil
	case .IDENTIFIER:
		vars := make([dynamic]NODEID, my_alloc)
		primary_expr := p->PARSE_PRIMARY() or_return
		append(&vars, primary_expr)
		#partial switch p->CURRENT_TOKEN() {
		case .COMMA:
			for p->CURRENT_IS(.COMMA) {
				p->ADVANCE() or_return
				primary_expr = p->PARSE_PRIMARY() or_return
				append(&vars, primary_expr)
			}
			for v in vars { p->APPEND_NODEID_CHILD(node, v) }
			if p->CURRENT_IS(.ASSIGN) {
				p->ADVANCE() or_return
				values := p->PARSE_EXPLIST() or_return
				for val in values {
					p->APPEND_NODEID_CHILD(node, val)
				}
			}
		case .ASSIGN:
			p->ADVANCE() or_return
			for v in vars { p->APPEND_NODEID_CHILD(node, v) }
			values := p->PARSE_EXPLIST() or_return
			for val in values { p->APPEND_NODEID_CHILD(node, val) }
		case:
			for v in vars { p->APPEND_NODEID_CHILD(node, v) }
		}
		return node, nil
	case:
		return node, GET_PARSE_ERROR(p, "Invalid Token in Local Declaration")
	}
	unreachable()
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
	if !(p->CURRENT_IS(.SEMI)) && !(p->CURRENT_IS(.EOF)) {
		values := p->PARSE_EXPLIST() or_return
		for val in values { p->APPEND_NODEID_CHILD(node, val) }
	}
	return node, nil
}
@(private = "file", require_results)
PARSE_TABLE :: proc(p: ^Parser) -> (node: NODEID, err: OuauError) {
	p->EXPECT(.TOPEN) or_return
	table := p->NEW_NODE(.TABLE)
	if !(p->CURRENT_IS(.TCLOSE)) {
		loop: for {
			if p->CURRENT_IS(.OPEN) {
				p->ADVANCE() or_return
				key := p->PARSE_EXP() or_return
				p->EXPECT(.CLOSE) or_return
				p->EXPECT(.ASSIGN) or_return
				value := p->PARSE_EXP() or_return
				pair := p->NEW_NODE(.BINARY)
				p->APPEND_NODEID_CHILD(pair, key)
				p->APPEND_NODEID_CHILD(pair, value)
				p->APPEND_NODEID_CHILD(table, pair)
			} else if p->CURRENT_IS(.IDENTIFIER) && p->CURRENT_IS(.ASSIGN) {
				key := p->NEW_NODE(.IDENTIFIER)
				p->SET_NODEID_NAME(key, p->CURRENT_TEXT())
				p->ADVANCE() or_return
				p->EXPECT(.ASSIGN) or_return
				value := p->PARSE_EXP() or_return
				pair := p->NEW_NODE(.BINARY)
				p->APPEND_NODEID_CHILD(pair, key)
				p->APPEND_NODEID_CHILD(pair, value)
				p->APPEND_NODEID_CHILD(table, pair)
			} else {
				value := p->PARSE_EXP() or_return
				p->APPEND_NODEID_CHILD(table, value)
			}
			if !(p->CURRENT_IS(.COMMA)) && !(p->CURRENT_IS(.SEMI)) {
				break loop
			}
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
	if p->CURRENT_IS(.FUNCTION) {
		global_node = p->PARSE_FUNCTION() or_return // return global function
	} else {
		vars := make([dynamic]NODEID, my_alloc)
		primary_node := p->PARSE_PRIMARY() or_return
		append(&vars, primary_node)
		for p->CURRENT_IS(.COMMA) {
			p->ADVANCE() or_return
			primary_node := p->PARSE_PRIMARY() or_return
			append(&vars, primary_node)
		}
		for v in vars {
			p->APPEND_NODEID_CHILD(global_node, v)
		}
		if p->CURRENT_IS(.ASSIGN) {
			p->ADVANCE() or_return
			values := p->PARSE_EXPLIST() or_return
			for val in values {
				p->APPEND_NODEID_CHILD(global_node, val)
			}
		}
	}
	return global_node, nil
}
@(private = "file", require_results)
SET_NODEID_NAME :: proc(p: ^Parser, node: NODEID, name: string) -> (err: OuauError) {
	if p.nodes.name[node] == "" {
		p.nodes.name[node] = name
		return nil
	}
	return GET_PARSE_ERROR(p, "Name Already set for node.")
}
@(private = "file", require_results)
SET_STRING_VALUE :: proc(p: ^Parser, node: NODEID, value: string) -> (err: OuauError) {
	if p.nodes.string_value[node] == "" {
		p.nodes.string_value[node] = value
		return nil
	}
	return GET_PARSE_ERROR(p, "String Value Already set for node.")
}
@(private = "file", require_results)
SET_INT_VALUE :: proc(p: ^Parser, node: NODEID, value: i64) -> (err: OuauError) {
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
CURRENT_IS :: proc(p: ^Parser, kind: Token) -> bool {
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
APPEND_NODEID_CHILD :: proc(p: ^Parser, parent, child: NODEID) {
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
	ADVANCE                    = ADVANCE,
	APPEND_NODEID_CHILD        = APPEND_NODEID_CHILD,
	CURRENT_IS                 = CURRENT_IS,
	EXPECT                     = EXPECT,
	CURRENT_TEXT               = CURRENT_TEXT,
	CURRENT_TOKEN              = CURRENT_TOKEN,
	IS_TERMINAL                = IS_TERMINAL,
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
	SET_NODEID_NAME            = SET_NODEID_NAME,
	SET_STRING_VALUE           = SET_STRING_VALUE,
	SET_INT_VALUE              = SET_INT_VALUE,
	SET_NODEID_TOKEN           = SET_NODEID_TOKEN,
}

