package parser_test
import parser "../"
import "core:fmt"
import "core:log"
import "core:testing"

DUMP_AST :: proc(p: ^parser.Parser) {
	using parser
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
EXPECT_NODE :: proc(kind: parser.NODE_KIND, expect: parser.NODE_KIND, t: ^testing.T) {
	if expect != kind {
		log.info("expect", expect, "got", kind)
		testing.fail(t)
	}
}
EXPECT_CHILD :: proc(
	p: ^parser.Parser,
	parent: parser.NODEID,
	child: parser.NODEID,
	t: ^testing.T,
) {
	if p.nodes.first_child[parent] != child {
		log.info("expect", child, "got", p.nodes.first_child[parent])
		testing.fail(t)
	}
}
CHECK_ID :: proc(p: ^parser.Parser, nodeid: parser.NODEID, id: string, t: ^testing.T) {
	using parser
	if p.nodes.name[nodeid] != id {
		log.info("expect", id, "got", p.nodes.name[nodeid])
		testing.fail(t)
	}
}

