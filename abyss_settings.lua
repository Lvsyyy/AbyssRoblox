local HttpService = game:GetService("HttpService")

local function save(path, payload)
	if not (writefile and type(path) == "string" and type(payload) == "table") then
		return false
	end
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	if not ok or type(encoded) ~= "string" then
		return false
	end
	return pcall(writefile, path, encoded)
end

local function parseLegacyFishList(data)
	local list = {}
	for line in data:gmatch("[^\r\n]+") do
		local s = line:gsub("^%s+", ""):gsub("%s+$", "")
		if s ~= "" then
			list[#list + 1] = s
		end
	end
	if #list > 0 then
		return { fishNames = list }
	end
	return nil
end

local function load(path)
	if not (isfile and readfile and type(path) == "string" and isfile(path)) then
		return nil
	end
	local okRead, data = pcall(readfile, path)
	if not okRead or type(data) ~= "string" then
		return nil
	end

	local decoded
	local okJson = pcall(function()
		decoded = HttpService:JSONDecode(data)
	end)
	if okJson and type(decoded) == "table" then
		return decoded
	end

	return parseLegacyFishList(data)
end

return {
	save = save,
	load = load,
}
