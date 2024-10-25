-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Tractor Beam Effect
-- Credits: The Aperture addon
-- ----------------------------------------------------------------------------

local normalColor = Color(64, 160, 255)
local reversedColor = Color(255, 160, 64)

function EFFECT:Init(data)
	local ent = data:GetEntity()
	local radius = data:GetRadius()
	local magnitude = data:GetMagnitude()
	local reversed = tobool(data:GetColor())
	local color = ent:GetLinearForce() < 0 and normalColor or reversedColor
	local dir = reversed and -1 or 1

	if not self.Emitter then
		self.Emitter = ParticleEmitter(ent:GetPos())
	end

	for i = 0, 1, 0.1 do
		for k = 1, 3 do
			local cossinValues = CurTime() * magnitude * dir + ((math.pi * 2) / 3) * k
			local multWidth = i * radius
			local localVec = Vector(math.cos(cossinValues) * multWidth, math.sin(cossinValues) * multWidth, 30)
			local particlePos = ent:LocalToWorld(localVec) + VectorRand() * 5

			local p = self.Emitter:Add("sprites/light_glow02_add", particlePos)
			p:SetDieTime(math.random(1, 2) * ((0 - i) / 2 + 1))
			p:SetStartAlpha(math.random(0, 50))
			p:SetEndAlpha(255)
			p:SetStartSize(math.random(10, 20))
			p:SetEndSize(0)
			p:SetVelocity(ent:GetUp() * ent:GetLinearForce() * dir + VectorRand() * 5)
			p:SetGravity(VectorRand() * 5)
			p:SetColor(color.r, color.g, color.b)
			p:SetCollide(true)
		end
	end

	self.Emitter:Finish()
end

function EFFECT:Think()
	return
end

function EFFECT:Render()
end