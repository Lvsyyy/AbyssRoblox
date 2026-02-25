local RS = game:GetService("ReplicatedStorage")

local rf = RS.common.packages.Knit.Services.ArtifactsService.RF.SetAutoDelete

local function setAutoDelete(name, enabled)
	return rf:InvokeServer(name, enabled)
end

return {
	setAutoDelete = setAutoDelete,
}
