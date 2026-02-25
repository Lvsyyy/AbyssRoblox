local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local S = RS.common.packages.Knit.Services
local InvRF = S.InventoryService.RF
local SellRF = S.SellService.RF.SellInventory

local EquipArtifactsLoadoutRF = InvRF.EquipArtifactsLoadout

local old = pg:FindFirstChild("SellAllGui")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "SellAllGui"
sg.ResetOnSpawn = false
sg.Parent = pg

local frame = Instance.new("Frame")
frame.Parent = sg
frame.Size = UDim2.fromOffset(140, 55)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.Active = true
frame.Draggable = true
frame.Position = UDim2.fromOffset(100, 100)
frame.BorderSizePixel = 0

local btn = Instance.new("TextButton")
btn.Parent = frame
btn.Position = UDim2.fromOffset(10, 10)
btn.Size = UDim2.fromOffset(120, 34)
btn.BackgroundColor3 = Color3.fromRGB(136, 108, 168)
btn.Font = Enum.Font.GothamSemibold
btn.TextSize = 13
btn.TextColor3 = Color3.fromRGB(240, 240, 240)
btn.Text = "Sell All"
btn.BorderSizePixel = 0

btn.MouseButton1Click:Connect(function()
	EquipArtifactsLoadoutRF:InvokeServer(4)
	SellRF:InvokeServer()
end)
