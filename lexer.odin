package ouau
/*
*	 ./lexer.odin
*	 Copyright(C) 2025 TESTMEE
*	 Defines the lexer functions for Ouau.
*	 @Lexer
*/
Token :: enum u8 {
	EOF,
	ILLEGAL,
	// keywords
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
	// operators
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
	DOTS,
	BAND,
	BOR,
	BANG,
	// punctuation
	OPEN,
	CLOSE,
	// other
	IDENTIFIER,
	NUMBER,
	STRING,
	TOPEN,
	TCLOSE,
	BOPEN,
	BCLOSE,
}
TokenDefinition :: struct {
	kind: Token,
	text: []u8,
}
Lexer :: struct {
	input:    []u8,
	ch:       u8, //current character
	pos:      int,
	read_pos: int,
	NEXT:     proc(l: ^Lexer) -> (TokenDefinition, OuauError),
}
@(require_results)
NEW_LEXER :: proc(input: string) -> Lexer {
	l := Lexer {
		ch       = 0,
		input    = transmute([]u8)input,
		pos      = 0,
		read_pos = 0,
		NEXT     = NEXT,
	}
	EAT(&l)
	return l
}
@(require_results)
NEXT :: proc(l: ^Lexer) -> (tok: TokenDefinition, err: OuauError) {
	SKIP_WHITESPACE(l)
	switch l.ch {
	case '=':
		if PEEK(l) == '=' {
			start := l.pos
			EAT(l)
			tok = GET_TOKEN(.EQ, l.input, start, 2)
		}
		 else do tok = GET_TOKEN(.ASSIGN, l.input, l.pos, 1)
	case '+':
		tok = GET_TOKEN(.PLUS, l.input, l.pos, 1)
	case '-':
		tok = GET_TOKEN(.MINUS, l.input, l.pos, 1)
	case '*':
		tok = GET_TOKEN(.MUL, l.input, l.pos, 1)
	case '.':
		if PEEK(l) == '.' {
			start := l.pos
			EAT(l)
			tok = GET_TOKEN(.DOTDOT, l.input, start, 2)
		}
		tok = GET_TOKEN(.DOT, l.input, l.pos, 1)
	case '/':
		tok = GET_TOKEN(.DIV, l.input, l.pos, 1)
	case '%':
		tok = GET_TOKEN(.MOD, l.input, l.pos, 1)
	case '^':
		tok = GET_TOKEN(.POW, l.input, l.pos, 1)
	case '(':
		tok = GET_TOKEN(.OPEN, l.input, l.pos, 1)
	case ')':
		tok = GET_TOKEN(.CLOSE, l.input, l.pos, 1)
	case '[':
		tok = GET_TOKEN(.BOPEN, l.input, l.pos, 1)
	case ']':
		tok = GET_TOKEN(.BCLOSE, l.input, l.pos, 1)
	case '{':
		tok = GET_TOKEN(.TOPEN, l.input, l.pos, 1)
	case '}':
		tok = GET_TOKEN(.TCLOSE, l.input, l.pos, 1)
	case ',':
		tok = GET_TOKEN(.COMMA, l.input, l.pos, 1)
	case ':':
		tok = GET_TOKEN(.COLON, l.input, l.pos, 1)
	case ';':
		tok = GET_TOKEN(.SEMI, l.input, l.pos, 1)
	case '<':
		if PEEK(l) == '=' {
			start := l.pos
			EAT(l)
			tok = GET_TOKEN(.LE, l.input, start, 2)
		}
		 else if PEEK(l) == '<' {
			start := l.pos
			EAT(l)
			tok = GET_TOKEN(.SHL, l.input, start, 2)
		}
		 else do tok = GET_TOKEN(.LT, l.input, l.pos, 1)
	case '>':
		if PEEK(l) == '=' {
			start := l.pos
			EAT(l)
			tok = GET_TOKEN(.GE, l.input, start, 2)
		}
		 else if PEEK(l) == '>' {
			start := l.pos
			EAT(l)
			tok = GET_TOKEN(.SHR, l.input, start, 2)
		}
		 else do tok = GET_TOKEN(.GT, l.input, l.pos, 1)
	case '~':
		if PEEK(l) == '=' {
			start := l.pos
			EAT(l)
			tok = GET_TOKEN(.NEQ, l.input, start, 2)
		}
		 else do tok = GET_TOKEN(.TILDE, l.input, l.pos, 1)
	case '|':
		if PEEK(l) == '|' {
			start := l.pos
			EAT(l)
			tok = GET_TOKEN(.OROR, l.input, start, 2)
		}
		 else do tok = GET_TOKEN(.OR, l.input, l.pos, 1)
	case '&':
		if PEEK(l) == '&' {
			start := l.pos
			EAT(l)
			tok = GET_TOKEN(.ANDAND, l.input, start, 2)
		}
		 else do tok = GET_TOKEN(.AND, l.input, l.pos, 1)
	case '!':
		tok = GET_TOKEN(.BANG, l.input, l.pos, 1)
	case '#':
		tok = GET_TOKEN(.POUND, l.input, l.pos, 1)
	case '"':
		tok = CREATE_STRING(l)
	case 0:
		tok.text = {}
		tok.kind = .EOF
	case:
		if IS_LETTER(l.ch) {
			tok = CREATE_IDENTIFIER(l)
			UPDATE_KW(&tok)
			return tok, nil
		}
		 else if IS_DIGIT(l.ch) do return CREATE_NUMBER(l), nil
		tok = GET_TOKEN(.ILLEGAL, l.input, l.pos, 1)
	}
	EAT(l)
	if tok.kind == .ILLEGAL do return tok, GET_SYNTAX_ERROR(l, tok)
	return tok, nil // EOF
}
@(private = "file")
GET_TOKEN :: proc(type: Token, input: []u8, start: int, length: int) -> TokenDefinition {
	return TokenDefinition{kind = type, text = input[start:start + length]}
}
@(private = "file")
UPDATE_KW :: proc(tok: ^TokenDefinition) {
	switch string(tok.text) {
	case "do":
		tok.kind = .DO
	case "end":
		tok.kind = .END
	case "while":
		tok.kind = .WHILE
	case "repeat":
		tok.kind = .REPEAT
	case "if":
		tok.kind = .IF
	case "function":
		tok.kind = .FUNCTION
	case "local":
		tok.kind = .LOCAL
	case "global":
		tok.kind = .GLOBAL
	case "true":
		tok.kind = .TRUE
	case "false":
		tok.kind = .FALSE
	case "nil":
		tok.kind = .NIL
	case "break":
		tok.kind = .BREAK
	case "or":
		tok.kind = .OR
	case "and":
		tok.kind = .AND
	case "not":
		tok.kind = .NOT
	case "then":
		tok.kind = .THEN
	case "else":
		tok.kind = .ELSE
	case "elseif":
		tok.kind = .ELSEIF
	}
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
	for l.ch == ' ' || l.ch == '\t' || l.ch == '\n' || l.ch == '\r' do EAT(l)
}

