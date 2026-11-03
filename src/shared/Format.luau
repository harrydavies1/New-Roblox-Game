--!strict
local Format = {}
function Format.number(value: number): string
	local n = math.max(0, value)
	for _, unit in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		local divisor = unit[1] :: number
		if n >= divisor then
			return (string.format("%.1f", n / divisor):gsub("%.0$", "")) .. (unit[2] :: string)
		end
	end
	return tostring(math.floor(n))
end
function Format.percent(value: number): string
	return string.format("+%d%%", math.floor(value * 100 + 0.5))
end
return Format
