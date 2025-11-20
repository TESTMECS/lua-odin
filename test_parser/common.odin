package parser_test
import parser "../"
import "core:fmt"

validate_node :: proc(p: ^parser.Parser, node_id: parser.NODEID) -> bool
{
	using parser
	if node_id >= cast(NODEID)len(p.nodes.kind)
	{
		fmt.printf("ERROR: Node ID %d out of range\n", node_id)
		return false
	}

	if p.nodes.kind[node_id] == .INVALID
	{
		fmt.printf("ERROR: Invalid node at ID %d\n", node_id)
		return false
	}

	return true
}

count_children :: proc(p: ^parser.Parser, node_id: parser.NODEID) -> int
{
	using parser
	count := 0
	child := p.nodes.first_child[node_id]
	for child != 0
	{
		count += 1
		child = p.nodes.next_sibling[child]
	}
	return count
}

find_node_by_kind :: proc(p: ^parser.Parser, kind: parser.NODE_KIND) -> []parser.NODEID
{
	using parser
	results := make([dynamic]NODEID)
	for i, k in p.nodes.kind
	{
		if i == kind
		{
			append(&results, cast(NODEID)i)
		}
	}
	return results[:]
}

find_node_by_name :: proc(p: ^parser.Parser, name: string) -> parser.NODEID
{
	using parser
	for i, n in p.nodes.name
	{
		if i == name
		{
			return cast(NODEID)n
		}
	}
	return 0
}
dump_ast :: proc(p: ^parser.Parser)
{
	using parser
	fmt.println("=== AST DUMP ===")
	for i in 0 ..< len(p.nodes.kind)
	{
		fmt.printf("Node %d: %s", i, p.nodes.kind[i])

		if p.nodes.name[i] != ""
		{
			fmt.printf(" name='%s'", p.nodes.name[i])
		}
		if p.nodes.int_value[i] != 0
		{
			fmt.printf(" int=%d", p.nodes.int_value[i])
		}
		if p.nodes.string_value[i] != ""
		{
			fmt.printf(" str='%s'", p.nodes.string_value[i])
		}

		child_count := 0
		child := p.nodes.first_child[i]
		for child != 0
		{
			child_count += 1
			child = p.nodes.next_sibling[child]
		}
		fmt.printf(" children=%d", child_count)
		fmt.println()
	}
}

