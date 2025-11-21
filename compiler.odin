package ouau
import "core:fmt"
COMPILE_NODE :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	kind := c.nodes.kind[nodeid]
	fmt.printf("Compiling node %d: %s\n", nodeid, kind)

	switch kind {
	case .BLOCK:
		unimplemented("TODO BLOCK")
	case .LITERAL:
		unimplemented("TODO LITERAL")
	case .IDENTIFIER:
		unimplemented("TODO IDENTIFIER")
	case .ASSIGN:
		unimplemented("TODO ASSIGN")
	case .WHILE:
		unimplemented("TODO WHILE")
	case .REPEAT:
		unimplemented("TODO REPEAT")
	case .TABLE:
		unimplemented("TODO TABLE")
	case .FUNCTION:
		unimplemented("TODO FUNCTION")
	case .UNARY:
		unimplemented("TODO UNARY")
	case .UBLOCK:
		unimplemented("TODO UBLOCK")
	case .BINARY:
		unimplemented("TODO BINARY")
	case .STRING:
		unimplemented("TODO STRING")
	case .GLOBAL:
		unimplemented("TODO GLOBAL")
	case .LOCAL:
		unimplemented("TODO LOCAL")
	case .BREAK:
		unimplemented("TODO BREAK")
	case .FOR:
		unimplemented("TODO FOR")
	case .DO:
		unimplemented("TODO")
	case .CALL:
		unimplemented("TODO CALL")
	case .RETURN:
		unimplemented("TODO RETURN")
	case .IF:
		unimplemented("TODO IF")
	case .INVALID:
		return COMPILE_ERR(c, "Invalid node", kind)
	}
	return COMPILE_ERR(c, "Unimplemented node", kind)
}
CHECK_KIND :: proc(c: ^Compiler, nodeid: NODEID, kind: NODE_KIND) -> bool {
	if c.nodes.kind[nodeid] == kind {
		return true
	}
	return false
}

