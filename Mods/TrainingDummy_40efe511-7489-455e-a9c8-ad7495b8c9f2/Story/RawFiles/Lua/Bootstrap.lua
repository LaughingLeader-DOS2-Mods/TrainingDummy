
local function GameSessionLoad()
	Ext.Print("[TargetDummy:Bootstrap.lua] Session is loading.")
	if _G["LeaderLib"] ~= nil then

	end
end

--v36 and higher
if Ext.RegisterListener ~= nil then
    Ext.RegisterListener("SessionLoading", GameSessionLoad)
end