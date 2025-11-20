package ouau
import "core:slice"
NEW_ENVIRONMENT :: proc(outer: ^Environment, allocator := context.allocator) -> ^Environment
{
	env := new(Environment, allocator)
	env.outer = outer
	env.values = make(map[string]Value, allocator)
	return env
}
ENV_GET :: proc(env: ^Environment, name: string) -> (Value, bool)
{
	e := env
	for e != nil
	{
		if v, ok := e.values[name]; ok
		{
			return v, true
		}
		e = e.outer
	}
	return nil, false
}
ENV_SET :: proc(env: ^Environment, name: string, v: Value)
{
	env.values[name] = v
	env.dirty = true
}
ENV_SET_UPWARD :: proc(env: ^Environment, name: string, v: Value)
{
	e := env
	for e != nil
	{
		if _, ok := e.values[name]; ok
		{
			e.values[name] = v
			e.dirty = true
			return
		}
		e = e.outer
	}

	env.values[name] = v
	env.dirty = true
}
ENV_RESORT :: proc(env: ^Environment)
{
	if !env.dirty do return
	env_len := len(env.sorted)
	clear(&env.sorted)
	resize(&env.sorted, env_len)
	for k in env.values
	{
		append(&env.sorted, k)
	}

	slice.sort_by(env.sorted[:], proc(a, b: string) -> bool
	{
		return a < b
	})

	env.dirty = false
}

