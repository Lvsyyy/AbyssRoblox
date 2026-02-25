local P=game:GetService("Players").LocalPlayer
local RS=game:GetService("ReplicatedStorage")
local rf=RS.common.packages.Knit.Services.ArtifactsService.RF.SetAutoDelete
local a=require(RS.common.library).artifacts
pcall(function()P.PlayerGui.ArtifactAutoDeleteGUI:Destroy()end)

local n={} for k,v in pairs(a) do if type(k)=="string" and type(v)=="table" then n[#n+1]=k end end
table.sort(n,function(x,y)return x:lower()<y:lower()end)

local g=Instance.new("ScreenGui",P.PlayerGui) g.Name="ArtifactAutoDeleteGUI" g.ResetOnSpawn=false
local f=Instance.new("Frame",g) f.Size=UDim2.fromOffset(320,380) f.Position=UDim2.new(.5,-160,.5,-190) f.BackgroundColor3=Color3.fromRGB(28,28,32) f.BorderSizePixel=0 f.Active=true f.Draggable=true
Instance.new("UICorner",f).CornerRadius=UDim.new(0,8)

local s=Instance.new("TextBox",f) s.Size=UDim2.new(1,-49,0,28) s.Position=UDim2.fromOffset(8,8) s.PlaceholderText="Search artifact..." s.ClearTextOnFocus=false s.Text="" s.Font=Enum.Font.Gotham s.TextSize=14 s.TextColor3=Color3.new(1,1,1) s.PlaceholderColor3=Color3.fromRGB(170,170,170) s.BackgroundColor3=Color3.fromRGB(40,40,48) s.BorderSizePixel=0
Instance.new("UICorner",s).CornerRadius=UDim.new(0,6)

local x=Instance.new("TextButton",f) x.Size=UDim2.fromOffset(26,26) x.Position=UDim2.new(1,-34,0,9) x.Text="×" x.Font=Enum.Font.GothamBold x.TextSize=18 x.TextColor3=Color3.new(1,1,1) x.BackgroundColor3=Color3.fromRGB(60,60,70) x.BorderSizePixel=0
Instance.new("UICorner",x).CornerRadius=UDim.new(0,6)

local l=Instance.new("ScrollingFrame",f) l.Size=UDim2.new(1,-16,1,-86) l.Position=UDim2.fromOffset(8,42) l.BackgroundColor3=Color3.fromRGB(34,34,40) l.BorderSizePixel=0 l.ScrollBarThickness=6
Instance.new("UICorner",l).CornerRadius=UDim.new(0,8)
local lo=Instance.new("UIListLayout",l) lo.Padding=UDim.new(0,4)
local pd=Instance.new("UIPadding",l) pd.PaddingTop=UDim.new(0,4) pd.PaddingBottom=UDim.new(0,4) pd.PaddingLeft=UDim.new(0,4) pd.PaddingRight=UDim.new(0,4)

local e=Instance.new("TextButton",f) e.Size=UDim2.new(.5,-12,0,28) e.Position=UDim2.new(0,8,1,-36) e.Text="Enable" e.Font=Enum.Font.GothamBold e.TextSize=13 e.TextColor3=Color3.new(1,1,1) e.BackgroundColor3=Color3.fromRGB(58,120,66) e.BorderSizePixel=0
Instance.new("UICorner",e).CornerRadius=UDim.new(0,6)
local d=Instance.new("TextButton",f) d.Size=UDim2.new(.5,-12,0,28) d.Position=UDim2.new(.5,4,1,-36) d.Text="Disable" d.Font=Enum.Font.GothamBold d.TextSize=13 d.TextColor3=Color3.new(1,1,1) d.BackgroundColor3=Color3.fromRGB(120,62,62) d.BorderSizePixel=0
Instance.new("UICorner",d).CornerRadius=UDim.new(0,6)

local sel,rows=nil,{}
local function paint()
	for name,b in pairs(rows) do if b.Parent then b.BackgroundColor3=(name==sel and Color3.fromRGB(70,94,138) or Color3.fromRGB(45,45,54)) end end
end
local function rebuild()
	for _,b in pairs(rows) do if b.Parent then b:Destroy() end end rows={}
	local q=s.Text:lower()
	for _,name in ipairs(n) do
		if q=="" or name:lower():find(q,1,true) then
			local b=Instance.new("TextButton",l)
			b.Size=UDim2.new(1,-8,0,24) b.Text=name b.TextXAlignment=Enum.TextXAlignment.Left b.Font=Enum.Font.Gotham b.TextSize=13 b.TextColor3=Color3.new(1,1,1) b.BackgroundColor3=Color3.fromRGB(45,45,54) b.BorderSizePixel=0
			Instance.new("UICorner",b).CornerRadius=UDim.new(0,5)
			local p=Instance.new("UIPadding",b) p.PaddingLeft=UDim.new(0,8)
			b.MouseButton1Click:Connect(function() sel=name paint() end)
			rows[name]=b
		end
	end
	task.defer(function() l.CanvasSize=UDim2.new(0,0,0,lo.AbsoluteContentSize.Y+8) paint() end)
end
local function set(v)
	if not sel then return end
	local ok,res=pcall(function() return rf:InvokeServer(sel,v) end)
	print(sel,v,ok,res)
end

s:GetPropertyChangedSignal("Text"):Connect(rebuild)
e.MouseButton1Click:Connect(function() set(true) end)
d.MouseButton1Click:Connect(function() set(false) end)
x.MouseButton1Click:Connect(function() g:Destroy() end)
rebuild()