package ouau

GC_HEADER :: struct {
	marked: bool, // TAGGED ON EVERY OBJ
}
GC_HEAP :: struct {
	objects: [dynamic]rawptr, // pointers to base of each allocated object
}
// 3. Define what “roots” are
// Roots are objects always considered reachable:
// Global variables (Interpreter.globals)
// Current environment chain (Interpreter.current)
// Call stack frames (Interpreter.call_stack)
// Any temporary values in registers (if you have registers in VM)
// Constants used by currently loaded closures (if using prototypes)
// You must walk all of these during the mark phase.
// 4. Mark functions
// The mark step is a DFS through objects referenced by values.
// 5. Sweep phase
// After marking: free all unmarked objects, and reset mark bits on survivors.
// 6. Garbage collection Every N allocations or before large allocations.
// gc_collect :: proc(interp: ^Interpreter) {
//     mark_roots(interp)
//     sweep()
// }
// 7. When to mark registers / temporary VM values
// In your VM loop, before running a GC step:
// Mark registers: these hold Value which may reference tables/closures.
// Mark call stack frames
// Mark global environment
// Mark any pending return value
//A generational GC is just an optimization layered on top of your existing mark-and-sweep collector. You do not throw away what you already have. You augment it with:
// Two (sometimes three) generations
// A remembered set / write barrier
// Fast collection of young objects only
// Occasional full GC of both young + old/ If your instructions store values in a register array:
// GC_Header :: struct {
//     marked:     bool,
//     generation: u8,   // 0 = young, 1 = old
// }
// GC_Heap :: struct {
//     young: [dynamic]rawptr,
//     old:   [dynamic]rawptr,
// }
// 4. Write barrier (the key detail)
// A generational GC only works if you track old objects that gained a reference to young objects. Otherwise minor GC would miss them.
// Every time you store a pointer into an object:
// If parent is old
// And child is young
// Add parent to the remembered set.

