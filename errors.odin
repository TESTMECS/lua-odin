package ouau
import "core:fmt"
import "core:io"
import "core:mem/virtual"
/*
*	 ./errors.odin
*	 Copyright(C) 2025 TESTMEE
*	 Defines the error values for Ouau.
*/
OuauError :: union {
	SyntaxError,
	ParseError,
	virtual.Allocator_Error,
	io.Error,
}

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
	fmt.eprintfln(
		"[Syntax Error]::at position::(%d) of kind::(%v) with text::('%s'/%d)",
		s.pos,
		s.kind,
		s.msg,
		s.text,
	)
	return s
}
ParseError :: struct {
	msg: string,
}
PARSE_ERROR :: proc(p: ^Parser, msg: string) -> (err: OuauError) {
	err = ParseError{msg}
	fmt.eprintf("[Parse Error]Msg::(%s)|", msg)
	fmt.eprintf("Pos::(%d)|", p.pos)
	fmt.eprintf("Current Token Text::(%s)|", p.current.text)
	fmt.eprintf("Current Token Kind::(%v)|", p.current.kind)
	fmt.eprintf("Peek Token Kind::(%s)|", p.peek.kind)
	fmt.eprintf("Peek Token Text::(%s)|", p.peek.text)
	return
}

