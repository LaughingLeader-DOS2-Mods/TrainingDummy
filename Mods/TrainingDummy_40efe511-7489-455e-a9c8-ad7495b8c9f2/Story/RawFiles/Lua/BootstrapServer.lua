Ext.Require("BootstrapShared.lua")

local ts = Classes.TranslatedString

local text = {
	CombatLogDamage = ts:CreateFromKey("LLDUMMY_CombatLog_TookDamage", "[[1]] [2] from [3] ([4])"),
	CombatLogDamageReport = ts:CreateFromKey("LLDUMMY_CombatLog_DamageReport", "Damage Report [[5]]<br>=========<br><font color='#33FF33'>Target</font>  [1]<br><font color='#FF3333'>Attacker</font>  [2]<br>Damage from ([3])<br>[4]<br>=========")
}

---@alias LLDummyDamageEntryData {Amount:integer, Hits:integer}
---@alias LLDummyDamageHitSourceData {Damages:table<DamageType, LLDummyDamageEntryData>, CriticalHit:boolean}
---@alias LLDummyAttackerData {Name:string, Damage:table<string,LLDummyDamageHitSourceData>}
---@alias LLDummyDamageData {Name:string, Attackers:table<UUID, LLDummyAttackerData>}

---@type table<UUID, LLDummyDamageData>
local aggregatedDamage = {}

local function AddDamageToLog()
	for GUID,data in pairs(aggregatedDamage) do
		local name = data.Name
		for attackerGUID,data in pairs(data.Attackers) do
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
			text.CombatLogDamageReport:ReplacePlaceholders(name, attackerName, sourcesText, finalDamageText, Ext.MonotonicTime()))
		end
	end
	aggregatedDamage = {}
end

--- Every type of damage deals pure damage now, so armor is unaffected. Damage is reduced by armor.
---@param target EsvCharacter
---@param attacker StatCharacter|StatItem
---@param hit HitRequest
---@param causeType string
---@param impactDirection number[]
---@param context HitContext
---@return HitRequest
Ext.RegisterListener("BeforeCharacterApplyDamage", function(target, attacker, hit, causeType, impactDirection, context)
    if target:HasTag("LLDUMMY_TrainingDummy") then

		local damageList = Ext.NewDamageList()
		for k,v in pairs(hit.DamageList:ToTable()) do
			if v.Amount > 0 then
				damageList:Add(v.DamageType, v.Amount)
			end
		end

		local hitSource = ""
		
		if context.HitStatus then
			if not StringHelpers.IsNullOrEmpty(context.HitStatus.SkillId) then
				local skillId = GetSkillEntryName(context.HitStatus.SkillId)
				local skill = Ext.GetStat(skillId)
				hitSource = string.format("Skill: <font color='%s' size='16'>%s</font>", Data.Colors.Ability[skill.Ability], GameHelpers.GetStringKeyText(skill.DisplayName, skill.DisplayNameRef))
			else
				--local hitReason = GameHelpers.Hit.GetHitReason(context.HitStatus.HitReason)
				hitSource = string.format("Source: <font color='#FFAA33'>%s</font>", context.HitStatus.DamageSourceType)
			end
		end

		local attackerId = "Unknown"

		if attacker then
			attackerId = attacker.MyGuid
		end

		if aggregatedDamage[target.MyGuid] == nil then
			aggregatedDamage[target.MyGuid] = {
				Name = string.format("%s (%s)", GameHelpers.GetDisplayName(target), target.NetID),
				Attackers = {}
			}
		end

		if aggregatedDamage[target.MyGuid].Attackers[attackerId] == nil then
			aggregatedDamage[target.MyGuid].Attackers[attackerId] = {
				Damage = {}
			}
		end

		local attackerData = aggregatedDamage[target.MyGuid].Attackers[attackerId]
		if attackerData.Damage[hitSource] == nil then
			attackerData.Damage[hitSource] = {
				Damages = {},
				CriticalHit = false
			}
		end
		local damageData = attackerData.Damage[hitSource].Damages

		if hit.CriticalHit then
			attackerData.Damage[hitSource].CriticalHit = true
		end

		if attacker then
			attackerData.Name = string.format("%s (%s)", GameHelpers.GetDisplayName(attacker.Character), attacker.NetID)
		else
			attackerData.Name = "Unknown"
		end
		
		--damageList:AggregateSameTypeDamages()
		for k,v in pairs(damageList:ToTable()) do
			if damageData[v.DamageType] == nil then
				damageData[v.DamageType] = {Amount = 0, Hits = 0}
			end
			damageData[v.DamageType].Amount = damageData[v.DamageType].Amount + v.Amount
			damageData[v.DamageType].Hits = damageData[v.DamageType].Hits + 1
			--local damageText = GameHelpers.GetDamageText(v.DamageType, v.Amount)
			--damageData.Sources[#damageData.Sources+1] = hitSource
			--CombatLog.AddTextToAllPlayers("Combat", text.CombatLogDamage:ReplacePlaceholders(target.DisplayName, damageText, displayName, hitSource))
		end
		Timer.Cancel("LLDUMMY_AddInfoToCombatLog")
		Timer.StartOneshot("LLDUMMY_AddInfoToCombatLog", 2000, AddDamageToLog)
	end
end)

Ext.RegisterOsirisListener("RequestPickpocket", 2, "after", function (player, target)
	if IsTagged(target, "LLDUMMY_TrainingDummy") == 1 then
		StartPickpocket(player,target,1)
	end
end)