@(private = "file")
EAT :: proc(l: ^Lexer) {
	if l.pos >= len(l.input) - 1 {
		l.ch = 0
	}
	 else {
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
CREATE_IDENTIFIER :: proc(l: ^Lexer) -> TokenDefinition {
	start := l.pos
	EAT(l)
	for IS_LETTER(l.ch) || IS_DIGIT(l.ch) do EAT(l)

	// Check if identifier is a keyword
	ident := string(l.input[start:l.pos])

	if ident == "do" do return GET_TOKEN(.DO, l.input, start, l.pos - start)
	if ident == "end" do return GET_TOKEN(.END, l.input, start, l.pos - start)
	if ident == "in" do return GET_TOKEN(.IN, l.input, start, l.pos - start)
	if ident == "while" do return GET_TOKEN(.WHILE, l.input, start, l.pos - start)
	if ident == "repeat" do return GET_TOKEN(.REPEAT, l.input, start, l.pos - start)
	if ident == "until" do return GET_TOKEN(.UNTIL, l.input, start, l.pos - start)
	if ident == "for" do return GET_TOKEN(.FOR, l.input, start, l.pos - start)
	if ident == "return" do return GET_TOKEN(.RETURN, l.input, start, l.pos - start)
	if ident == "if" do return GET_TOKEN(.IF, l.input, start, l.pos - start)
	if ident == "then" do return GET_TOKEN(.THEN, l.input, start, l.pos - start)
	if ident == "else" do return GET_TOKEN(.ELSE, l.input, start, l.pos - start)
	if ident == "elseif" do return GET_TOKEN(.ELSEIF, l.input, start, l.pos - start)
	if ident == "function" do return GET_TOKEN(.FUNCTION, l.input, start, l.pos - start)
	if ident == "local" do return GET_TOKEN(.LOCAL, l.input, start, l.pos - start)
	if ident == "true" do return GET_TOKEN(.TRUE, l.input, start, l.pos - start)
	if ident == "false" do return GET_TOKEN(.FALSE, l.input, start, l.pos - start)
	if ident == "nil" do return GET_TOKEN(.NIL, l.input, start, l.pos - start)
	if ident == "break" do return GET_TOKEN(.BREAK, l.input, start, l.pos - start)
	if ident == "or" do return GET_TOKEN(.OR, l.input, start, l.pos - start)
	if ident == "and" do return GET_TOKEN(.AND, l.input, start, l.pos - start)
	if ident == "not" do return GET_TOKEN(.NOT, l.input, start, l.pos - start)

	return GET_TOKEN(.IDENTIFIER, l.input, start, l.pos - start)
}
@(private = "file")
CREATE_NUMBER :: proc(l: ^Lexer) -> TokenDefinition {
	start := l.pos
	for IS_DIGIT(l.ch) do EAT(l)
	if l.ch == '.' {
		EAT(l)
		for IS_DIGIT(l.ch) do EAT(l)
		return GET_TOKEN(.NUMBER, l.input, start, l.pos - start)
	}
	return GET_TOKEN(.NUMBER, l.input, start, l.pos - start)
}

@(private = "file")
CREATE_STRING :: proc(l: ^Lexer) -> TokenDefinition {
	start := l.pos + 1
	for {
		EAT(l)
		if l.ch == '"' || l.ch == 0 do break
	}
	return GET_TOKEN(.STRING, l.input, start, l.pos - start)
}

