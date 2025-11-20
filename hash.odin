package ouau
import "core:hash"
hash_keytag :: proc(k: KeyTag) -> u64
{
	using hash
	buf: [64]u8 // plenty for controlled encoding
	idx := 0

	// always encode kind first
	buf[idx] = k.kind
	idx += 1

	switch k.kind
	{
	case 0:
		// string
		// write length (u32)
		len := cast(u32)len(k.s)
		transmute_u32_to_bytes(buf[idx:], len)
		idx += 4
		// write string bytes
		for b, i in k.s
		{
			buf[idx] = k.s[i]
			idx += 1
		}
	case 1:
		// integer
		transmute_i64_to_bytes(buf[idx:], k.i)
		idx += 8

	case 2:
		// float
		bits := transmute(u64)k.f
		transmute_u64_to_bytes(buf[idx:], bits)
		idx += 8

	case 3:
		// bool (encoded from `i`)
		buf[idx] = u8(k.i & 1)
		idx += 1

	case 4:
		// pointer
		check := uintptr(k.p)
		ensure(check != 0, "Invalid Rawptr")
		transmute_u64_to_bytes(buf[idx:], cast(u64)check)
		idx += 8

	case 5:
		// table pointer
		check := uintptr(k.p)
		ensure(check != 0, "Invalid Rawptr")
		transmute_u64_to_bytes(buf[idx:], cast(u64)check)
		idx += 8

	case 6:
		// closure pointer
		check := uintptr(k.p)
		ensure(check != 0, "Invalid Rawptr")
		transmute_u64_to_bytes(buf[idx:], cast(u64)check)
		idx += 8
	}

	return fnv64a(buf[:idx])
}
transmute_u32_to_bytes :: proc(dst: []u8, v: u32)
{
	dst[0] = u8(v >> 0)
	dst[1] = u8(v >> 8)
	dst[2] = u8(v >> 16)
	dst[3] = u8(v >> 24)
}

transmute_i64_to_bytes :: proc(dst: []u8, v: i64)
{
	u := transmute(u64)v
	transmute_u64_to_bytes(dst, u)
}

transmute_u64_to_bytes :: proc(dst: []u8, v: u64)
{
	for i in 0 ..< 8
	{
		dst[i] = u8(v >> uint(i * 8))
	}
}

