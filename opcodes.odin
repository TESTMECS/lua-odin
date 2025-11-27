package ouau
/* 
*	 opcodes.odin
* Copyright(C) 2025 TESTMEE
* This file defines the @Opcodes and @Definition__Table__ for the Ouau VM. 
* The format of the opcodes and instructions is copied {lopcodes.h} from lua source 
* but is also described in detail here.
=================
*	 All instructions are 32 bit integers.
*	 The first 7 bits always contain an opcode.
*	 Instructions have the following formats:
*
*	 iABC |  C(8) | B(8) |k| A(8) | Op(7)    |
*
*	 ivABC |  vC(10) | vB(6) |k| A(8) | Op(7)|
*
*	 iABx  | Bx(17) | A(8) | Op(7) |
*
*	 iAsBx |  sBx(signed)(17) | A(8) | Op(7) |
*
*	 iAx   | Ax(25) |     Op(7)      |
*
*	 isJ   | sJ(signed)(25) | Op(7) |
=========
*	 v -> "variant"
*	 s -> "signed"
*	 x -> "extended"
* A signed argument is represented in excess K: The represented value is
*  the written unsigned value minus K, where K is half (rounded down) the
*  maximum value for the corresponding unsigned argumen
*/
MASK :: proc "contextless" (n: int) -> u32 { return (u32(1) << u32(n)) - u32(1) }
MASK_OP := MASK(SIZE_OP)
MASK_A := MASK(SIZE_A)
MASK_B := MASK(SIZE_B)
MASK_C := MASK(SIZE_C)
MASK_Bx := MASK(SIZE_Bx)
// (1 << bx - 1) - 1 / (2^17) - 1
BxBIAS := (1 << (SIZE_Bx - 1)) - 1
// Size of C Field and variant
SIZE_C :: 8
SIZE_vC :: 10
// Size of B Field and variant
SIZE_B :: 8
SIZE_vB :: 6
SIZE_Bx :: (SIZE_C + SIZE_B + 1)
// Size of A Field and extended
SIZE_A :: 8
SIZE_Ax :: (SIZE_A + SIZE_Bx)
// Size of sJ Field
SIZE_sJ :: (SIZE_A + SIZE_Bx)
// Size of the Op Field
SIZE_OP :: 7
// Position of OP, always 0
POS_OP :: 0
// Position of A, and extended Ax
POS_A :: POS_OP + SIZE_OP
POS_Ax :: POS_A
// Position of k
POS_k :: POS_A + SIZE_A
// Position of B and variant B, and extended Bx
POS_B :: POS_k + 1
POS_vB :: POS_k + 1
POS_Bx :: POS_k
// Position of C and variant C
POS_C :: POS_B + SIZE_B
POS_vC :: POS_vB + SIZE_vB
// Pos signed jump
POS_sJ :: POS_A

/* Opcodes 
Name|<Args>|<Description>|
*/
NUM_OPCODES :: 81

