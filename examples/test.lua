do
	a = function(x, y)
		return x + y
	end
	M = {
		["a(1,2)"] = a(1, 2),
	}
	print(M["a(1,2)"]) -- prints 3
end
