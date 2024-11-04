-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Portal gun
-- ----------------------------------------------------------------------------

AddCSLuaFile()
SWEP.Slot = 0
SWEP.SlotPos = 2
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false
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

if SERVER then
	concommand.Add("upgrade_portalgun", function( ply, cmd, args )
		ply:Give("weapon_portalgun")
		
		for _, weapon in ipairs(ply:GetWeapons()) do
			if weapon:GetClass() == "weapon_portalgun" then
				weapon:UpdatePortalGun()
			end
		end
	end )
end

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

	local tr = PortalManager.TraceLine({
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
		local extr = PortalManager.TraceLine({
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
    self:NetworkVar("Bool", "CanFirePortal1")
    self:NetworkVar("Bool", "CanFirePortal2")
    self:NetworkVar("Int", "LinkageGroup")

	if SERVER then
		self:SetCanFirePortal1(true) -- default only portal 1
	end
end

function SWEP:Deploy()
	if CLIENT then return end
	
	if not self.GotCustomLinkageGroup then
		self:SetLinkageGroup(self:GetOwner():EntIndex() - 1)
	end

    if self:GetIsPotatoGun() then
        self:SendWeaponAnim(ACT_VM_DEPLOY)
        self:GetOwner():GetViewModel(0):SetBodygroup(1, 1)
        self:SetBodygroup(1, 1)
    end
	

    return true
end

function SWEP:PrimaryAttack()
    if not SERVER then return end
	if not self:GetCanFirePortal1() then return end

    if not self:CanPrimaryAttack() then return end
    self:GetOwner():EmitSound("Weapon_Portalgun.fire_blue")

    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self:GetOwner():SetAnimation(PLAYER_ATTACK1)

    self.NextIdleTime = CurTime() + 0.5

    if IsValid(self:GetOwner()) and self:GetOwner():IsPlayer() then
        self:GetOwner():ViewPunch(Angle(math.Rand(-1, -0.5), math.Rand(-1, 1), 0))
    end

    self:PlacePortal(PORTAL_TYPE_BLUE)

    self:SetNextPrimaryFire(CurTime() + 0.5)
	self:SetNextSecondaryFire(CurTime() + 0.5)
end

function SWEP:SecondaryAttack()
    if not SERVER then return end
	if not self:GetCanFirePortal2() then return end

    if not self:CanPrimaryAttack() then return end
    self:GetOwner():EmitSound("Weapon_Portalgun.fire_red")

    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self:GetOwner():SetAnimation(PLAYER_ATTACK1)

    self.NextIdleTime = CurTime() + 0.5

    if IsValid(self:GetOwner()) and self:GetOwner():IsPlayer() then
        self:GetOwner():ViewPunch(Angle(math.Rand(-1, -0.5), math.Rand(-1, 1), 0))
    end

    self:PlacePortal(PORTAL_TYPE_ORANGE)

    self:SetNextPrimaryFire(CurTime() + 0.5)
	self:SetNextSecondaryFire(CurTime() + 0.5)
end

function SWEP:Reload()
end

function SWEP:ClearSpawn()
end

function SWEP:PlacePortal(type)
	local portal = ents.Create("prop_portal")
	if not IsValid(portal) then return end

	portal:SetType(type or 0)
	portal:SetLinkageGroup(self:GetLinkageGroup())
	portal:SetActivated(true)
	portal:Spawn()
	setPortalPlacement(self:GetOwner(), portal)
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
	function SWEP:UpdatePortalGun()
		self:SetCanFirePortal1(true)
		self:SetCanFirePortal2(true)
	end

    function SWEP:UpdatePotatoGun(into)
		self:SetCanFirePortal1(true)
		self:SetCanFirePortal2(true)

        self:SendWeaponAnim(ACT_VM_HOLSTER)

		timer.Simple(2, function()
			self:SendWeaponAnim(ACT_VM_DRAW)
			if into then
				self:GetOwner():GetViewModel(0):SetBodygroup(1, 1)
				self:SetBodygroup(1, 1)
				self:SetIsPotatoGun(true)
			else
				self:GetOwner():GetViewModel(0):SetBodygroup(1, 0)
				self:SetBodygroup(1, 0)
				self:SetIsPotatoGun(false)
			end
		end)

		self.NextIdleTime = CurTime() + 5
    end
end

function SWEP:OnRemove()
end

function SWEP:ClearPortals()
	local portal1 = PortalManager.LinkageGroups[self:GetLinkageGroup()][PORTAL_TYPE_BLUE]
	local portal2 = PortalManager.LinkageGroups[self:GetLinkageGroup()][PORTAL_TYPE_ORANGE]

	if IsValid(portal1) and self:GetCanFirePortal1() then
		portal1:Remove()
	end

	if IsValid(portal2) and self:GetCanFirePortal2() then
		portal2:Remove()
	end	
end

function SWEP:ViewModelDrawn(vm)
    vm:RemoveEffects(EF_NODRAW)
end

function SWEP:Reload()
	if CLIENT then return end

	local portal1 = PortalManager.LinkageGroups[self:GetLinkageGroup()][PORTAL_TYPE_BLUE]
	local portal2 = PortalManager.LinkageGroups[self:GetLinkageGroup()][PORTAL_TYPE_ORANGE]

	if not (IsValid(portal1) or IsValid(portal2)) then
		return
	end

	self:ClearPortals()

    self:SendWeaponAnim(ACT_VM_FIZZLE)
    self.NextIdleTime = CurTime() + 0.5
end