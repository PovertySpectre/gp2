-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Portal gun
-- ----------------------------------------------------------------------------

AddCSLuaFile()
SWEP.Slot = 0
SWEP.SlotPos = 2
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true
SWEP.Spawnable = true

SWEP.ViewModel = "models/weapons/v_portalgun.mdl"
SWEP.WorldModel = "models/weapons/w_portalgun.mdl"
SWEP.ViewModelFOV = 50
SWEP.Automatic = true

SWEP.Primary.Ammo = "None"
SWEP.Primary.Automatic = true
SWEP.Secondary.Ammo = "None"
SWEP.Secondary.Automatic = true

SWEP.AutoSwitchFrom = true
SWEP.AutoSwitchTo = true

SWEP.PrintName = "Portal Gun"
SWEP.Category = "Portal 2"

local function getSurfaceAngle(owner, norm)
	local fwd = owner:GetAimVector()
	local rgh = fwd:Cross(norm)
	fwd:Set(norm:Cross(rgh))
	return fwd:AngleEx(norm)
end

local gtCheck =
{
	["player"]          = true,
	["prop_portal"] = true
}

local function seamlessCheck(e)
	if(!IsValid(e)) then return end
	return !gtCheck[e:GetClass()]
end

-- so the size is in source units (remember we are using sine/cosine)
local function setPortalPlacement(owner, portal)
	local ang = Angle() -- The portal angle
	local siz = portal:GetSize()
	local pos = owner:GetShootPos()
	local aim = owner:GetAimVector()
	local mul = siz[3] * 1.1

	local tr = SeamlessPortals.TraceLine({
		start  = pos,
		endpos = pos + aim * 99999,
		filter = seamlessCheck,
        mask = MASK_SHOT_PORTAL
	})

	-- Align portals on 45 degree surfaces
	if math.abs(tr.HitNormal:Dot(ang:Up())) < 0.71 then
		ang:Set(tr.HitNormal:Angle())
		ang:RotateAroundAxis(ang:Right(), -90)
		ang:RotateAroundAxis(ang:Up(), 180)
	else -- Place portals on any surface and angle
		ang:Set(getSurfaceAngle(owner, tr.HitNormal))
	end

	-- Extrude portal from the ground
	local af, au = ang:Forward(), ang:Right()
	local angTab = {
		 af * siz[1],
		-af * siz[1],
		 au * siz[2],
		-au * siz[2]
	}
	for i = 1, 4 do
		local extr = SeamlessPortals.TraceLine({
			start  = tr.HitPos + tr.HitNormal,
			endpos = tr.HitPos + tr.HitNormal - angTab[i],
			filter = seamlessCheck,
		})

		if extr.Hit then
			tr.HitPos = tr.HitPos + angTab[i] * (1 - extr.Fraction)
		end
	end

	pos:Set(tr.HitNormal)
	pos:Mul(mul)
	pos:Add(tr.HitPos)

	portal:SetPos(pos)
	portal:SetAngles(ang)
	if CPPI then portal:CPPISetOwner(owner) end
end

function SWEP:Initialize()
    self:SetDeploySpeed(1)
    self:SetHoldType("shotgun")

    if SERVER then
        self.NextIdleTime = 0
    end
end

function SWEP:SetupDataTables()
    self:NetworkVar("Bool", "IsPotatoGun")
end

function SWEP:Deploy()
    if self:GetIsPotatoGun() then
        self:SendWeaponAnim(ACT_VM_DEPLOY)
        self:GetOwner():GetViewModel(0):SetBodygroup(1, 1)
        self:SetBodygroup(1, 1)
    end

    return true
end

function SWEP:PrimaryAttack()
    if not SERVER then return end

    if not self:CanPrimaryAttack() then return end
    self:GetOwner():EmitSound("Weapon_Portalgun.fire_blue")

    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self:GetOwner():SetAnimation(PLAYER_ATTACK1)

    self.NextIdleTime = CurTime() + 0.5

    if IsValid(self:GetOwner()) and self:GetOwner():IsPlayer() then
        self:GetOwner():ViewPunch(Angle(math.Rand(-1, -0.5), math.Rand(-1, 1), 0))
    end

    self:DoLink("Portal1", "Portal2", Color(64, 160, 255))

    self:SetNextPrimaryFire(CurTime() + 0.5)
	self:SetNextSecondaryFire(CurTime() + 0.5)
