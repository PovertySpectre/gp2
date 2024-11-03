-- detours so stuff go through portals
AddCSLuaFile()

-- bullet detour
hook.Add("EntityFireBullets", "seamless_portal_detour_bullet", function(entity, data)
	if PortalManager.PortalIndex < 1 then return end
	local tr = PortalManager.TraceLine({start = data.Src, endpos = data.Src + data.Dir * data.Distance, filter = entity})
	local hitPortal = tr.Entity
	if !hitPortal:IsValid() then return end
	if hitPortal:GetClass() != "prop_portal" then return end
	local exitportal = hitPortal:GetExitPortal()
	if !IsValid(exitportal) then return end
	if (tr.HitPos - hitPortal:GetPos()):Dot(hitPortal:GetUp()) > 0 then
		local newPos, newAng = PortalManager.TransformPortal(hitPortal, exitportal, tr.HitPos, data.Dir:Angle())

		--ignoreentity doesnt seem to work for some reason
		data.IgnoreEntity = exitportal
		data.Src = newPos
		data.Dir = newAng:Forward()
		data.Tracer = 0

		return true
	end
end)

-- effect detour (Thanks to WasabiThumb)
local tabEffectClass = {["phys_unfreeze"] = true, ["phys_freeze"] = true}
local oldUtilEffect = util.Effect
local function effect(name, b, c, d)
	 if PortalManager.PortalIndex > 0 and
	    name and tabEffectClass[name] then return end
	oldUtilEffect(name, b, c, d)
end
util.Effect = effect

if SERVER then return end

-- sound detour
hook.Add("EntityEmitSound", "seamless_portals_detour_sound", function(t)
	if !PortalManager or PortalManager.PortalIndex < 1 then return end
	for k, v in ipairs(ents.FindByClass("prop_portal")) do
		local exitportal = v:GetExitPortal()
		if !v.ExitPortal or !exitportal or !exitportal:IsValid() or !exitportal.GetExitSize then continue end
		if !t.Pos or !t.Entity or t.Entity == NULL then continue end
		if t.Pos:DistToSqr(v:GetPos()) < 50000 * exitportal:GetExitSize()[1] and (t.Pos - v:GetPos()):Dot(v:GetUp()) > 0 then
			local newPos = PortalManager.TransformPortal(v, exitportal, t.Pos, Angle())
			local oldPos = t.Entity:GetPos() or Vector()
			t.Entity:SetPos(newPos)
			EmitSound(t.SoundName, newPos, t.Entity:EntIndex(), t.Channel, t.Volume, t.SoundLevel, t.Flags, t.Pitch, t.DSP)
			t.Entity:SetPos(oldPos)
		end
	end
end)
