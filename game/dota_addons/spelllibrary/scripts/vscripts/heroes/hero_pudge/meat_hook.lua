hookTable = hookTable or {}

--[[Author: Pizzalol
	Date: 02.01.2015.
	Upon hitting a unit it gives vision and checks if its a friendly unit or an enemy one and then pulls it back]]
function RetractMeatHook( keys )
	-- Spell
	local caster = keys.caster
	local target = keys.target
	local ability = keys.ability
	local damage = ability:GetAbilityDamage() 
	local hookSpeed = keys.speed * 0.03
	local casterLocation = caster:GetAbsOrigin()
	local targetLocation = target:GetAbsOrigin() 
	local distance = (targetLocation - casterLocation):Length2D()

	-- Modifiers
	local meat_hook_modifier = keys.meat_hook_modifier
	local vision_modifier = keys.vision_modifier
	local vision_duration = keys.vision_duration
	local dummy_modifier = keys.dummy_modifier

	-- Sound
	local sound_extend = keys.sound_extend
	local sound_retract = keys.sound_retract
	local sound_retract_stop = keys.sound_retract_stop
	StopSoundEvent(sound_extend, caster)

	-- Vision
	local vision_dummy = CreateUnitByName("npc_dummy_blank", targetLocation, false, caster, caster, caster:GetTeam())
	ability:ApplyDataDrivenModifier(caster, vision_dummy, vision_modifier, {})
	ability:ApplyDataDrivenModifier(caster, vision_dummy, dummy_modifier, {})
	Timers:CreateTimer(vision_duration, function() vision_dummy:RemoveSelf() end)

	-- Damage
	if target:GetTeam() ~= caster:GetTeam() then
		local damageTable = {}
		damageTable.attacker = caster
		damageTable.victim = target
		damageTable.damage_type = DAMAGE_TYPE_PURE
		damageTable.ability = ability
		damageTable.damage = damage

		ApplyDamage(damageTable)
	end

	-- For retracting the hook
	hookTable[caster].bHitUnit = true
	
	-- Moving the target
	Timers:CreateTimer(0, function()
		targetLocation = casterLocation + (targetLocation - casterLocation):Normalized() * (distance - hookSpeed)
		target:SetAbsOrigin(targetLocation)

		distance = (targetLocation - casterLocation):Length2D()

		if distance > 100 then
			return 0.03
		else
			-- Finished dragging the target
			FindClearSpaceForUnit(target, targetLocation, false)
			target:RemoveModifierByName(meat_hook_modifier)
			StopSoundEvent(sound_retract, caster)
			EmitSoundOn(sound_retract_stop, caster)

			-- This is to fix a visual bug when the target is very close to the caster
			Timers:CreateTimer(0.03, function() hookTable[caster].bHitUnit = false end)
		end

		end)
end

--[[Author: Pizzalol
	Date: 03.01.2015.
	Creates a dummy that moves along the hook path until it hits a unit or reaches the maximum distance
	then it retracts back to the launch position]]
function LaunchMeatHook( keys )
	local caster = keys.caster
	local ability = keys.ability
	local casterLocation = caster:GetAbsOrigin()
	local dummyLocation = casterLocation
	local dummy = CreateUnitByName("npc_dummy_blank", dummyLocation, false, caster, caster, caster:GetTeam())

	-- KV variables
	local targetPoint = keys.target_points[1]
	local hookSpeed = keys.speed * 0.03
	local dummy_modifier = keys.dummy_modifier	
	local hook_particle = keys.hook_particle
	local sound_extend = keys.sound_extend

	local travel_distance = ability:GetLevelSpecialValueFor("hook_distance", (ability:GetLevel() - 1))
	local distance_traveled = 0

	-- Hook particle
	local particle = ParticleManager:CreateParticle(hook_particle, PATTACH_RENDERORIGIN_FOLLOW, caster)
	ParticleManager:SetParticleControlEnt(particle, 0, caster, 5, "attach_attack1", casterLocation, false)
	ParticleManager:SetParticleControlEnt(particle, 6, dummy, 5, "attach_hitloc", dummyLocation, false)

	-- Setting up the hook dummy
	dummy:AddNewModifier(caster, nil, "modifier_phased", {})
	ability:ApplyDataDrivenModifier(caster, dummy, dummy_modifier, {})
	dummyLocation = dummyLocation + Vector(0,0,125) 

	local direction = (targetPoint - casterLocation):Normalized()
	dummy:SetForwardVector(direction)	

	-- Setting up the extend/retract decision
	hookTable[caster] = hookTable[caster] or {}
	hookTable[caster].bHitUnit = false

	-- Extending the hook dummy
	Timers:CreateTimer(0.03, function()
		dummyLocation = dummyLocation + direction * hookSpeed
		dummy:SetAbsOrigin(dummyLocation)
		distance_traveled = distance_traveled + hookSpeed

		if distance_traveled < travel_distance and not hookTable[caster].bHitUnit then
			return 0.03
		else
			-- Retract the hook dummy
			Timers:CreateTimer(0,function()
				distance_traveled = distance_traveled - hookSpeed
				dummyLocation = casterLocation + Vector(0,0,125) + direction * distance_traveled
				dummy:SetAbsOrigin(dummyLocation)

				if distance_traveled > 100 then
					return 0.03
				else
					StopSoundEvent(sound_extend, caster)
					ParticleManager:DestroyParticle(particle, true)
					dummy:RemoveSelf()

				end
			end)
		end
	end)
end