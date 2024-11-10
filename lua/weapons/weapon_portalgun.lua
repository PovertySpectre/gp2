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

PrecacheParticleSystem("portal_projectile_stream")
PrecacheParticleSystem("portal_badsurface")
PrecacheParticleSystem("portal_success")

local glow1 = Material("particle/particle_glow_05")

PORTAL_PLACEMENT_FAILED = 0
PORTAL_PLACEMENT_SUCCESFULL = 1
PORTAL_PLACEMENT_BAD_SURFACE = 2
PORTAL_PLACEMENT_UNKNOWN_SURFACE = 3

if SERVER then
	concommand.Add("upgrade_portalgun", function( ply, cmd, args )
		ply:Give("weapon_portalgun")
		
		for _, weapon in ipairs(ply:GetWeapons()) do
			if weapon:GetClass() == "weapon_portalgun" then
				weapon:UpdatePortalGun()
			end
		end
	end )

	concommand.Add("upgrade_potatogun", function( ply, cmd, args )		
		for _, weapon in ipairs(ply:GetWeapons()) do
			if weapon:GetClass() == "weapon_portalgun" then
				weapon:UpdatePotatoGun(true)
			end
		end
	end )
else
	CreateClientConVar("gp2_portal_color1", "2 114 210", true, true, "Color for Portal 1")
	CreateClientConVar("gp2_portal_color2", "210 114 2", true, true, "Color for Portal 2")

	net.Receive(GP2.Net.SendPortalPlacementNotPortalable, function()
		local hitPos = net.ReadVector()
		local hitAngle = net.ReadAngle()
		local color = net.ReadVector()
	
		local forward, right, up = hitAngle:Forward(), hitAngle:Right(), hitAngle:Up()
	
		local particle = CreateParticleSystemNoEntity("portal_badsurface", hitPos, hitAngle)
		particle:SetControlPoint(0, hitPos)
		particle:SetControlPointOrientation(0, up, right, forward)
		particle:SetControlPoint(2, color)
	end)

	net.Receive(GP2.Net.SendPortalPlacementSuccess, function()
		local hitPos = net.ReadVector() 
		local hitAngle = net.ReadAngle()
		local color = net.ReadVector()

		hitPos = hitPos - hitAngle:Up() * 7
	
		local forward, right, up = hitAngle:Forward(), hitAngle:Right(), hitAngle:Up()
	
		local particle = CreateParticleSystemNoEntity("portal_success", hitPos, hitAngle)
		particle:SetControlPoint(0, hitPos)
		particle:SetControlPointOrientation(0, right, forward, up)
		particle:SetControlPoint(2, color)

	end)		
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
	["prop_portal"] = true,
	["prop_weighted_cube"] = true,
	["grenade_helicopter"] = true,
	["npc_portal_turret_floor"] = true,
	["prop_monster_box"] = true,
	["npc_*"] = true,
}

local function seamlessCheck(e)
	if not IsValid(e) then return end
	return !gtCheck[e:GetClass()]
end

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

	if
		not tr.Hit
		or IsValid(tr.Entity)
		or tr.HitTexture == "**studio**"
		--or bit.band(tr.DispFlags, DISPSURF_WALKABLE) ~= 0
		or bit.band(tr.SurfaceFlags, SURF_NOPORTAL) ~= 0
		or bit.band(tr.SurfaceFlags, SURF_TRANS) ~= 0
	then
		return PORTAL_PLACEMENT_BAD_SURFACE, tr
	end

	if tr.HitSky then
		return PORTAL_PLACEMENT_UNKNOWN_SURFACE, tr
	end

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
			filter = ents.GetAll(),
		})

		if extr.Hit then
			tr.HitPos = tr.HitPos + angTab[i] * (1 - extr.Fraction)
		end
	end

	pos:Set(tr.HitNormal)
	pos:Mul(mul)
	pos:Add(tr.HitPos)

	return PORTAL_PLACEMENT_SUCCESFULL, tr, pos, ang
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
    self:NetworkVar("Entity", "LastPlacedPortal")

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

