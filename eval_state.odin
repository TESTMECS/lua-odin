package ouau
import "core:fmt"

Environment :: struct {
	values: map[string]Value,
	sorted: [dynamic]string,
	dirty:  bool,
	outer:  ^Environment,
}

Frame :: struct {
	env:         ^Environment,
	return_addr: NODEID,
	result:      Value,
}

Interpreter :: struct {
	globals:    map[string]Value,
	current:    ^Environment,
	nodes:      ^NODES,
	call_stack: [dynamic]^Frame,
}

NEW_INTERPRETER :: proc(nodes: ^NODES, allocator := context.allocator) -> ^Interpreter {
	i := new(Interpreter, allocator)
	i.nodes = nodes
	i.globals = make(map[string]Value, allocator)
	i.current = NEW_ENVIRONMENT(nil, allocator)
	i.call_stack = make([dynamic]^Frame, allocator)
	INIT_BUILTINS(i)
	return i
}
INTERPRET :: proc(i: ^Interpreter, root: NODEID) -> Value {
	// root is a block. Let's iterate its statements.
	child := i.nodes.first_child[root]
	last_val: Value
	for child != 0 {
		v := EVAL(i, child)
		if ret, ok := v.(^ReturnValue); ok {
			return ret.value
		}
		last_val = v
		child = i.nodes.next_sibling[child]
	}
	return last_val
}
INIT_BUILTINS :: proc(i: ^Interpreter) {
	print_fn := new(Closure)
	print_fn.is_native = true
	print_fn.native_proc = BUILTIN_PRINT
	i.globals["print"] = print_fn
}

BUILTIN_PRINT :: proc(args: []Value) -> Value {
	for arg in args {
		fmt.print(arg)
	}
	fmt.println()
	return nil
}

