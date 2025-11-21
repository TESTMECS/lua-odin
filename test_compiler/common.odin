package compiler_test
import compiler "../"
import "core:log"
import "core:testing"
CHECK_DECODE_ABC :: proc(t: ^testing.T, i: compiler.Instruction, op: compiler.Opcodes) {
	using compiler
	op, _, _, _ := DECODE_ABC(i)
	if op != u32(op) {
		log.error("Instruction is not %v", op)
		testing.fail(t)
	}
}
DEBUG_INSTRUCTION :: proc(t: ^testing.T, i: compiler.Instruction) {
	using compiler
	op, a, b, c := DECODE_ABC(i)
	log.debugf("op: %v, a: %v, b: %v, c: %v", op, a, b, c)
}