function SWEP:Holster(arguments)
	if IsValid(self.TopLightFirstPerson) then
		self.TopLightFirstPerson:StopEmission()
		self.TopLightFirstPerson = nil
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

    self:PlacePortal(PORTAL_TYPE_FIRST, self:GetOwner())

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

    self:PlacePortal(PORTAL_TYPE_SECOND, self:GetOwner())

    self:SetNextPrimaryFire(CurTime() + 0.5)
	self:SetNextSecondaryFire(CurTime() + 0.5)
end

function SWEP:Reload()
end

function SWEP:ClearSpawn()
end

function SWEP:PlacePortal(type, owner)	
	local r, g, b = 255, 255, 255

	if IsValid(owner) and owner:IsPlayer() then
		local colorConvar = owner:GetInfo("gp2_portal_color" .. type + 1)
		r, g, b = unpack((colorConvar or "255 255 255"):Split(" "))
	end
	
	local portal = ents.Create("prop_portal")
	if not IsValid(portal) then return end

	portal:SetPlacedByMap(false)
	portal:SetPortalColor(tonumber(r or 255), tonumber(g or 255), tonumber(b or 255))
	portal:SetType(type or 0)
	portal:SetLinkageGroup(self:GetLinkageGroup())
	local placementStatus, traceResult, pos, ang = setPortalPlacement(self:GetOwner(), portal)
	
	--local effectData = EffectData()
	--effectData:SetNormal(Vector(r, g, b)) -- color
	--effectData:SetOrigin(traceResult.StartPos)
	--effectData:SetStart(traceResult.HitPos)
	--effectData:SetEntity(owner)

	--util.Effect("portal_blast", effectData)

	if placementStatus == PORTAL_PLACEMENT_BAD_SURFACE then
		net.Start(GP2.Net.SendPortalPlacementNotPortalable)
			net.WriteVector(traceResult.HitPos)
			net.WriteAngle(traceResult.HitNormal:Angle())
			net.WriteVector(portal:GetColorVector())
		net.Broadcast()
		
		EmitSound("Portal.fizzle_invalid_surface", traceResult.HitPos, self:EntIndex(), CHAN_AUTO, 1, 60)
		return
	elseif placementStatus == PORTAL_PLACEMENT_UNKNOWN_SURFACE then
		return
	end
	
	portal:SetActivated(true)
	portal:Spawn()
	portal:SetPos(pos)
	portal:SetAngles(ang)

	--- @type Player
	local player = owner

	self:SetLastPlacedPortal(portal)

	net.Start(GP2.Net.SendPortalPlacementSuccess)
		net.WriteVector(portal:GetPos())
		net.WriteAngle(portal:GetAngles())
		net.WriteVector(portal:GetColorVector())
	net.Broadcast()
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
		self:SetIsPotatoGun(into)

		self:SetNextPrimaryFire(CurTime() + 3.5)
		self:SetNextSecondaryFire(CurTime() + 3.5)

		timer.Simple(2, function()
			self:SendWeaponAnim(ACT_VM_DRAW)
			if into then
				self:GetOwner():GetViewModel(0):SetBodygroup(1, 1)
				self:SetBodygroup(1, 1)
			else
				self:GetOwner():GetViewModel(0):SetBodygroup(1, 0)
				self:SetBodygroup(1, 0)
			end
		end)

		self.NextIdleTime = CurTime() + 5
    end
end

function SWEP:OnRemove()
	self:ClearPortals()
end

function SWEP:ClearPortals()
	local portal1 = PortalManager.LinkageGroups[self:GetLinkageGroup()][PORTAL_TYPE_FIRST]
	local portal2 = PortalManager.LinkageGroups[self:GetLinkageGroup()][PORTAL_TYPE_SECOND]

	if SERVER then
		if IsValid(portal1) and self:GetCanFirePortal1() then
			portal1:Fizzle()
		end
	
		if IsValid(portal2) and self:GetCanFirePortal2() then
			portal2:Fizzle()
		end	
	end

	self:SetLastPlacedPortal(NULL)
end

