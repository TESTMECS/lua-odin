package ouau
/*
*	 ./lexer.odin
*	 Copyright(C) 2025 TESTMEE
*	 Defines the lexer functions for Ouau.
*	 @Lexer
*/
@(require_results)
NEXT :: proc(l: ^Lexer) -> (token: TokenDefinition, err: OuauError) {
	l->SKIP_WHITESPACE()
	switch l.ch {
	case '=':
		if l->PEEK() == '=' {
			l->EAT()
			token = GET_TOKEN(.EQ, l.input, l.pos, 2)
		} else { token = GET_TOKEN(.ASSIGN, l.input, l.pos, 1) }
	case '+':
		token = GET_TOKEN(.PLUS, l.input, l.pos, 1)
	case '-':
		token = GET_TOKEN(.MINUS, l.input, l.pos, 1)
	case '*':
		token = GET_TOKEN(.MUL, l.input, l.pos, 1)
	case '.':
		if l->PEEK() == '.' {
			start := l.pos
			l->EAT()
			if l->PEEK() == '.' {
				l->EAT()
				token = GET_TOKEN(.DOTS, l.input, start, 3)
			} else {
				token = GET_TOKEN(.DOTDOT, l.input, start, 2)
			}
		} else {
			token = GET_TOKEN(.DOT, l.input, l.pos, 1)
		}
	case '/':
		token = GET_TOKEN(.DIV, l.input, l.pos, 1)
	case '%':
		token = GET_TOKEN(.MOD, l.input, l.pos, 1)
	case '^':
		token = GET_TOKEN(.POW, l.input, l.pos, 1)
	case '(':
		token = GET_TOKEN(.OPEN, l.input, l.pos, 1)
	case ')':
		token = GET_TOKEN(.CLOSE, l.input, l.pos, 1)
	case '[':
		token = GET_TOKEN(.BOPEN, l.input, l.pos, 1)
	case ']':
		token = GET_TOKEN(.BCLOSE, l.input, l.pos, 1)
	case '{':
		token = GET_TOKEN(.TOPEN, l.input, l.pos, 1)
	case '}':
		token = GET_TOKEN(.TCLOSE, l.input, l.pos, 1)
	case ',':
		token = GET_TOKEN(.COMMA, l.input, l.pos, 1)
	case ':':
		token = GET_TOKEN(.COLON, l.input, l.pos, 1)
	case ';':
		token = GET_TOKEN(.SEMI, l.input, l.pos, 1)
	case '<':
		if l->PEEK() == '=' {
			start := l.pos
			l->EAT()
			token = GET_TOKEN(.LE, l.input, start, 2)
		} else if l->PEEK() == '<' {
			start := l.pos
			l->EAT()
			token = GET_TOKEN(.SHL, l.input, start, 2)
		} else { token = GET_TOKEN(.LT, l.input, l.pos, 1) }
	case '>':
		if l->PEEK() == '=' {
			start := l.pos
			l->EAT()
			token = GET_TOKEN(.GE, l.input, start, 2)
		} else if l->PEEK() == '>' {
			start := l.pos
			l->EAT()
			token = GET_TOKEN(.SHR, l.input, start, 2)
		} else { token = GET_TOKEN(.GT, l.input, l.pos, 1) }
	case '~':
		if l->PEEK() == '=' {
			start := l.pos
			l->EAT()
			token = GET_TOKEN(.NEQ, l.input, start, 2)
		} else { token = GET_TOKEN(.TILDE, l.input, l.pos, 1) }
	case '|':
		if l->PEEK() == '|' {
			start := l.pos
			l->EAT()
			token = GET_TOKEN(.OROR, l.input, start, 2)
		} else { token = GET_TOKEN(.OR, l.input, l.pos, 1) }
	case '&':
		if l->PEEK() == '&' {
			start := l.pos
			l->EAT()
			token = GET_TOKEN(.ANDAND, l.input, start, 2)
		} else { token = GET_TOKEN(.AND, l.input, l.pos, 1) }
	case '!':
		token = GET_TOKEN(.BANG, l.input, l.pos, 1)
	case '#':
		token = GET_TOKEN(.POUND, l.input, l.pos, 1)
	case '"':
		token = CREATE_STRING(l)
	case 0:
		token.text = {}
		token.kind = .EOF
	case:
		if IS_LETTER(l.ch) {
			token = CREATE_IDENTIFIER_OR_KEYWORD(l)
			return token, nil
		} else if IS_DIGIT(l.ch) { return CREATE_NUMBER(l), nil }
		token = GET_TOKEN(.ILLEGAL, l.input, l.pos, 1)
	}
	l->EAT()
	if token.kind == .ILLEGAL { return token, SYNTAX_ERROR(l, token) }
	return token, nil
}
@(private = "file")
GET_TOKEN :: proc(type: Token, input: []u8, start: int, length: int) -> TokenDefinition {
	// input := l.input
	// start := l.pos
	return TokenDefinition{kind = type, text = input[start:start + length]}
}
@(private = "file")
IS_LETTER :: proc(ch: u8) -> bool {
	return 'a' <= ch && ch <= 'z' || 'A' <= ch && ch <= 'Z' || ch == '_'
}
@(private = "file")
IS_DIGIT :: proc(ch: u8) -> bool {
	return '0' <= ch && ch <= '9'
}
@(private = "file")
TOKEN_FROM_CHAR :: proc(l: ^Lexer, ty: Token) -> TokenDefinition {
	return GET_TOKEN(ty, l.input, l.pos, 1)
}
@(private = "file")
SKIP_WHITESPACE :: proc(l: ^Lexer) {
	for l.ch == ' ' || l.ch == '\t' || l.ch == '\n' || l.ch == '\r' {
		l->EAT()
	}
}
@(private = "file")
EAT :: proc(l: ^Lexer) {
	if l.pos >= len(l.input) - 1 {
		l.ch = 0
	} else {
		l.ch = l.input[l.read_pos]
	}
	l.pos = l.read_pos
	l.read_pos += 1
}
@(private = "file")
PEEK :: proc(l: ^Lexer) -> u8 {
	return l.read_pos >= len(l.input) ? 0 : l.input[l.read_pos]
}
@(private = "file")
CREATE_IDENTIFIER_OR_KEYWORD :: proc(l: ^Lexer) -> TokenDefinition {
	start := l.pos
	l->EAT()
	for IS_LETTER(l.ch) || IS_DIGIT(l.ch) { l->EAT() }
	// Check if keyword first
	text := string(l.input[start:l.pos])
	if ok, kind := LOOKUP_KEYWORD(text); ok {
		return GET_TOKEN(kind, l.input, start, l.pos - start)
	}
	return GET_TOKEN(.IDENTIFIER, l.input, start, l.pos - start)
}
@(private = "file")
CREATE_NUMBER :: proc(l: ^Lexer) -> TokenDefinition {
	start := l.pos
	for IS_DIGIT(l.ch) { l->EAT() }
	if l.ch == '.' {
		l->EAT()
		for IS_DIGIT(l.ch) { l->EAT() }
		return GET_TOKEN(.NUMBER, l.input, start, l.pos - start)
	}
	return GET_TOKEN(.NUMBER, l.input, start, l.pos - start)
}
@(private = "file")
CREATE_STRING :: proc(l: ^Lexer) -> TokenDefinition {
	start := l.pos + 1
	read_string: for {
		l->EAT()
		if l.ch == '"' || l.ch == 0 { break read_string }
	}
	return GET_TOKEN(.STRING, l.input, start, l.pos - start)
}
@(rodata)
LEXER_VTABLE := LexerVTable {
	NEXT            = NEXT,
	EAT             = EAT,
	PEEK            = PEEK,
	SKIP_WHITESPACE = SKIP_WHITESPACE,
}

