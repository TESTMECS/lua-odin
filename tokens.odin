package ouau
/*
	 ./tokens.odin
	 Copyright(C) 2025 TESTMEE
	 Defines the tokens for Ouau.
	 @Token, @Token_def
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
Token_def :: struct {
	kind: Token,
	text: []u8,
}

