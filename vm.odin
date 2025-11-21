package ouau
import "core:fmt"
VM_EXECUTE :: proc(vm: ^VM, closure: ^Closure, args: []Value) -> Value {
	thread := vm.current_thread
	thread.call_count = 0
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
	case .CLOSURE:
		op, a, bx := DECODE_ABX(inst)
		EXECUTE_CLOSURE(vm, a, bx)
	case .LOADBOOL:
		EXECUTE_LOADBOOL(vm, a, b, c)
	case .ADD:
		EXECUTE_ADD(vm, a, b, c)
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
EXECUTE_CALL :: proc(vm: ^VM, closure: ^Closure, a, b, c: u32) -> Value {
	thread := vm.current_thread
	frame := VMFrame {
		func        = closure,
		base_reg    = thread.base + int(a) + 1,
		saved_pc    = thread.pc + 1,
		num_results = int(c),
		tail_calls  = 0,
	}
	append(&thread.call_stack, frame)
	thread.call_count += 1
	thread.base = frame.base_reg
	thread.pc = 0
	return nil
}
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
	pop(&thread.call_stack)
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
EXECUTE_JMP :: proc(vm: ^VM, a, b, c: u32) {
	thread := vm.current_thread
	op, a, sbx := DECODE_ASBX(
		thread.call_stack[thread.call_count].func.proto.instructions[thread.pc],
	)
	thread.pc += int(sbx) - 1
}
EXECUTE_CLOSURE :: proc(vm: ^VM, a, bx: u32) {
	thread := vm.current_thread
	frame := thread.call_stack[thread.call_count]
	if int(bx) >= len(frame.func.proto.proto) {
		fmt.printf(
			"ERROR: Closure index %d out of bounds [0, %d]\n",
			bx,
			len(frame.func.proto.proto),
		)
		thread.globals.panic(thread, "CLOSURE index out of bounds", 0)
		return
	}
	LOGSF(context.logger, "frame.func.proto.proto[%d]", int(bx))
	proto := frame.func.proto.proto[int(bx)]
	LOGSF(context.logger, "proto->%v", proto)
	closure := new(Closure, vm.allocator)
	closure.proto = proto
	closure.is_native = false
	STACK_SET(thread, int(a), closure)
}

