package ouau

STACK_CHECK :: proc(vm: ^VM, needed: int) -> bool {
	thread := vm.current_thread
	available := len(thread.stack) - thread.top
	if available < needed {
		resize(&thread.stack, len(thread.stack) * 2)
	}
	return true
}
STACK_PUSH :: proc(thread: ^ThreadState, val: Value) {
	if thread.top >= len(thread.stack) {
		resize(&thread.stack, len(thread.stack) * 2)
	}
	thread.stack[thread.top] = val
	thread.top += 1
}
STACK_POP :: proc(thread: ^ThreadState) -> Value {
	thread.top -= 1
	return thread.stack[thread.top]
}
STACK_GET :: proc(thread: ^ThreadState, idx: int) -> Value {
	return thread.stack[thread.top + idx]
}
STACK_SET :: proc(thread: ^ThreadState, idx: int, val: Value) {
	thread.stack[thread.top + idx] = val
}

