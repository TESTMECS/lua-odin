package ouau
import "core:math"
/*
	 opcodes_help.odin
	 Copyright(C) 2025 TESTMEE
	 This file defines the helper functions for ./opcodes.odin
 */
// bx POS_C .. POS_B + SIZE_B - 1 (14-31)
MASK :: proc(n: int) -> u32 {return (u32(1) << u32(n)) - u32(1)}
MASK_OP := MASK(SIZE_OP)
MASK_A := MASK(SIZE_A)
MASK_B := MASK(SIZE_B)
MASK_C := MASK(SIZE_C)
MASK_Bx := MASK(SIZE_Bx)
BxBIAS := (1 << (SIZE_Bx - 1)) - 1 / math.pow2_f64(17) - 1
LOOKUP :: proc(op: Opcodes) -> (Definition, bool) {
	def := Definition__Table__[op]
	if def.name == "" do return Definition{}, false
	return def, true
}

MAKE_ABC :: proc(operation, register_a, register_b, register_c: u32) -> u32 {
	if operation > MASK_OP || register_a > MASK_A || register_b > MASK_B || register_c > MASK_C do panic("field out of range @MAKE_ABC")
	return(
		u32((operation & MASK_OP) << POS_OP) |
		u32((register_a & MASK_A) << POS_A) |
		u32((register_c & MASK_C) << POS_C) |
		u32((register_b & MASK_B) << POS_B) \
	)
}

MAKE_ABX :: proc(operation, register_a, register_bx: u32) -> u32 {
	if operation > MASK_OP || register_a > MASK_A || register_bx > MASK_Bx do panic("field out of range @MAKE_ABX")
	return(
		u32((operation & MASK_OP) << POS_OP) |
		u32((register_a & MASK_A) << POS_A) |
		u32((register_bx & MASK_Bx) << POS_C) \
	)
}
MAKE_ASBX :: proc(operation, register_a: u32, register_sbx: i32) -> u32 {
	biased := u32(register_sbx + i32(BxBIAS))
	return MAKE_ABX(operation, register_a, biased)
}
DECODE_ABC :: proc(instruction: u32) -> (operation, register_a, register_b, register_c: u32) {
	operation = u32((instruction >> POS_OP) & u32(MASK_OP))
	register_a = u32((instruction >> POS_A) & u32(MASK_A))
	register_c = u32((instruction >> POS_C) & u32(MASK_C))
	register_b = u32((instruction >> POS_B) & u32(MASK_B))
	return
}
DECODE_ABX :: proc(instruction: u32) -> (operation, register_a, register_bx: u32) {
	operation = u32((instruction >> POS_OP) & u32(MASK_OP))
	register_a = u32((instruction >> POS_A) & u32(MASK_A))
	register_bx = u32((instruction >> POS_C) & u32(MASK_Bx))
	return
}
DECODE_ASBX :: proc(instruction: u32) -> (u32, u32, i32) {
	operation, register_a, register_bx := DECODE_ABX(instruction)
	register_sbx := i32(register_bx) - i32(BxBIAS)
	return operation, register_a, register_sbx
}
MAKE_INSTRUCTION :: proc(op: Opcodes, operands: ..int) -> u32 {
	def, ok := LOOKUP(op)
	if !ok do return 0
	switch def.format {
	case .FORMAT_ABC:
		return MAKE_ABC(u32(op), u32(operands[0]), u32(operands[1]), u32(operands[2]))
	case .FORMAT_ABx:
		return MAKE_ABX(u32(op), u32(operands[0]), u32(operands[1]))
	case .FORMAT_AsBx:
		return MAKE_ASBX(u32(op), u32(operands[0]), i32(operands[1]))
	}
	return 0
}

