local RS = game:GetService("ReplicatedStorage")
local artifacts = require(RS.common.library).artifacts

local function scanArtifactNames()
	local names = {}
	for k, v in pairs(artifacts) do
		if type(k) == "string" and type(v) == "table" then
			names[#names + 1] = k
		end
	end
	table.sort(names, function(a, b) return a:lower() < b:lower() end)
	return names
end

return {
	scanArtifactNames = scanArtifactNames,
}
