local WS = game:GetService("Workspace")

local root = WS:WaitForChild("Game"):WaitForChild("Merchants")
local lines = {}
lines[#lines + 1] = "Abyss Merchant Item Scan"

local function addLine(s)
	lines[#lines + 1] = s
end

for _, merchant in ipairs(root:GetChildren()) do
	if merchant:IsA("Model") then
		addLine("")
		addLine(merchant.Name)
		local folder = merchant:FindFirstChild("Folder")
		local tableRoot = folder and folder:FindFirstChild("Table")
		if tableRoot then
			for _, slot in ipairs(tableRoot:GetChildren()) do
				local id = tonumber(slot.Name)
				if id then
					local item = slot:FindFirstChild("Item")
					local surface = item and item:FindFirstChild("SurfaceGui")
					local label = surface and surface:FindFirstChild("Label")
					if label and label:IsA("TextLabel") then
						addLine(string.format("  Slot %s | %s | %s", slot.Name, label.Text, label:GetFullName()))
					else
						local anyLabel = slot:FindFirstChildWhichIsA("TextLabel", true)
						if anyLabel then
							addLine(string.format("  Slot %s | %s | %s", slot.Name, anyLabel.Text, anyLabel:GetFullName()))
						else
							addLine(string.format("  Slot %s | (no label)", slot.Name))
						end
					end
				end
			end
		else
			addLine("  (no table)")
		end
	end
end

local out = table.concat(lines, "\n")
print(out)
if type(setclipboard) == "function" then
	pcall(setclipboard, out)
end
