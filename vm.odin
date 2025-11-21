package ouau

VM_EXECUTE :: proc(vm: ^VM, closure: ^Closure, args: []Value) -> Value {
	thread := vm.current_thread
	frame := VMFrame {
		func        = closure,
		base_reg    = 0,
		saved_pc    = 0,
		num_results = 0,
		tail_calls  = 0,
	}
	for arg in args {
		STACK_PUSH(thread, arg)
	}
	append(&thread.call_stack, frame)
	thread.pc = 0
	thread.base = 0
	return EXECUTE_LOOP(vm)
}
EXECUTE_LOOP :: proc(vm: ^VM) -> Value {
	thread := vm.current_thread
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
EXECUTE_INSTRUCTION :: proc(vm: ^VM, inst: Instruction) -> Value {
	op, a, b, c := DECODE_ABC(inst)
	#partial switch Opcodes(op) {
	case .MOVE:
		EXECUTE_MOVE(vm, a, b, c)
	case .LOADK:
		EXECUTE_LOADK(vm, a, b, c)
	case .LOADBOOL:
		EXECUTE_LOADBOOL(vm, a, b, c)
	case .ADD:
		EXECUTE_ADD(vm, a, b, c)
	case .CALL:
		return EXECUTE_CALL(vm, a, b, c)
	case .RETURN:
		return EXECUTE_RETURN(vm, a, b, c)
	case .JMP:
		EXECUTE_JMP(vm, a, b, c)
	case:
		return nil
	}
	return nil
}
EXECUTE_MOVE :: proc(vm: ^VM, a, b, c: u32) {
	thread := vm.current_thread
	STACK_SET(thread, int(a), STACK_GET(thread, int(b)))
}
EXECUTE_LOADK :: proc(vm: ^VM, a, b, c: u32) {
	thread := vm.current_thread
	frame := thread.call_stack[thread.call_count]
	constant := frame.func.proto.constants[int(b)]
	STACK_SET(thread, int(a), constant)
}
EXECUTE_LOADBOOL :: proc(vm: ^VM, a, b, c: u32) {
	thread := vm.current_thread
	STACK_SET(thread, int(a), b != 0)
	if c != 0 {
		thread.pc += 1
	}
}
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

