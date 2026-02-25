local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local S = RS.common.packages.Knit.Services
local InvRF = S.InventoryService.RF
local EquipArtifactsLoadoutRF = InvRF.EquipArtifactsLoadout

local old = pg:FindFirstChild("ArtifactSetsGui")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "ArtifactSetsGui"
sg.ResetOnSpawn = false
sg.Parent = pg

local frame = Instance.new("Frame")
frame.Parent = sg
frame.Size = UDim2.fromOffset(360, 55)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.Active = true
frame.Draggable = true
frame.Position = UDim2.fromOffset(100, 240)
frame.BorderSizePixel = 0

local function btn(t, x, y, c)
	local b = Instance.new("TextButton")
	b.Parent = frame
	b.Position = UDim2.fromOffset(x, y)
	b.Size = UDim2.fromOffset(110, 34)
	b.BackgroundColor3 = c
	b.Font = Enum.Font.GothamSemibold
	b.TextSize = 13
	b.TextColor3 = Color3.fromRGB(240, 240, 240)
	b.Text = t
	b.BorderSizePixel = 0
	return b
end

local wBtn = btn("Weight Set",  10, 10, Color3.fromRGB(90, 110, 160))
local dBtn = btn("Damage Set", 125, 10, Color3.fromRGB(160, 110, 90))
local sBtn = btn("Speed Set",  240, 10, Color3.fromRGB(80, 130, 90))

wBtn.MouseButton1Click:Connect(function() EquipArtifactsLoadoutRF:InvokeServer(1) end)
dBtn.MouseButton1Click:Connect(function() EquipArtifactsLoadoutRF:InvokeServer(2) end)
sBtn.MouseButton1Click:Connect(function() EquipArtifactsLoadoutRF:InvokeServer(3) end)
