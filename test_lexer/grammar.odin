package lexer_test
import lexer "../"
import "core:log"
import "core:mem/virtual"
import "core:testing"

@(test)
test_lexer_init :: proc(t: ^testing.T) {
	using lexer
	v: virtual.Arena
	err := virtual.arena_init_growing(&v)
	ensure(err == nil, "Error initializing arena")
	defer virtual.arena_destroy(&v)
	input := `
	local a = 1;
	function a(b, c) end;
	{a=0,[1]=1};
	break
	repeat
	true
	false
	nil
	if
	then
	else
	elseif`


	l := NEW_LEXER(input, &v)
	tests := [?]struct {
		expected: Token,
		lit:      string,
	} {
		{.LOCAL, "local"},
		{.IDENTIFIER, "a"},
		{.ASSIGN, "="},
		{.NUMBER, "1"},
		{.SEMI, ";"},
		{.FUNCTION, "function"},
		{.IDENTIFIER, "a"},
		{.OPEN, "("},
		{.IDENTIFIER, "b"},
		{.COMMA, ","},
		{.IDENTIFIER, "c"},
		{.CLOSE, ")"},
		{.END, "end"},
		{.SEMI, ";"},
		{.TOPEN, "{"},
		{.IDENTIFIER, "a"},
		{.ASSIGN, "="},
		{.NUMBER, "0"},
		{.COMMA, ","},
		{.BOPEN, "["},
		{.NUMBER, "1"},
		{.BCLOSE, "]"},
		{.ASSIGN, "="},
		{.NUMBER, "1"},
		{.TCLOSE, "}"},
		{.SEMI, ";"},
		{.BREAK, "break"},
		{.REPEAT, "repeat"},
		{.TRUE, "true"},
		{.FALSE, "false"},
		{.NIL, "nil"},
		{.IF, "if"},
		{.THEN, "then"},
		{.ELSE, "else"},
		{.ELSEIF, "elseif"},
		//
		{.EOF, ""},
	}
	for tc, i in tests {
		tok, err := l->NEXT()
		ensure(err == nil, "Failed to get next token")
		if tok.kind != tc.expected {
			log.errorf("expected %v, got %v, iter: %v", tc.expected, tok.kind, i)
			continue
		}
		if string(tok.text) != tc.lit {
			log.errorf("expected %v, got %v, iter: %v", tc.lit, tok.text, i)
		}
	}

}

