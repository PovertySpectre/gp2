-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Trigger Tractor beams
-- ----------------------------------------------------------------------------

ENT.Type = "brush"
ENT.Base = "base_brush"
ENT.TouchingEnts = {}
ENT.TractorBeam = NULL

local TRACTOR_BEAM_VALID_ENTS = {
    --["player"] = true, -- player movement handled by Move hook
    ["prop_physics"] = true,
    ["func_physbox"] = true,
    ["prop_monster_box"] = true,
    ["prop_weighted_cube"] = true,
    ["npc_personality_core"] = true,
    ["npc_portal_turret_floor"] = true,
    ["prop_ragdoll"] = true,
    ["prop_exploding_futbol"] = true,
}

function ENT:Initialize()
    self:SetSolid(SOLID_BBOX)
    self:SetTrigger(true)
end

function ENT:SetTractorBeam(tbeam)
    self.TractorBeam = tbeam
end

function ENT:Think()
    if not self.TractorBeam or not IsValid(self.TractorBeam) then
        self:Remove()
        return
    end

    local mins, maxs = self:GetCollisionBounds()

    local fwd = self:GetAngles():Forward()
    local right = self:GetAngles():Right()
    self.DistanceToHit = math.abs((maxs - mins):Dot(right))

    for i = #self.TouchingEnts, 1, -1 do
        local ent = self.TouchingEnts[i]

        if not IsValid(ent) then
            table.remove(self.TouchingEnts, i)

            if ent:IsPlayer() then
                GP2.GameMovement.PlayerExitedFromTractorBeam(ent, self)
            end
        else
            self:ProcessEntity(ent) 
        end
    end

    self:NextThink(CurTime())
    return true
end

function ENT:StartTouch(ent)
    if IsValid(self.TractorBeam) then
        
        if (TRACTOR_BEAM_VALID_ENTS[ent:GetClass()]) then
            table.insert(self.TouchingEnts, ent)
        elseif ent:IsPlayer() then
            GP2.GameMovement.PlayerEnteredToTractorBeam(ent, self)
        end
    end
end

function ENT:ProcessEntity(ent)
    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then return end

    local entPos = ent:WorldSpaceCenter()
    local centerPos = self:WorldSpaceCenter()
    local angles = self:GetAngles()

    local toCenter = centerPos - entPos
    local sidewayForce = angles:Right() * toCenter:Dot(angles:Right()) + angles:Up() * toCenter:Dot(angles:Up())
    local baseForce = self.LinearForce or 0
    local forwardForce = angles:Forward() * baseForce

    local mins, maxs = ent:GetCollisionBounds()
    local boxSize = (maxs - mins):Length()

    local trMovementFrontFace = entPos + angles:Forward() * (boxSize / 2)

    local tr = util.QuickTrace(trMovementFrontFace, angles:Forward() * boxSize, {self, ent})

    local totalForce

    if tr.Fraction < 0.1 then 
        totalForce = sidewayForce
    else
        totalForce = (forwardForce + sidewayForce) * tr.Fraction
        phys:AddAngleVelocity((forwardForce + sidewayForce) * tr.Fraction / phys:GetMass())
    end

    phys:Wake()
    phys:SetVelocity(totalForce)
    phys:SetAngleVelocity(totalForce)
end


function ENT:EndTouch(ent)
    table.RemoveByValue(self.TouchingEnts, ent)

    if ent:IsPlayer() then
        GP2.GameMovement.PlayerExitedFromTractorBeam(ent, self)
    end
end