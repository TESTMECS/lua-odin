package ouau

compare_keytag :: proc(a, b: KeyTag) -> bool
{
	// first: compare kind
	if a.kind != b.kind
	{
		return a.kind < b.kind
	}

	// kinds equal → compare payload
	switch a.kind
	{
	case 0:
		// string
		if a.s != b.s
		{
			return a.s < b.s // lexicographic
		}
		return false // equal

	case 1:
		// integer
		return a.i < b.i

	case 2:
		// float
		return a.f < b.f // handles +/-inf, NaN rules consistent

	case 3:
		return (a.i & 1) < (b.i & 1)

	case 4:
		checka := uintptr(a.p)
		ensure(checka != 0, "Invalid Rawptr")
		checkb := uintptr(b.p)
		ensure(checkb != 0, "Invalid Rawptr")
		return cast(u64)checka < cast(u64)checkb

	case 5:
		checka := uintptr(a.p)
		ensure(checka != 0, "Invalid Rawptr")
		checkb := uintptr(b.p)
		ensure(checkb != 0, "Invalid Rawptr")
		return cast(u64)checka < cast(u64)checkb

	case 6:
		checka := uintptr(a.p)
		ensure(checka != 0, "Invalid Rawptr")
		checkb := uintptr(b.p)
		ensure(checkb != 0, "Invalid Rawptr")
		return cast(u64)checka < cast(u64)checkb
	}

	return false
}