end

function SWEP:SecondaryAttack()
    if not SERVER then return end

    if not self:CanPrimaryAttack() then return end
    self:GetOwner():EmitSound("Weapon_Portalgun.fire_red")

    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self:GetOwner():SetAnimation(PLAYER_ATTACK1)

    self.NextIdleTime = CurTime() + 0.5

    if IsValid(self:GetOwner()) and self:GetOwner():IsPlayer() then
        self:GetOwner():ViewPunch(Angle(math.Rand(-1, -0.5), math.Rand(-1, 1), 0))
    end

    self:DoLink("Portal2", "Portal1", Color(255, 160, 64))

    self:SetNextPrimaryFire(CurTime() + 0.5)
	self:SetNextSecondaryFire(CurTime() + 0.5)
end

function SWEP:Reload()
end

function SWEP:DoSpawn(key)
	if not key then return NULL end
	local ent = self[key]
	if !ent or !ent:IsValid() then
		ent = ents.Create("prop_portal")
		if !ent or !ent:IsValid() then return NULL end
		ent:SetCreator(self:GetOwner())
		ent:Spawn()
		ent:SetSize(Vector(56, 32, 8))
		ent:SetSides(50)
		self[key] = ent
	end
	return ent
end

function SWEP:ClearSpawn(base, link)
	if base then SafeRemoveEntity(self[base]) end
	if link then SafeRemoveEntity(self[link]) end
end

function SWEP:DoLink(base, link, colr)
	local ent = self:DoSpawn(base)
	if !ent or !ent:IsValid() then self:ClearSpawn(base)
		ErrorNoHalt("Failed linking seamless portal "..base.." > "..link.."!\n"); return end
	ent:SetColor(colr)
	ent:LinkPortal(self[link])
	setPortalPlacement(self:GetOwner(), ent)
	self:SetNextPrimaryFire(CurTime() + 0.25)
end

function SWEP:Think()
    if SERVER then
        local owner = self:GetOwner()
        if not IsValid(owner) then return true end

        if owner:KeyPressed(IN_USE) then
            self:SendWeaponAnim(ACT_VM_FIZZLE)
            self.NextIdleTime = CurTime() + 0.5
        end

        if CurTime() > self.NextIdleTime and self:GetActivity() ~= ACT_VM_IDLE then
            self:SendWeaponAnim(ACT_VM_IDLE)
        end
    end

    self:NextThink(CurTime())
    return true
end

if SERVER then
    function SWEP:UpdatePotatoGun(into)
        self:SendWeaponAnim(ACT_VM_DRAW)
        self.NextIdleTime = CurTime() + 5
        if into then
            self:GetOwner():GetViewModel(0):SetBodygroup(1, 1)
            self:SetBodygroup(1, 1)
            self:SetIsPotatoGun(true)
        else
            self:GetOwner():GetViewModel(0):SetBodygroup(1, 0)
            self:SetBodygroup(1, 0)
            self:SetIsPotatoGun(false)
        end
    end
end

function SWEP:OnRemove()
	self:ClearSpawn("Portal1", "Portal2")
end

function SWEP:ViewModelDrawn(vm)
    vm:RemoveEffects(EF_NODRAW)
end

function SWEP:Reload()
	if CLIENT then return end
	self:ClearSpawn("Portal1", "Portal2")

    self:SendWeaponAnim(ACT_VM_FIZZLE)
    self.NextIdleTime = CurTime() + 0.5
end

SeamlessPortals = SeamlessPortals or {}
SeamlessPortals.SeamlessCheck = seamlessCheck
SeamlessPortals.GetSurfaceAngle = getSurfaceAngle
SeamlessPortals.SetPortalPlacement = setPortalPlacement