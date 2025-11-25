package parser_test
import Ouau "../"
import "core:log"
import "core:testing"
/*
* ./parser_test/common.odin
* Copyright(C) 2025 TESTMEE
* Defines the common functions and errors for parser tests.
* */
EXPECT_NODE :: proc(kind: Ouau.NODE_KIND, expect: Ouau.NODE_KIND, t: ^testing.T) {
	if expect != kind {
		log.errorf("Error expected node::(%v), got::(%v)", expect, kind)
		testing.fail(t)
	}
}
EXPECT_CHILD :: proc(p: ^Ouau.Parser, parent: Ouau.NODEID, child: Ouau.NODEID, t: ^testing.T) {
	if p.nodes.first_child[parent] != child {
		log.errorf("Error expected child::(%v), got::(%v)", child, p.nodes.first_child[parent])
		testing.fail(t)
	}
}
CHECK_ID :: proc(p: ^Ouau.Parser, nodeid: Ouau.NODEID, id: string, t: ^testing.T) {
	using Ouau
	if p.nodes.name[nodeid] != id {
		log.errorf("Error expected id::(%v), got::(%v)", id, p.nodes.name[nodeid])
		testing.fail(t)
	}
}