function SWEP:ViewModelDrawn(vm)
	if not self.TopLightFirstPersonAttachment then
		self.TopLightFirstPersonAttachment = vm:LookupAttachment("Body_light")
	end

	local owner = vm:GetOwner()

	local lastPlacedPortal = self:GetLastPlacedPortal()
	local lightColor

	if not IsValid(lastPlacedPortal) then
		lightColor = vector_origin
	else
		lightColor = lastPlacedPortal:GetColorVector()
	end
	
	if not self.TopLightColor then
		self.TopLightColor = Vector()
	end

	-- Top light particle (and beam)
	if not IsValid(self.TopLightFirstPerson) then
		self.TopLightFirstPerson = CreateParticleSystem(vm, "portalgun_top_light_firstperson", PATTACH_POINT_FOLLOW, self.TopLightFirstPersonAttachment )
		self.TopLightFirstPerson:SetIsViewModelEffect(true)
		self.TopLightFirstPerson:SetShouldDraw(false)

		-- Beam particles
		self.TopLightFirstPerson:AddControlPoint(2, owner, PATTACH_CUSTOMORIGIN)
		self.TopLightFirstPerson:AddControlPoint(3, vm, PATTACH_POINT_FOLLOW, "Beam_point1")
		self.TopLightFirstPerson:AddControlPoint(4, vm, PATTACH_POINT_FOLLOW, "Beam_point5")
	else
		self.TopLightFirstPerson:Render()

		if self.TopLightColor ~= lightColor then
			lightColor.x = lightColor.x * 0.5
			lightColor.y = lightColor.y * 0.5
			lightColor.z = lightColor.z * 0.5

			-- Set color to current portal placed
			self.TopLightFirstPerson:SetControlPoint(1, lightColor)

			self.TopLightColor = lightColor
		end
	end
end

function SWEP:DrawWorldModel(studio)
	local lastPlacedPortal = self:GetLastPlacedPortal()
	local lightColor

	if not IsValid(lastPlacedPortal) then
		lightColor = vector_origin
	else
		lightColor = lastPlacedPortal:GetColorVector()
	end

	if not self.TopLightThirdPersonAttachment then
		self.TopLightThirdPersonAttachment = self:LookupAttachment("Body_light")
	end

	if not self.TopLightColor then
		self.TopLightColor = Vector()
	end

	-- Top light particle (and beam) - world model
	if not IsValid(self.TopLightThirdPerson) then
		self.TopLightThirdPerson = CreateParticleSystem(self, "portalgun_top_light_thirdperson", PATTACH_POINT_FOLLOW, self.TopLightThirdPersonAttachment )
		self.TopLightThirdPerson:SetShouldDraw(false)

		-- Beam particles
		self.TopLightThirdPerson:AddControlPoint(2, self:GetOwner(), PATTACH_CUSTOMORIGIN)
		self.TopLightThirdPerson:AddControlPoint(3, self, PATTACH_POINT_FOLLOW, "Beam_point1")
		self.TopLightThirdPerson:AddControlPoint(4, self, PATTACH_POINT_FOLLOW, "Beam_point5")
	else
		self.TopLightThirdPerson:Render()

		-- Set color to current portal placed
		-- TODO: Make portals recolorable, since this code sucks
		self.TopLightThirdPerson:SetControlPoint(1, lightColor)
		self.TopLightThirdPerson:SetControlPoint(0, self:GetAttachment(self.TopLightThirdPersonAttachment).Pos)

		if self.TopLightColor ~= lightColor then
			lightColor.x = lightColor.x * 0.5
			lightColor.y = lightColor.y * 0.5
			lightColor.z = lightColor.z * 0.5

			-- Set color to current portal placed
			self.TopLightThirdPerson:SetControlPoint(1, lightColor)

			self.TopLightColor = lightColor
		end
	end

	self:DrawModel(studio)
end

function SWEP:Reload()
	if CLIENT then return end

	local portal1 = PortalManager.LinkageGroups[self:GetLinkageGroup()][PORTAL_TYPE_FIRST]
	local portal2 = PortalManager.LinkageGroups[self:GetLinkageGroup()][PORTAL_TYPE_SECOND]

	if not (IsValid(portal1) or IsValid(portal2)) then
		return
	end

	self:ClearPortals()

    self:SendWeaponAnim(ACT_VM_FIZZLE)
    self.NextIdleTime = CurTime() + 0.5
end