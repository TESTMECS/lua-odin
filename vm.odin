package ouau
/*
	 ./vm.odin
	 Copyright(C) 2025 TESTMEE
	 Defines the VM functions for Ouau.
*/
@(require_results)
VM_EXECUTE :: proc(vm: ^VM, closure: ^Closure, args: []Value) -> Value {
	thread := vm.current_thread // Get current thread
	thread.call_count = 0 // reset call count
	frame := VMFrame { 	// Create a new frame.
		func        = closure,
		base_reg    = 0,
		saved_pc    = 0,
		num_results = 0,
		tail_calls  = 0,
	}

	for arg in args {
		STACK_PUSH(thread, arg) // Push arguments onto the thread's stack
	}

	if append(&thread.call_stack, frame) < 0 do return nil // Push the frame onto the call stack

	thread.pc = 0 // Reset the program counter
	thread.base = 0 // Reset the base register
	return EXECUTE_LOOP(vm) // Execute the loop
}
@(private = "file")
EXECUTE_LOOP :: proc(vm: ^VM) -> Value {
	thread := vm.current_thread // Get the current thread
	for {

		if thread.pc >= len(thread.call_stack[thread.call_count].func.proto.instructions) {
			break
		}

		inst := thread.call_stack[thread.call_count].func.proto.instructions[thread.pc]
		result := EXECUTE_INSTRUCTION(vm, inst)
		if result != nil {
			return result
		}
		thread.pc += 1
	}
	return nil
}
@(private = "file")
EXECUTE_INSTRUCTION :: proc(vm: ^VM, instruction: u32) -> Value {
	op, a, b, c := DECODE_ABC(instruction)
	#partial switch Opcodes(op) {
	case .MOVE:
		EXECUTE_MOVE(vm, a, b, c)
	case .LOADK:
		EXECUTE_LOADK(vm, a, b, c)
	case .CLOSURE:
		op, a, bx := DECODE_ABX(instruction)
		EXECUTE_CLOSURE(vm, a, bx)
	case .LOADBOOL:
		EXECUTE_LOADBOOL(vm, a, b, c)
	case .ADD:
		EXECUTE_ADD(vm, a, b, c)
	case .SUB:
		EXECUTE_SUB(vm, a, b, c)
	case .MUL:
		EXECUTE_MUL(vm, a, b, c)
	case .DIV:
		EXECUTE_DIV(vm, a, b, c)
	case .UNM:
		EXECUTE_UNM(vm, a, b, c)
	case .NOT:
		EXECUTE_NOT(vm, a, b, c)
	case .CALL:
		function_value := STACK_GET(vm.current_thread, int(a))
		if closure, ok := function_value.(^Closure); ok {
			return EXECUTE_CALL(vm, closure, a, b, c)
		}
		 else {
			vm.current_thread.globals.panic(
				vm.current_thread,
				"attempt to call non-function value",
				0,
			)
		}
	case .RETURN:
		return EXECUTE_RETURN(vm, a, b, c)
	case .JMP:
		EXECUTE_JMP(vm, a, b, c)
	case .GETGLOBAL:
		op, a, bx := DECODE_ABX(instruction)
		EXECUTE_GETGLOBAL(vm, a, bx)
	case .SETGLOBAL:
		op, a, bx := DECODE_ABX(instruction)
		EXECUTE_SETGLOBAL(vm, a, bx)
	case:
		return nil
	}
	return nil
}
@(private = "file")
EXECUTE_MOVE :: proc(vm: ^VM, a, b, c: u32) {
	thread := vm.current_thread
	STACK_SET(thread, int(a), STACK_GET(thread, int(b)))
}
@(private = "file")
EXECUTE_LOADK :: proc(vm: ^VM, a, b, c: u32) {
	thread := vm.current_thread
	frame := thread.call_stack[thread.call_count]
	constant := frame.func.proto.constants[int(b)]
	STACK_SET(thread, int(a), constant)
}
@(private = "file")
EXECUTE_LOADBOOL :: proc(vm: ^VM, a, b, c: u32) {
	thread := vm.current_thread
	STACK_SET(thread, int(a), b != 0)
	if c != 0 {
		thread.pc += 1
	}
}
@(private = "file")
EXECUTE_ADD :: proc(vm: ^VM, a, b, c: u32) {
	thread := vm.current_thread
	val_b := STACK_GET(thread, int(b))
	val_c := STACK_GET(thread, int(c))
	if b_val, ok := val_b.(f64); ok {
		if c_val, ok := val_c.(f64); ok {
			STACK_SET(thread, int(a), f64(b_val + c_val))
			return
		}
	}
	thread.globals.panic(thread, "attempt to perform arithmetic on a non-numeric value", 0)
}
@(private = "file")
EXECUTE_SUB :: proc(vm: ^VM, a, b, c: u32) {
	thread := vm.current_thread
	val_b := STACK_GET(thread, int(b))
	val_c := STACK_GET(thread, int(c))
	if b_val, ok := val_b.(f64); ok {
		if c_val, ok := val_c.(f64); ok {
			STACK_SET(thread, int(a), f64(b_val - c_val))
			return
		}
	}
	thread.globals.panic(thread, "attempt to perform arithmetic on a non-numeric value", 0)
}
@(private = "file")
EXECUTE_MUL :: proc(vm: ^VM, a, b, c: u32) {
	thread := vm.current_thread
	val_b := STACK_GET(thread, int(b))
	val_c := STACK_GET(thread, int(c))
	if b_val, ok := val_b.(f64); ok {
		if c_val, ok := val_c.(f64); ok {
			STACK_SET(thread, int(a), f64(b_val * c_val))
			return
		}
	}
	thread.globals.panic(thread, "attempt to perform arithmetic on a non-numeric value", 0)
}
@(private = "file")
EXECUTE_CALL :: proc(vm: ^VM, closure: ^Closure, a, b, c: u32) -> Value {
	thread := vm.current_thread
	frame := VMFrame {
		func        = closure,
		base_reg    = thread.base + int(a) + 1,
		saved_pc    = thread.pc + 1,
		num_results = int(c),
		tail_calls  = 0,
	}
	if append(&thread.call_stack, frame) < 0 do return nil
	thread.call_count += 1
	thread.base = frame.base_reg
	thread.pc = 0
	return nil
}
@(private = "file")
EXECUTE_RETURN :: proc(vm: ^VM, a, b, c: u32) -> Value {
	thread := vm.current_thread
	if len(thread.call_stack) <= 1 {
		if b > 0 {
			return STACK_GET(thread, int(a))
		}
		return nil
	}
	results := make([]Value, int(b), vm.allocator)
	for i in 0 ..< int(b) {
		results[i] = STACK_GET(thread, int(a) + i)
	}
	_ = pop(&thread.call_stack)
	thread.call_count -= 1
	if len(thread.call_stack) > 0 {
		frame := &thread.call_stack[thread.call_count]
		thread.base = frame.base_reg
		thread.pc = frame.saved_pc // + 1
		for result, i in results {
			STACK_SET(
				thread,
				int(frame.func.proto.instructions[frame.saved_pc - 1] >> 8) & 0xFF + i,
				result,
			)
		}
	}
	return nil
}
@(private = "file")
EXECUTE_GETTABLE :: proc(vm: ^VM, a, b, c: u32) {
	thread := vm.current_thread
	table_val := STACK_GET(thread, int(b))
	key_val := STACK_GET(thread, int(c))
	if table, ok := table_val.(^Table); ok {
		key := VALUE_TO_KEY_TAG(key_val)
		if val, exists := table.data[key]; exists {
			STACK_SET(thread, int(a), val)
		}
		 else {
			STACK_SET(thread, int(a), nil)
		}
	}
}
@(private = "file")
EXECUTE_SETTABLE :: proc(vm: ^VM, a, b, c: u32) {
	thread := vm.current_thread
	table_val := STACK_GET(thread, int(a))
	key_val := STACK_GET(thread, int(b))
	val_val := STACK_GET(thread, int(c))
	if table, ok := table_val.(^Table); ok {
		key := VALUE_TO_KEY_TAG(key_val)
		table.data[key] = val_val
		table.dirty = true
	}
}
@(private = "file")
EXECUTE_JMP :: proc(vm: ^VM, a, b, c: u32) {
	thread := vm.current_thread
	op, a, sbx := DECODE_ASBX(
		thread.call_stack[thread.call_count].func.proto.instructions[thread.pc],
	)
	thread.pc += int(sbx) - 1
}
@(private = "file")
EXECUTE_CLOSURE :: proc(vm: ^VM, a, bx: u32) {
	thread := vm.current_thread
	frame := thread.call_stack[thread.call_count]
	if int(bx) >= len(frame.func.proto.proto) {
		// This is a compiler bug - nested function shouldn't have CLOSURE
		// For now, just ignore this instruction and set closure to nil
		STACK_SET(thread, int(a), nil)
		return
	}
	proto := frame.func.proto.proto[int(bx)]
	if proto == nil {
		thread.globals.panic(thread, "CLOSURE proto is nil", 0)
		return
	}
	closure := new(Closure, vm.allocator)
	closure.proto = proto
	closure.is_native = false
	STACK_SET(thread, int(a), closure)
}
@(private = "file")
EXECUTE_GETGLOBAL :: proc(vm: ^VM, a, bx: u32) {
	thread := vm.current_thread
	frame := thread.call_stack[thread.call_count]
	constant := frame.func.proto.constants[int(bx)]

	if thread.globals.globals == nil {
		STACK_SET(thread, int(a), nil)
		return
	}

	if _, ok := constant.(string); ok {
		key := VALUE_TO_KEY_TAG(constant)
		if val, exists := thread.globals.globals.data[key]; exists {
			STACK_SET(thread, int(a), val)
		}
		 else {
			// Global not found, set to nil
			STACK_SET(thread, int(a), nil)
		}
	}
	 else {
		// Not a string key, shouldn't happen
		STACK_SET(thread, int(a), nil)
	}
}
@(private = "file")
EXECUTE_SETGLOBAL :: proc(vm: ^VM, a, bx: u32) {
	thread := vm.current_thread
	frame := thread.call_stack[thread.call_count]
	value := STACK_GET(thread, int(a))
	key_constant := frame.func.proto.constants[int(bx)]

	if _, ok := key_constant.(string); ok {
		key := VALUE_TO_KEY_TAG(key_constant)
		thread.globals.globals.data[key] = value
		thread.globals.globals.dirty = true
	}
}
@(private = "file")
EXECUTE_UNM :: proc(vm: ^VM, a, b, c: u32) {
	thread := vm.current_thread
	val_b := STACK_GET(thread, int(b))
	if b_val, ok := val_b.(f64); ok {
		if c_val, ok := val_b.(f64); ok {
			STACK_SET(thread, int(a), f64(-c_val))
			return
		}
	}
	thread.globals.panic(thread, "attempt to perform arithmetic on a non-numeric value", 0)
}
@(private = "file")
EXECUTE_NOT :: proc(vm: ^VM, a, b, c: u32) {
	thread := vm.current_thread
	val_b := STACK_GET(thread, int(b))
	if b_val, ok := val_b.(bool); ok {
		STACK_SET(thread, int(a), !b_val)
		return
	}
	thread.globals.panic(thread, "attempt to perform arithmetic on a non-numeric value", 0)
}
@(private = "file")
EXECUTE_DIV :: proc(vm: ^VM, a, b, c: u32) {
	thread := vm.current_thread
	val_b := STACK_GET(thread, int(b))
	val_c := STACK_GET(thread, int(c))
	if b_val, ok := val_b.(f64); ok {
		if c_val, ok := val_c.(f64); ok {
			STACK_SET(thread, int(a), f64(b_val / c_val))
			return
		}
	}
	thread.globals.panic(thread, "attempt to perform arithmetic on a non-numeric value", 0)
}

