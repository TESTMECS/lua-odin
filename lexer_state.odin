package ouau
Lexer :: struct
{
	input:    []u8,
	pos:      int,
	read_pos: int,
	ch:       u8,
	NEXT:     proc(l: ^Lexer) -> Token_def,
}

