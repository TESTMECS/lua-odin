do
	local b = function(x, y)
		return x + y
	end
	local a = {
		["add"] = b(1, 2),
	}
	print(a["add"]) -- 3
end
