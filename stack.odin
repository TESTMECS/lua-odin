package ouau
import "core:fmt"
/*
	 ./stack.odin
	 Copyright(C) 2025 TESTMEE
	 Defines the stack functions for Ouau.
*/
STACK_CHECK :: proc(vm: ^VM, needed: int) -> bool {
	thread := vm.current_thread
	available := len(thread.stack) - thread.top
	if available < needed {
		if resize(&thread.stack, len(thread.stack) * 2) != .None do return false
	}
	return true
}
STACK_PUSH :: proc(thread: ^ThreadState, val: Value) {
	if thread.top >= len(thread.stack) {
		if resize(&thread.stack, len(thread.stack) * 2) != .None do return
	}
	thread.stack[thread.top] = val
	thread.top += 1
}
STACK_POP :: proc(thread: ^ThreadState) -> Value {
	thread.top -= 1
	return thread.stack[thread.top]
}
STACK_GET :: proc(thread: ^ThreadState, idx: int) -> Value {
	actual_idx := thread.base + idx
	if actual_idx < 0 || actual_idx >= thread.top {
		fmt.eprintf("SEGFAULT: STACK_GET idx %d out of bounds [0, %d]\n", actual_idx, thread.top)
		panic("stack bounds error")
	}
	return thread.stack[actual_idx]
}
STACK_SET :: proc(thread: ^ThreadState, idx: int, value: Value) {
	actual_idx := thread.base + idx
	if actual_idx < 0 || actual_idx >= len(thread.stack) {
		fmt.eprintf(
			"SEGFAULT: STACK_SET idx %d out of bounds [0, %d]\n",
			actual_idx,
			len(thread.stack),
		)
		panic("stack bounds error")
	}
	thread.stack[actual_idx] = value
	if actual_idx >= thread.top {
		thread.top = actual_idx + 1
	}
}

