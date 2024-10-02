-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Portal gun
-- ----------------------------------------------------------------------------

AddCSLuaFile()
SWEP.Slot = 1
SWEP.SlotPos = 1
SWEP.DrawAmmo = true
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

function SWEP:Initialize()
    self:SetDeploySpeed(1)
    self:SetHoldType("shotgun")
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
end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end
    self:GetOwner():EmitSound("Weapon_Portalgun.fire_blue")

    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self:GetOwner():SetAnimation(PLAYER_ATTACK1)

    if IsValid(self:GetOwner()) and self:GetOwner():IsPlayer() then
        self:GetOwner():ViewPunch(Angle(math.Rand(-1, -0.5), math.Rand(-1, 1), 0))
    end

    self:PlacePortal(0)

    self:SetNextPrimaryFire(CurTime() + 0.5)
	self:SetNextSecondaryFire(CurTime() + 0.5)
end

function SWEP:SecondaryAttack()
    if not self:CanPrimaryAttack() then return end
    self:GetOwner():EmitSound("Weapon_Portalgun.fire_red")

    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
	self:GetOwner():SetAnimation(PLAYER_ATTACK1)

    if IsValid(self:GetOwner()) and self:GetOwner():IsPlayer() then
        self:GetOwner():ViewPunch(Angle(math.Rand(-1, -0.5), math.Rand(-1, 1), 0))
    end

    self:PlacePortal(1)

    self:SetNextPrimaryFire(CurTime() + 0.5)
	self:SetNextSecondaryFire(CurTime() + 0.5)
end

function SWEP:Reload()
end

function SWEP:PlacePortal(type)
    if self:GetOwner():IsPlayer() then
		self:GetOwner():LagCompensation( true )
	end
    
    local tr = self:GetOwner():GetEyeTrace()

    if self:GetOwner():IsPlayer() then
		self:GetOwner():LagCompensation( false )
	end
    
    local portal = ents.Create("prop_portal")

    local angles
    local normal = tr.HitNormal
    if math.abs(tr.HitNormal.z) > 0.5 then
        angles = self.Owner:EyeAngles()
        angles.p = 0
        angles.y = angles.y - 180
        angles.r = 0
    else
        angles = normal:Angle()
        angles:RotateAroundAxis(angles:Right(), -90)
    end

    portal:SetType(type)
    portal:Spawn()
    portal:SetActivated(true)
    portal:SetPos(tr.HitPos + tr.HitNormal * 0.1)  
    portal:SetAngles(angles)
end

function SWEP:Think()
    if SERVER then
        self:NextThink(CurTime())
        return true
    end
end

if SERVER then
    function SWEP:UpdatePotatoGun()
        self:SendWeaponAnim(ACT_VM_DEPLOY)
        self:SetIsPotatoGun(true)
        self:GetOwner():GetViewModel(0):SetBodygroup(1, 1)
        self:SetBodygroup(1, 1)
    end
end