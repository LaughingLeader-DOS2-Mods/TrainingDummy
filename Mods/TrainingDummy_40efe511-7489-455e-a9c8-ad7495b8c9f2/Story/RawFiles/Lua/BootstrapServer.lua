Ext.Require("BootstrapShared.lua")

local ts = Classes.TranslatedString

local text = {
	CombatLogDamage = ts:CreateFromKey("LLDUMMY_CombatLog_TookDamage", "[1]: [2] from [3] ([4])")
}

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
		local displayName = ""
		if getmetatable(attacker) == "CDivinityStats_Character" then
			displayName = attacker.Character.DisplayName
		else
			displayName = attacker.Name
		end
		local damageList = Ext.NewDamageList()
		for k,v in pairs(hit.DamageList:ToTable()) do
			if v.Amount > 0 then
				damageList:Add(v.DamageType, v.Amount)
			end
		end

		local hitSource = ""
		
		if context.HitStatus then
			if not StringHelpers.IsNullOrEmpty(context.HitStatus.SkillId) then
				local skill = GetSkillEntryName(context.HitStatus.SkillId)
				hitSource = "Skill: " .. GameHelpers.GetStringKeyText(Ext.StatGetAttribute(skill, "DisplayName"), skill)
			else
				--local hitReason = GameHelpers.Hit.GetHitReason(context.HitStatus.HitReason)
				hitSource = "Source: " .. context.HitStatus.DamageSourceType
			end
		end

		damageList:AggregateSameTypeDamages()
		for k,v in pairs(damageList:ToTable()) do
			local damageText = GameHelpers.GetDamageText(v.DamageType, v.Amount)
			CombatLog.AddTextToAllPlayers("Combat", text.CombatLogDamage:ReplacePlaceholders(target.DisplayName, damageText, displayName, hitSource))
		end
	end
end)