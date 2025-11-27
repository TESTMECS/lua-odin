package compiler_test
import compiler "../"
import "core:log"
import "core:testing"
CHECK_DECODE_ABC :: proc(t: ^testing.T, instruction: u32, op: compiler.Opcodes) {
	using compiler
	op, _, _, _ := DECODE_ABC(instruction)
	if op != u32(op) {
		log.error("Instruction is not %v", op)
		testing.fail(t)
	}
}
DEBUG_INSTRUCTION :: proc(testptr: ^testing.T, instruction: u32) {
	using compiler
	op, a, b, c := DECODE_ABC(instruction)
	log.debugf("op::%v/%v, reg_a::%v, reg_b::%v, reg_c::%v", op, Opcodes(op), a, b, c)
}

