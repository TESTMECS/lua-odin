package parser_test
import Ouau "../"
import "core:fmt"
import "core:log"
import "core:mem/virtual"
import "core:testing"
/*
* ./parser_test/common.odin
* Copyright(C) 2025 TESTMEE
* Defines the common functions and errors for parser tests.
* */
DUMP_AST :: proc(p: ^Ouau.Parser) {
	using Ouau
	fmt.println("=== AST DUMP ===")
	for i in 0 ..< len(p.nodes.kind) {
		fmt.printf("Node %d: %s", i, p.nodes.kind[i])

		if p.nodes.name[i] != "" {
			fmt.printf(" name='%s'", p.nodes.name[i])
		}
		if p.nodes.int_value[i] != 0 {
			fmt.printf(" int=%d", p.nodes.int_value[i])
		}
		if p.nodes.string_value[i] != "" {
			fmt.printf(" str='%s'", p.nodes.string_value[i])
		}

		child_count := 0
		child := p.nodes.first_child[i]
		for child != 0 {
			child_count += 1
			child = p.nodes.next_sibling[child]
		}
		fmt.printf(" children=%d", child_count)
		fmt.println()
	}
}
EXPECT_NODE :: proc(kind: Ouau.NODE_KIND, expect: Ouau.NODE_KIND, t: ^testing.T) -> bool {
	if expect != kind {
		log.debug("expect", expect, "got", kind)
		return false
	}
	return true
}
EXPECT_CHILD :: proc(p: ^Ouau.Parser, parent: Ouau.NODEID, child: Ouau.NODEID, t: ^testing.T) {
	if p.nodes.first_child[parent] != child {
		log.info("expect", child, "got", p.nodes.first_child[parent])
		testing.fail(t)
	}
}
CHECK_ID :: proc(p: ^Ouau.Parser, nodeid: Ouau.NODEID, id: string, t: ^testing.T) {
	using Ouau
	if p.nodes.name[nodeid] != id {
		log.info("expect", id, "got", p.nodes.name[nodeid])
		testing.fail(t)
	}
}

