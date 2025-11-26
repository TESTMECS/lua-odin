package ouau
import "core:fmt"
import "core:mem/virtual"
/*
*	 ./lexer.odin
*	 Copyright(C) 2025 TESTMEE
*	 Defines the lexer functions for Ouau.
*	 @Lexer
*/
@(require_results)
NEXT :: proc(l: ^Lexer) -> (token: TokenDefinition, err: ^OuauError) {
	l->SKIP_WHITESPACE()
	switch l.ch {
	case '=':
		if l->PEEK() == '=' {
			l->EAT()
			token = l->GET_TOKEN(.EQ, l.pos, 2)
		} else { token = l->GET_TOKEN(.ASSIGN, l.pos, 1) }
	case '+':
		token = l->GET_TOKEN(.PLUS, l.pos, 1)
	case '-':
		token = l->GET_TOKEN(.MINUS, l.pos, 1)
	case '*':
		token = l->GET_TOKEN(.MUL, l.pos, 1)
	case '.':
		if l->PEEK() == '.' {
			start := l.pos
			l->EAT()
			if l->PEEK() == '.' {
				l->EAT()
				token = l->GET_TOKEN(.DOTS, start, 3)
			} else {
				token = l->GET_TOKEN(.DOTDOT, start, 2)
			}
		} else {
			token = l->GET_TOKEN(.DOT, l.pos, 1)
		}
	case '/':
		token = l->GET_TOKEN(.DIV, l.pos, 1)
	case '%':
		token = l->GET_TOKEN(.MOD, l.pos, 1)
	case '^':
		token = l->GET_TOKEN(.POW, l.pos, 1)
	case '(':
		token = l->GET_TOKEN(.OPEN, l.pos, 1)
	case ')':
		token = l->GET_TOKEN(.CLOSE, l.pos, 1)
	case '[':
		token = l->GET_TOKEN(.BOPEN, l.pos, 1)
	case ']':
		token = l->GET_TOKEN(.BCLOSE, l.pos, 1)
	case '{':
		token = l->GET_TOKEN(.TOPEN, l.pos, 1)
	case '}':
		token = l->GET_TOKEN(.TCLOSE, l.pos, 1)
	case ',':
		token = l->GET_TOKEN(.COMMA, l.pos, 1)
	case ':':
		token = l->GET_TOKEN(.COLON, l.pos, 1)
	case ';':
		token = l->GET_TOKEN(.SEMI, l.pos, 1)
	case '<':
		if l->PEEK() == '=' {
			start := l.pos
			l->EAT()
			token = l->GET_TOKEN(.LE, start, 2)
		} else if l->PEEK() == '<' {
			start := l.pos
			l->EAT()
			token = l->GET_TOKEN(.SHL, start, 2)
		} else { token = l->GET_TOKEN(.LT, l.pos, 1) }
	case '>':
		if l->PEEK() == '=' {
			start := l.pos
			l->EAT()
			token = l->GET_TOKEN(.GE, start, 2)
		} else if l->PEEK() == '>' {
			start := l.pos
			l->EAT()
			token = l->GET_TOKEN(.SHR, start, 2)
		} else { token = l->GET_TOKEN(.GT, l.pos, 1) }
	case '~':
		if l->PEEK() == '=' {
			start := l.pos
			l->EAT()
			token = l->GET_TOKEN(.NEQ, start, 2)
		} else { token = l->GET_TOKEN(.TILDE, l.pos, 1) }
	case '|':
		if l->PEEK() == '|' {
			start := l.pos
			l->EAT()
			token = l->GET_TOKEN(.OROR, start, 2)
		} else { token = l->GET_TOKEN(.OR, l.pos, 1) }
	case '&':
		if l->PEEK() == '&' {
			start := l.pos
			l->EAT()
			token = l->GET_TOKEN(.ANDAND, start, 2)
		} else { token = l->GET_TOKEN(.AND, l.pos, 1) }
	case '!':
		token = l->GET_TOKEN(.BANG, l.pos, 1)
	case '#':
		token = l->GET_TOKEN(.POUND, l.pos, 1)
	case '"':
		token = CREATE_STRING(l)
	case 0:
		token.text = {}
		token.kind = .EOF
	case:
		if IS_LETTER(l.ch) {
			token = l->CREATE_IDENTIFIER_OR_KEYWORD()
			return token, nil
		} else if IS_DIGIT(l.ch) {
			return l->CREATE_NUMBER(), nil
		} else {
			token = l->GET_TOKEN(.ILLEGAL, l.pos, 1)
		}
	}
	l->EAT()
	if token.kind == .ILLEGAL { return token, l->SYNTAX_ERROR("Illegal Token", token) }
	return token, nil
}
@(private = "file")
GET_TOKEN :: proc(l: ^Lexer, type: Token, start: int, length: int) -> TokenDefinition {
	input := l.input
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
	return l->GET_TOKEN(ty, l.pos, 1)
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
	text := string(l.input[start:l.pos])
	if ok, kind := LOOKUP_KEYWORD(text); ok {
		return l->GET_TOKEN(kind, start, (l.pos - start))
	}
	return l->GET_TOKEN(.IDENTIFIER, start, (l.pos - start))
}
@(private = "file")
CREATE_NUMBER :: proc(l: ^Lexer) -> TokenDefinition {
	start := l.pos
	for IS_DIGIT(l.ch) { l->EAT() }
	if l.ch == '.' {
		l->EAT()
		for IS_DIGIT(l.ch) { l->EAT() }
		return l->GET_TOKEN(.NUMBER, start, (l.pos - start))
	}
	return l->GET_TOKEN(.NUMBER, start, l.pos - start)
}
@(private = "file")
CREATE_STRING :: proc(l: ^Lexer) -> TokenDefinition {
	start := l.pos + 1
	read_string: for {
		l->EAT()
		if l.ch == '"' || l.ch == 0 { break read_string }
	}
	return l->GET_TOKEN(.STRING, start, (l.pos - start))
}
@(private = "file")
SYNTAX_ERROR :: proc(l: ^Lexer, my_msg: string, token: TokenDefinition) -> ^OuauError {
	my_alloc := virtual.arena_allocator(l.arena)
	e := new(OuauError, my_alloc)
	e.kind = .SyntaxErr
	e.msg = my_msg
	e.payload = SyntaxErr {
		pos  = l.pos,
		kind = token.kind,
		text = string(token.text),
	}
	fmt.eprintfln("Syntax Error::Msg::(%s)|", e.msg)
	fmt.eprintfln("Payload::(%v)|", e.payload)
	fmt.eprintfln("Kind::(%v)|", token.kind)
	fmt.eprintfln("Text::(%s)|", token.text)
	return e
}
@(rodata)
LEXER_VTABLE := LexerVTable {
	NEXT                         = NEXT,
	EAT                          = EAT,
	PEEK                         = PEEK,
	GET_TOKEN                    = GET_TOKEN,
	SKIP_WHITESPACE              = SKIP_WHITESPACE,
	CREATE_NUMBER                = CREATE_NUMBER,
	CREATE_IDENTIFIER_OR_KEYWORD = CREATE_IDENTIFIER_OR_KEYWORD,
	SYNTAX_ERROR                 = SYNTAX_ERROR,
}

