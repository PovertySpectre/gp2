-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Tractor Beam Emitter
-- ----------------------------------------------------------------------------

AddCSLuaFile()
ENT.Type = "anim"
ENT.AutomaticFrameAdvance = true

PrecacheParticleSystem("tractor_beam_arm")
PrecacheParticleSystem("tractor_beam_core")

function ENT:KeyValue(k, v)
    if k == "use128model" then
        self.Use128Model = tobool(v)
    elseif k == "StartEnabled" then
        self.StartEnabled = true
    elseif k == "linearForce" then
        self.StartLinearForce = tonumber(v)
    end
end

function ENT:SetupDataTables()
end

function ENT:Initialize()
    if SERVER then
        self.RotationStart = 0
        self.RotationStartTime = CurTime()
        self.RotationDuration = 0
        self.RotationTarget = 0

        self.ArmatureStart = 0
        self.ArmatureTarget = 0
        self.ArmatureDuration = 0.75
        self.ArmatureStartTime = CurTime()

        if self.Use128Model then
            self:SetModel("models/props_ingame/tractor_beam_128.mdl")
        else
            self:SetModel("models/props/tractor_beam_emitter.mdl")
        end
    
        self:PhysicsInitStatic(SOLID_VPHYSICS)
        self:ResetSequence("tractor_beam_rotation")
        self:AddEffects(EF_NOSHADOW)

        if self.StartEnabled then
            self:Enable()
        end
    end
end

function ENT:AcceptInput(name, activator, caller, data)
    name = name:lower()

    if name == "enable" then
        self:Enable()  
    elseif name == "disable" then
        self:Disable()
    elseif name == "setlinearforce" then
        self:SetLinearForce(tonumber(data))
    end
end 

if SERVER then
    function ENT:Enable()
        if not (self.Beam and IsValid(self.Beam)) then
            self.Beam = ents.Create("projected_tractor_beam_entity")
            local ang = self:GetAngles()
            self.Beam:Spawn()
            self.Beam:SetPos(self:GetPos() + ang:Forward() * 8)
            self.Beam:SetParent(self)
            self.Beam:SetRadius(self.Use128Model and 50 or 60)
            self.Beam:SetLinearForce(self.StartLinearForce)
            self.Beam:SetAngles(ang)
        end

        self.RotationStart = self:CalculateRotationPose()
        self.RotationStartTime = CurTime()
        self.RotationDuration = 0.25
        self.RotationTarget = self.StartLinearForce * 0.0083333338

        self.ArmatureStart = self:CalculateArmaturePose()
        self.ArmatureTarget = self.StartLinearForce < 0 and 0 or 1
        self.ArmatureDuration = 0.75
        self.ArmatureStartTime = CurTime()
    end

    function ENT:Disable()
        if self.Beam and IsValid(self.Beam) then
            self.Beam:Remove()
            self.Beam = nil
        end

        self.RotationStart = self:CalculateRotationPose()
        self.RotationStartTime = CurTime()
        self.RotationDuration = 1.5
        self.RotationTarget = 0.0

        self.ArmatureStart = self:CalculateArmaturePose()
        self.ArmatureTarget = 0.5
        self.ArmatureDuration = 1.5
        self.ArmatureStartTime = CurTime()
    end

    function ENT:SetLinearForce(force)
        force = force or 250
        
        if self.Beam and IsValid(self.Beam) then
            self.Beam:SetLinearForce(force)
        end

        if self.StartLinearForce ~= force then
            self.RotationStart = self:CalculateRotationPose()
            self.RotationStartTime = CurTime()
            self.RotationDuration = 0.25
            self.RotationTarget = force * 0.0083333338
    
            self.ArmatureStart = self:CalculateArmaturePose()
            self.ArmatureTarget = self.StartLinearForce < 0 and 0 or 1
            self.ArmatureDuration = 0.75
            self.ArmatureStartTime = CurTime()
        end

        self.StartLinearForce = force
    end
end

function ENT:Think()
    if SERVER then
        self:SetPoseParameter("reversal", self:CalculateArmaturePose())
        self:SetPlaybackRate(self:CalculateRotationPose())
    end
    
    self:NextThink(CurTime())
    return true
end

function ENT:OnEnabled(name, old, new)
    self.EnabledTime = CurTime()
end

function ENT:CalculateRotationPose()
    local curTime = CurTime()
    
    if curTime > (self.RotationStartTime + self.RotationDuration) then
        return self.RotationTarget
    end

    local rotationGoal = self.RotationStart
    local rotationEndTime = self.RotationStartTime + self.RotationDuration
    if self.RotationStartTime == rotationEndTime then
        if curTime < rotationEndTime then
            rotationGoal = self.RotationStart
        else
            rotationGoal = self.RotationTarget
        end
    else
        local elapsedTime = (curTime - self.RotationStartTime) / (rotationEndTime - self.RotationStartTime)
        local factor = (elapsedTime * elapsedTime)
        rotationGoal = (((factor * 3.0) - (factor * 2.0 * elapsedTime)) * (self.RotationTarget - rotationGoal)) + rotationGoal
    end

    local linearForceFactor = self.StartLinearForce * 0.0083333338

    if linearForceFactor ~= 0.0 then
        local isInBounds
        if linearForceFactor >= 0.0 then
            isInBounds = rotationGoal <= linearForceFactor
        else
            isInBounds = linearForceFactor <= rotationGoal
        end
        if not isInBounds then
            return linearForceFactor
        end
    end
    
    return rotationGoal
end

function ENT:CalculateArmaturePose()
    local curTime = CurTime()

    if curTime > (self.ArmatureStartTime + self.ArmatureDuration) then
        return self.ArmatureTarget
    end

    local armatureEndTime = self.ArmatureStartTime + self.ArmatureDuration
    local armatureGoal = self.ArmatureStart

    if self.ArmatureStartTime == armatureEndTime then
        if curTime < armatureEndTime then
            armatureGoal = self.ArmatureStart
        else
            armatureGoal = self.ArmatureTarget
        end
    else
        local elapsedTime = (curTime - self.ArmatureStartTime) / (armatureEndTime - self.ArmatureStartTime)
        armatureGoal = (((elapsedTime * elapsedTime * 3.0) - ((elapsedTime * elapsedTime * 2.0) * elapsedTime))
            * (self.ArmatureTarget - armatureGoal)) + armatureGoal
    end

    if armatureGoal < 0.0 then
        return 0.0
    elseif armatureGoal > 1.0 then
        return 1.0
    else
        return armatureGoal
    end
end