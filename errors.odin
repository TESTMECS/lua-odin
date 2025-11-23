package ouau
import "core:io"
import "core:log"
/*
*	 ./errors.odin
*	 Copyright(C) 2025 TESTMEE
*	 Defines the error values for Ouau.
*/
SyntaxError :: struct {
	msg:  string,
	pos:  int,
	kind: Token,
	text: []u8,
}
GET_SYNTAX_ERROR :: proc(l: ^Lexer, tok: TokenDefinition) -> OuauError {
	s := SyntaxError {
		msg  = string(tok.text),
		pos  = l.pos,
		kind = tok.kind,
		text = tok.text,
	}
	log.errorf(
		"[Syntax Error]::at position::(%d) of kind::(%v) with text::('%s'/%d)",
		s.pos,
		s.kind,
		s.msg,
		s.text,
	)
	return s
}
OuauError :: union {
	SyntaxError,
	io.Error,
}

