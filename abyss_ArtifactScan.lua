local RS = game:GetService("ReplicatedStorage")
local artifacts = require(RS.common.library).artifacts

local cachedNames = nil

local function scanArtifactNames()
	if cachedNames then
		return cachedNames
	end

	local names = {}
	for k, v in pairs(artifacts) do
		if type(k) == "string" and type(v) == "table" then
			names[#names + 1] = k
		end
	end
	table.sort(names, function(a, b) return a:lower() < b:lower() end)
	cachedNames = names
	return cachedNames
end

return {
	scanArtifactNames = scanArtifactNames,
}
