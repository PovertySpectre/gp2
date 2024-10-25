-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Player's movement
-- ----------------------------------------------------------------------------

GP2.GameMovement = {}
local playersInTB = {}

function GP2.GameMovement.PlayerEnteredToTractorBeam(ply, beam)
    playersInTB[ply] = beam
end

function GP2.GameMovement.PlayerExitedFromTractorBeam(ply, beam)
    playersInTB[ply] = nil
end

local function TractorBeamMovement(ply, mv)
    local beam = playersInTB[ply]

    if IsValid(beam) then
        ply:SetGroundEntity(NULL)

        local plyPos = ply:GetPos()
        local plyAng = ply:GetAngles()
        local centerPos = beam:WorldSpaceCenter()
        local angles = beam:GetAngles()

        local toCenter = centerPos - plyPos
        local sidewayForce = angles:Right() * toCenter:Dot(angles:Right()) + angles:Up() * toCenter:Dot(angles:Up())
        local baseForce = (beam.LinearForce or 0) * 0.5
        local forwardForce = angles:Forward() * baseForce

        local totalForce = forwardForce + sidewayForce

        if bit.band(mv:GetButtons(), IN_FORWARD) ~= 0 then
            totalForce = totalForce + plyAng:Forward() * ply:GetWalkSpeed()
        elseif bit.band(mv:GetButtons(), IN_BACK) ~= 0 then
            totalForce = totalForce - plyAng:Forward() * ply:GetWalkSpeed()
        elseif bit.band(mv:GetButtons(), IN_MOVELEFT) ~= 0 then
            totalForce = totalForce - plyAng:Right() * ply:GetWalkSpeed()
        elseif bit.band(mv:GetButtons(), IN_MOVERIGHT) ~= 0 then
            totalForce = totalForce + plyAng:Right() * ply:GetWalkSpeed()
        end

        mv:SetVelocity(totalForce)
    end
end

hook.Add("Move", "GP2::Move", function(ply, mv)
    TractorBeamMovement(ply, mv)
end)