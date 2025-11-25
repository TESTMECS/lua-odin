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
	EvalError,
	virtual.Allocator_Error,
	io.Error,
}
SyntaxError :: struct {
	msg:  string,
	pos:  int,
	kind: Token,
	text: []u8,
}
SYNTAX_ERROR :: proc(l: ^Lexer, tok: TokenDefinition) -> OuauError {
	s := SyntaxError {
		msg  = string(tok.text),
		pos  = l.pos,
		kind = tok.kind,
		text = tok.text,
	}
	fmt.eprintfln("Syntax Error::Msg::(%s)|", s.msg)
	fmt.eprintfln("Pos::(%d)|", s.pos)
	fmt.eprintfln("Kind::(%v)|", tok.kind)
	fmt.eprintfln("Text::(%s)|", tok.text)
	return s
}
ParseError :: struct {
	msg:           string,
	parser_object: ^Parser,
}
PARSE_ERROR :: proc(p: ^Parser, msg: string) -> OuauError {
	fmt.eprintfln("|Parse Error::Msg::(%s)|", msg)
	fmt.eprintfln("|Pos::(%d)|", p.pos)
	fmt.eprintfln("|Current Token Text::(%s)|", p.current.text)
	fmt.eprintfln("|Current Token Kind::(%v)|", p.current.kind)
	fmt.eprintfln("|Peek Token Kind::(%s)|", p.peek.kind)
	fmt.eprintfln("|Peek Token Text::(%s)|", p.peek.text)
	return ParseError{msg, p}
}
EvalError :: struct {
	msg:       string,
	evaluator: ^Interpreter,
}
EVAL_ERROR :: proc(i: ^Interpreter, msg: string) -> OuauError {
	fmt.eprintfln("Eval Error::Msg::(%s)|", msg)
	fmt.eprintfln("Call Stack::(%v)|", i.call_stack)
	fmt.eprintfln("Globals::(%v)|", i.globals)
	return EvalError{msg, i}
}