Opcodes :: enum {
	MOVE       = 0, /*| A, B | Reg[A] := R[B]|*/
	LOADI      = 1, /*|A, sBx | R[A] := sBx|*/
	LOADF      = 2, /*|A, sBx | R[A] := (ONumber)sBx|*/
	LOADK      = 3, /*|A, Bx | R[A] := K[Bx]| */
	LOADKX     = 4, /*|A | R[A] := K[extra arg]|*/
	LOADFALSE  = 5, /*|A | R[A] := false |*/
	LFALSESKIP = 6, /*|A | R[A] := false; pc++|*/
	LOADTRUE   = 7, /*|A | R[A] := true |*/
	LOADNIL    = 8, /*|A,B | R[A], R[A+1], ..., R[A+B] := nil|*/
	GETUPVAL   = 9, /*|A,B | R[A] := UpValue[B] |*/
	SETUPVAL   = 10, /*|A,B | UpValue[B] := R[A]|*/
	GETTABUP   = 11, /*|A, B, C | R[A] := UpValue[B][K[C]:shortstring]*/
	GETTABLE   = 12, /*|A, B, C | R[A] := R[B][R[C]] |*/
	GETI       = 13, /*|A, B, C | R[A] := R[B][C] |*/
	GETFIELD   = 14, /*|A, B, C | R[A] := R[B][K[C]:shortstring] |*/
	SETTABUP   = 14, /*|A, B, C | UpValue[A][K[B]:shortstring] := R[C] |*/
	SETTABLE   = 15, /*|A, B, C | R[A][R[B]] := RK[C] |*/
	SETI       = 16, /*|A, B, C | R[A][B] := RK(C) |*/
	SETFIELD   = 17, /*|A, B, C | R[A][K[B]:shortstring] := RK(C) |*/
	NEWTABLE   = 18, /*|A, vB, vC, k | R[A] := {} |*/
	SELF       = 19, /*|A, B, C| R[A+1] := R[B]; R[A] := R[B][K[C]:shortstring] |*/
	ADDI       = 20, /*|A, B, sC | R[A] := R[B] + sC |*/
	ADDK       = 21, /*|A,B,C | R[A] := R[B] + K[C]:number |*/
	SUBK       = 22, /*|A,B,C | R[A] := R[B] - K[C]:number |*/
	MULK       = 23, /*|A,B,C | R[A] := R[B] * K[C]:number |*/
	MODK       = 24, /*|A,B,C | R[A] := R[B] % K[C]:number |*/
	POWK       = 25, /*|A,B,C | R[A] := R[B] ^ K[C]:number |*/
	DIVK       = 26, /*|A,B,C | R[A] := R[B] / K[C]:number |*/
	IDIVK      = 27, /*|A,B,C | R[A] := R[B] // K[C]:number |*/
	BANDK      = 28, /*|A,B,C | R[A] := R[B] & K[C]:number |*/
	BORK       = 29, /*|A,B,C | R[A] := R[B] | K[C]:number |*/
	BXORK      = 30, /*|A,B,C | R[A] := R[B] ~ K[C]:number |*/
	SHLI       = 31, /*|A,B,sC | R[A] := sC << R[B] |*/
	SHRI       = 32, /*|A,B,sC | R[A] := sC >> R[B] |*/
	ADD        = 33, /*|A,B,C | R[A] := R[B] + R[C] |*/
	SUB        = 34, /*|A,B,C | R[A] := R[B] - R[C] |*/
	MUL        = 35, /*|A,B,C | R[A] := R[B] * R[C] |*/
	MOD        = 36, /*|A,B,C | R[A] := R[B] % R[C] |*/
	POW        = 37, /*|A,B,C | R[A] := R[B] ^ R[C] |*/
	DIV        = 38, /*|A,B,C | R[A] := R[B] / R[C] |*/
	IDIV       = 39, /*|A,B,C | R[A] := R[B] // R[C] |*/
	BAND       = 40, /*|A,B,C | R[A] := R[B] & R[C] |*/
	BOR        = 41, /*|A,B,C | R[A] := R[B] | R[C] |*/
	BXOR       = 42, /*|A,B,C | R[A] := R[B] ~ R[C] |*/
	SHL        = 43, /*|A,B,C | R[A] := R[B] << R[C] |*/
	SHR        = 44, /*|A,B,C | R[A] := R[B] >> R[C] |*/
	MMBIN      = 45, /*|A,sB,C,k | call C metamethod over R[A] and R[B] |*/
	MMBINI     = 46, /*|A,B,C,k | call C metamethod over R[A] and sB |*/
	UNM        = 47, /*|A,B | R[A] := -R[B] |*/
	BNOT       = 48, /*|A,B | R[A] := ~R[B] |*/
	NOT        = 49, /*|A,B | R[A] := not R[B] |*/
	LEN        = 50, /*|A,B | R[A] := #R[B] |*/
	CONCAT     = 51, /*|A,B | R[A] := R[A].. ... ..R[(A+B-1)]|*/
	CLOSE      = 52, /*|A | close all upvalues >= R[A] |*/
	TBC        = 53, /*|A | A mark variable A "To be closed"  |*/
	JMP        = 54, /*|sJ | pc += sJ | */
	EQ         = 55, /*|A,B,k | if ((R[A] == R[B]) ~= k); pc++|*/
	LT         = 56, /*|A,B,k | if ((R[A] < R[B]) ~= k); pc++|*/
	LE         = 57, /*|A,B,k | if ((R[A] <= R[B]) ~= k); pc++|*/
	EQK        = 58, /*|A,B,k | if ((R[A] == K[B]) ~= k); pc++|*/
	EQI        = 59, /*|A sB k | if ((R[A] == sB) ~= k); pc++|*/
	LTI        = 60, /*|A sB k | if ((R[A] < sB) ~= k); pc++|*/
	LEI        = 61, /*|A sB k | if ((R[A] <= sB) ~= k); pc++|*/
	GTI        = 62, /*|A sB k | if ((R[A] > sB) ~= k); pc++|*/
	GEI        = 63, /*|A sB k | if ((R[A] >= sB) ~= k); pc++|*/
	TEST       = 64, /*|A, k| if (not R[A] == k) then pc++*/
	TESTSET    = 65, /*|A,B,k | if (not R[B] == k) then pc++ else R[A] := R[B]|*/
	CALL       = 66, /*|A,B,C | R[A] := R[A+C-2] := R[A](R[A+1],...,R[A+B-1])|*/
	TAILCALL   = 67, /*|A,B,C,k | return R[A] (R[A+1], ..., R[A+B-1]) */
	RETURN     = 68, /*|A,B,C,k | return R[A], ... ,R[A+B-2] */
	RETURN0    = 69, /* return */
	RETURN1    = 70, /*|A| return R[A]| */
	FORLOOP    = 71, /*|A, Bx| update counters; if loop continues then pc-=Bx; */
	FORPREP    = 72, /*|A, Bx| <check values and prepare counters>; if not to run then pc+=Bx+1; */
	TFORPREP   = 73, /*|A, Bx|create upvalue for R[A+3]; pc+=Bx |*/
	TFORCALL   = 74, /*|A, C| R[A+4], ... , R[A+3+C] := R[A](R[A+1], R[A+2]); |*/
	TFORLOOP   = 75, /*|A, Bx|if R[A+2] ~= nil then { R[A]=R[A+2]; pc -= Bx }|*/
	SETLIST    = 76, /*|A, vB, vC, k|R[A][vC+i] := R[A+i], 1 <= i <= vB; |*/
	CLOSURE    = 77, /*|A, Bx|R[A] := closure(KProto[Bx]) |*/
	VARARG     = 78, /*|A, C| R[A], R[A+1], ..., R[A+C-2] = vararg; |*/
	GETVARG    = 79, /*|A, B, C| R[A] := R[B][R[C]], R[B] is vararg parameter |*/
	ERRNNIL    = 80, /*|A, Bx|raise error if R[A] ~= nil (K[Bx] is global name) |*/
	VARARGPREP = 81, /* Prepare vararg parameters |*/
	EXTRAARG   = 82, /* Ax| extra (larger) argument for previous opcode |*/
}
Format :: enum {
	FORMAT_iABC,
	FORMAT_ivABC,
	FORMAT_iABx,
	FORMAT_iAsBx,
	FORMAT_iAx,
	FORMAT_isJ,
}
OPMODE_MM :: u8(1 << 7)
OPMODE_OT :: u8(1 << 6)
OPMODE_IT :: u8(1 << 5)
OPMODE_T :: u8(1 << 4)
OPMODE_A :: u8(1 << 3)
// instruction format is lower 3 bits
iABC :: u8(0)
iABx :: u8(1)
iAsBx :: u8(2)
iAx :: u8(3)
opmode :: proc "contextless" (mm, ot, it, t, a: bool, mode: u8) -> u8 {
	// mm, ot, it, t, a, mode
	return(
		(u8(mm) << 7) |
		(u8(ot) << 6) |
		(u8(it) << 5) |
		(u8(t) << 4) |
		(u8(a) << 3) |
		(mode & 0b111) \
	)
}
// TODO: Double check this.
OpModes :: [NUM_OPCODES]u8 {
	opmode(false, false, false, false, true, iABC), // MOVE
	opmode(false, false, false, false, true, iAsBx), // LOADI
	opmode(false, false, false, false, true, iAsBx), // LOADF
	opmode(false, false, false, false, true, iABx), // LOADK
	opmode(false, false, false, false, true, iABx), // LOADKX
	opmode(false, false, false, false, true, iABC), // LOADFALSE
	opmode(false, false, false, false, true, iABC), // LFALSESKIP
	opmode(false, false, false, false, true, iABC), // LOADTRUE
	opmode(false, false, false, false, true, iABC), // LOADNIL
	opmode(false, false, false, false, true, iABC), // GETUPVAL
	opmode(false, false, false, false, false, iABC), // SETUPVAL
	opmode(false, false, false, false, true, iABC), // GETTABUP
	opmode(false, false, false, false, true, iABC), // GETTABLE
	opmode(false, false, false, false, true, iABC), // GETI
	opmode(false, false, false, false, true, iABC), // GETFIELD
	opmode(false, false, false, false, false, iABC), // SETTABUP
	opmode(false, false, false, false, false, iABC), // SETTABLE
	opmode(false, false, false, false, false, iABC), // SETI
	opmode(false, false, false, false, false, iABC), // SETFIELD
	opmode(false, false, false, false, true, ivABC), // NEWTABLE
	opmode(false, false, false, false, true, iABC), // SELF
	opmode(false, false, false, false, true, iABC), // ADDI
	opmode(false, false, false, false, true, iABC), // ADDK
	opmode(false, false, false, false, true, iABC), // SUBK
	opmode(false, false, false, false, true, iABC), // MULK
	opmode(false, false, false, false, true, iABC), // MODK
	opmode(false, false, false, false, true, iABC), // POWK
	opmode(false, false, false, false, true, iABC), // DIVK
	opmode(false, false, false, false, true, iABC), // IDIVK
	opmode(false, false, false, false, true, iABC), // BANDK
	opmode(false, false, false, false, true, iABC), // BORK
	opmode(false, false, false, false, true, iABC), // BXORK
	opmode(false, false, false, false, true, iABC), // SHLI
	opmode(false, false, false, false, true, iABC), // SHRI
	opmode(false, false, false, false, true, iABC), // ADD
	opmode(false, false, false, false, true, iABC), // SUB
	opmode(false, false, false, false, true, iABC), // MUL
	opmode(false, false, false, false, true, iABC), // MOD
	opmode(false, false, false, false, true, iABC), // POW
	opmode(false, false, false, false, true, iABC), // DIV
	opmode(false, false, false, false, true, iABC), // IDIV
	opmode(false, false, false, false, true, iABC), // BAND
	opmode(false, false, false, false, true, iABC), // BOR
	opmode(false, false, false, false, true, iABC), // BXOR
	opmode(false, false, false, false, true, iABC), // SHL
	opmode(false, false, false, false, true, iABC), // SHR
	opmode(true, false, false, false, false, iABC), // MMBIN
	opmode(true, false, false, false, false, iABC), // MMBINI
	opmode(true, false, false, false, false, iABC), // MMBINK
	opmode(false, false, false, false, true, iABC), // UNM
	opmode(false, false, false, false, true, iABC), // BNOT
	opmode(false, false, false, false, true, iABC), // NOT
	opmode(false, false, false, false, true, iABC), // LEN
	opmode(false, false, false, false, true, iABC), // CONCAT
	opmode(false, false, false, false, false, iABC), // CLOSE
	opmode(false, false, false, false, false, iABC), // TBC
	opmode(false, false, false, false, true, isJ), // JMP
	opmode(false, false, false, true, false, iABC), // EQ
	opmode(false, false, false, true, false, iABC), // LT
	opmode(false, false, false, true, false, iABC), // LE
	opmode(false, false, false, true, false, iABC), // EQK
	opmode(false, false, false, true, false, iABC), // EQI
	opmode(false, false, false, true, false, iABC), // LTI
	opmode(false, false, false, true, false, iABC), // LEI
	opmode(false, false, false, true, false, iABC), // GTI
	opmode(false, false, false, true, false, iABC), // GEI
	opmode(false, false, false, true, false, iABC), // TEST
	opmode(false, false, false, true, true, iABC), // TESTSET
	opmode(false, true, true, false, true, iABC), // CALL
	opmode(false, true, true, false, true, iABC), // TAILCALL
	opmode(false, false, true, false, true, iABC), // RETURN
	opmode(false, false, false, false, false, iABC), // RETURN0
	opmode(false, false, false, false, false, iABC), // RETURN1
	opmode(false, false, false, false, true, iABx), // FORLOOP
	opmode(false, false, false, false, true, iABx), // FORPREP
	opmode(false, false, false, false, false, iABx), // TFORPREP
	opmode(false, false, false, false, false, iABC), // TFORCALL
	opmode(false, false, false, false, true, iABx), // TFORLOOP
	opmode(false, false, true, false, false, ivABC), // SETLIST
	opmode(false, false, false, false, true, iABx), // CLOSURE
	opmode(false, true, false, false, true, iABC), // VARARG
	opmode(false, false, false, false, true, iABC), // GETVARG
	opmode(false, false, false, false, false, iABx), // ERRNNIL
	opmode(false, false, true, false, true, iABC), // VARARGPREP
	opmode(false, false, false, false, false, iABC), // EXTRAARG
}
/*
4. Notes for correctness
OT means “opcode produces multiple results” (open table, open call, varargs tail, etc.).
IT means “opcode consumes multiple results” (call-like IN instructions).
The flag check testOTMode(op) or testITMode(op) only works because you filled OpModes correctly.
*/
testOTMode :: proc(op: Opcodes) -> bool {
	return (OpModes[op] & OPMODE_OT) != 0
}

testITMode :: proc(op: Opcodes) -> bool {
	return (OpModes[op] & OPMODE_IT) != 0
}
luaP_isOT :: proc(i: Instruction) -> bool {
	op := GET_OPCODE(i)

	// OP_TAILCALL always uses OT
	if op == .TAILCALL {
		return true
	}

	// Otherwise: OT flag must be set AND C == 0
	return testOTMode(op) && (GETARG_C(i) == 0)
}
luaP_isIT :: proc(i: Instruction) -> bool {
	op := GET_OPCODE(i)

	if op == .SETLIST {
		return testITMode(op) && (GETARG_vB(i) == 0)
	}

	return testITMode(op) && (GETARG_B(i) == 0)
}

