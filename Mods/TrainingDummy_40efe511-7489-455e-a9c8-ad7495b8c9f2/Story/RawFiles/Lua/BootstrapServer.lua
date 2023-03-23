Ext.Require("Shared.lua")

local ts = Classes.TranslatedString

local text = {
	CombatLogDamage = ts:CreateFromKey("LLDUMMY_CombatLog_TookDamage", "[[1]] [2] from [3] ([4])"),
	CombatLogDamageReport = ts:CreateFromKey("LLDUMMY_CombatLog_DamageReport", "Damage Report [[5]]<br>=========<br><font color='#33FF33'>Target</font>  [1]<br><font color='#FF3333'>Attacker</font>  [2]<br>Damage from ([3])<br>[4]<br>=========")
}

---@alias LLDummyDamageEntryData {Amount:integer, Hits:integer}
---@alias LLDummyDamageHitSourceData {Damages:table<DamageType, LLDummyDamageEntryData>, CriticalHit:boolean}
---@alias LLDummyAttackerData {Name:string, Damage:table<string,LLDummyDamageHitSourceData>}
---@alias LLDummyDamageData {Name:string, Attackers:table<Guid, LLDummyAttackerData>}

---@type table<Guid, LLDummyDamageData>
local aggregatedDamage = {}

local function AddDamageToLog()
	for GUID,damageData in pairs(aggregatedDamage) do
		local name = damageData.Name
		for attackerGUID,data in pairs(damageData.Attackers) do
			local attackerName = data.Name
			local sourcesText = ""
			local allDamageText = {}
			for source,damage in pairs(data.Damage) do
				for damageType,damageData in pairs(damage.Damages) do
					local damageText = GameHelpers.GetDamageText(damageType, damageData.Amount)
					allDamageText[#allDamageText+1] = string.format("%s (%ix)", damageText, damageData.Hits)
				end
				if sourcesText ~= "" then
					sourcesText = sourcesText .. "|"
				end
				sourcesText = sourcesText .. source
				if damage.CriticalHit then
					sourcesText = sourcesText .. " <font color='#FF7733'>[Critical Hit]</font>"
				end
			end
			table.sort(allDamageText)
			local finalDamageText = StringHelpers.Join("<br>", allDamageText)
			CombatLog.AddTextToAllPlayers("Combat", 
			text.CombatLogDamageReport:ReplacePlaceholders(name, attackerName, sourcesText, finalDamageText, Ext.Utils.MonotonicTime()))
		end
	end
	aggregatedDamage = {}
end

Ext.Events.BeforeCharacterApplyDamage:Subscribe(function(e)
	if not e.Target or not e.Target:HasTag("LLDUMMY_TrainingDummy") then
		return
	end

	local hitSource = ""
	
	if e.Context.Status then
		if not StringHelpers.IsNullOrEmpty(e.Context.Status.SkillId) then
			local skillId = GetSkillEntryName(e.Context.Status.SkillId)
			local skill = Ext.Stats.Get(skillId, nil, false)
			if skill then
				hitSource = string.format("Skill: <font color='%s' size='16'>%s</font>", Data.Colors.Ability[skill.Ability], GameHelpers.GetStringKeyText(skill.DisplayName, skill.DisplayNameRef))
			end
		else
			--local hitReason = GameHelpers.Hit.GetHitReason(context.HitStatus.HitReason)
			hitSource = string.format("Source: <font color='#FFAA33'>%s</font>", e.Context.Status.DamageSourceType)
		end
	end

	local attacker = nil
	local attackerId = "Unknown"

	if e.Attacker and e.Attacker.Character then
		attacker = e.Attacker.Character
		attackerId = GameHelpers.GetUUID(attacker) --[[@as Guid]]
	end

	if aggregatedDamage[e.Target.MyGuid] == nil then
		aggregatedDamage[e.Target.MyGuid] = {
			Name = string.format("%s (%s)", GameHelpers.GetDisplayName(e.Target), e.Target.NetID),
			Attackers = {}
		}
	end

	if aggregatedDamage[e.Target.MyGuid].Attackers[attackerId] == nil then
		aggregatedDamage[e.Target.MyGuid].Attackers[attackerId] = {
			Damage = {}
		}
	end

	local attackerData = aggregatedDamage[e.Target.MyGuid].Attackers[attackerId]
	if attackerData.Damage[hitSource] == nil then
		attackerData.Damage[hitSource] = {
			Damages = {},
			CriticalHit = false
		}
	end
	local damageData = attackerData.Damage[hitSource].Damages

	if e.Hit.CriticalHit then
		attackerData.Damage[hitSource].CriticalHit = true
	end

	if attacker then
		attackerData.Name = string.format("%s (%s)", GameHelpers.GetDisplayName(attacker), attacker.NetID)
	else
		attackerData.Name = "Unknown"
	end
	
	for k,v in pairs(e.Hit.DamageList:ToTable()) do
		if damageData[v.DamageType] == nil then
			damageData[v.DamageType] = {Amount = 0, Hits = 0}
		end
		damageData[v.DamageType].Amount = damageData[v.DamageType].Amount + v.Amount
		damageData[v.DamageType].Hits = damageData[v.DamageType].Hits + 1
	end
	Timer.Cancel("LLDUMMY_AddInfoToCombatLog")
	Timer.StartOneshot("LLDUMMY_AddInfoToCombatLog", 2000, AddDamageToLog)
end)

Ext.Osiris.RegisterListener("RequestPickpocket", 2, "after", function (player, target)
	if IsTagged(target, "LLDUMMY_TrainingDummy") == 1 then
		StartPickpocket(player,target,1)
	end
end)