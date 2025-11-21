package ouau
COMPILE_NODE :: proc(c: ^Compiler, nodeid: NODEID) -> int {
	kind := c.nodes.kind[nodeid]

	switch kind {
	case .LITERAL:
		unimplemented("TODO")
	case .IDENTIFIER:
		unimplemented("TODO")
	case .ASSIGN:
		unimplemented("TODO")
	case .WHILE:
		unimplemented("TODO")
	case .REPEAT:
		unimplemented("TODO")
	case .TABLE:
		unimplemented("TODO")
	case .FUNCTION:
		unimplemented("TODO")
	case .UNARY:
		unimplemented("TODO")
	case .UBLOCK:
		unimplemented("TODO")
	case .BINARY:
		unimplemented("TODO")
	case .STRING:
		unimplemented("TODO")
	case .GLOBAL:
		unimplemented("TODO")
	case .LOCAL:
		unimplemented("TODO")
	case .BREAK:
		unimplemented("TODO")
	case .FOR:
		unimplemented("TODO")
	case .BLOCK:
		unimplemented("TODO")
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

