local WS = game:GetService("Workspace")

local function findMerchantsRoot()
	local gameFolder = WS:FindFirstChild("Game")
	if gameFolder then
		local m = gameFolder:FindFirstChild("Merchants")
		if m then return m end
	end
	for _, inst in ipairs(WS:GetDescendants()) do
		if inst.Name == "Merchants" and inst:IsA("Folder") then
			return inst
		end
	end
	return nil
end

local root = findMerchantsRoot() or WS:WaitForChild("Game"):WaitForChild("Merchants")
local lines = {}
lines[#lines + 1] = "Abyss Merchant Item Scan"
lines[#lines + 1] = "Root: " .. root:GetFullName()

local t0 = os.clock()
while #root:GetChildren() == 0 and os.clock() - t0 < 5 do
	task.wait(0.2)
end

lines[#lines + 1] = "Merchant count: " .. tostring(#root:GetChildren())

local function addLine(s)
	lines[#lines + 1] = s
end

for _, merchant in ipairs(root:GetChildren()) do
	addLine("")
	addLine(merchant.Name .. " | class=" .. merchant.ClassName)
	local folder = merchant:FindFirstChild("Folder")
	local sign = folder and folder:FindFirstChild("Sign")
	local time = sign and sign:FindFirstChild("Time")
	local timeSurface = time and time:FindFirstChild("SurfaceGui")
	local timeLabel = timeSurface and timeSurface:FindFirstChild("Label")
	if timeLabel and timeLabel:IsA("TextLabel") then
		addLine("  Restock | " .. timeLabel.Text .. " | " .. timeLabel:GetFullName())
	end
	local tableRoot = folder and folder:FindFirstChild("Table")
	if tableRoot then
		local t1 = os.clock()
		while #tableRoot:GetChildren() == 0 and os.clock() - t1 < 5 do
			task.wait(0.2)
		end
		for _, slot in ipairs(tableRoot:GetChildren()) do
			local id = tonumber(slot.Name)
			if id then
				local item = slot:FindFirstChild("Item")
				local surface = item and item:FindFirstChild("SurfaceGui")
				local label = surface and surface:FindFirstChild("Label")
				if label and label:IsA("TextLabel") then
					local t2 = os.clock()
					while label.Text == "" and os.clock() - t2 < 3 do
						task.wait(0.1)
					end
					addLine(string.format("  Slot %s | %s | %s", slot.Name, label.Text, label:GetFullName()))
				else
					addLine(string.format("  Slot %s | (no label)", slot.Name))
				end
				local stock = slot:FindFirstChild("Stock")
				local stockSurface = stock and stock:FindFirstChild("SurfaceGui")
				local stockLabel = stockSurface and stockSurface:FindFirstChild("Label")
				if stockLabel and stockLabel:IsA("TextLabel") then
					addLine(string.format("    Stock | %s | %s", stockLabel.Text, stockLabel:GetFullName()))
				end
			end
		end
	else
		addLine("  (no table)")
	end
end

local out = table.concat(lines, "\n")
print(out)
if type(setclipboard) == "function" then
	pcall(setclipboard, out)
end
