# difference from lua
|lua| ouau|
|---| --- |
|bnot: '~21->22' | bnot: '!21->22' |
# Goal
- Be as deterministic as possible with the table order.
# Why this is deterministic
- No random seeds.
- Same byte-order for all types.
- Floats hashed by bit pattern (matches Lua).
- Pointers hashed by their numeric address (stable within a run).
- Strings hashed byte-by-byte in lexical order.
- This ensures stable hashing across runs given identical input data.
# BUGS
```odin
package ouau
import "core:fmt"
sort.slice(table.sorted, compare_keytag);
```
