-- Seamless portals addon by Mee
-- You may use this code as a reference for your own projects, but please do not publish this addon as your own.

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category     = "Seamless Portals"
ENT.PrintName    = "Seamless Portal"
ENT.Author       = "Mee"
ENT.Purpose      = ""
ENT.Instructions = ""
ENT.Spawnable    = true

local gbSvFlag = bit.bor(FCVAR_ARCHIVE)

function ENT:SetupDataTables()
	self:NetworkVar("Entity", 0, "ExitPortal")
	self:NetworkVar("Vector", 0, "SizeInternal")
	self:NetworkVar("Bool", 0, "DisableBackface")
	self:NetworkVar("Int", 0, "SidesInternal")
	self:NetworkVar("Int", "Type")
	self:NetworkVar("Float", "OpenTime")
	self:NetworkVar("Float", "StaticTime")

	if self:GetSidesInternal() < 1 then
		self:SetSidesInternal(4)
	end
end

function ENT:LinkPortal(ent)
	if !IsValid(ent) then return end
	self:SetExitPortal(ent)
	ent:SetExitPortal(self)
end

function ENT:UnlinkPortal()
	local exitPortal = self:GetExitPortal()
	if IsValid(exitPortal) then
		exitPortal:SetExitPortal(nil)
	end
	self:SetExitPortal(nil)
end

function ENT:SetSides(sides)
	local shouldUpdatePhysmesh = self:GetSidesInternal() != sides
	self:SetSidesInternal(math.Clamp(sides, 3, 100))
	if shouldUpdatePhysmesh then self:UpdatePhysmesh() end
end

-- custom size for portal
function ENT:SetSize(n)
	self:SetSizeInternal(n)
	self:UpdatePhysmesh(n)
end

function ENT:SetRemoveExit(bool)
	self.PORTAL_REMOVE_EXIT = bool
end

function ENT:GetRemoveExit(bool)
	return self.PORTAL_REMOVE_EXIT
end

function ENT:GetSize()
	return self:GetSizeInternal()
end

local outputs = {
	["OnTeleportFrom"] = true,
	["OnTeleportTo"]   = true
}

if SERVER then
	function ENT:KeyValue(key, value)
		if key == "link" then
			timer.Simple(0, function() self:SetExitPortal(ents.FindByName(value)[1]) end)
		elseif key == "backface" then
			self:SetDisableBackface(value == "1")
		elseif key == "size" then
			local size = string.Split(value, " ")
			self:SetSizeInternal(Vector(size[2] * 0.5, size[1] * 0.5, size[3]))
		elseif outputs[key] then
			self:StoreOutput(key, value)
		end
	end

	function ENT:AcceptInput(input, activator, caller, data)
		if input == "Link" then
			self:SetExitPortal(ents.FindByName(data)[1])
		end
	end
end

local function incrementPortal(ent)
	if CLIENT then	-- singleplayer is weird... dont generate a physmesh if its singleplayer
		if ent.UpdatePhysmesh then
			ent:UpdatePhysmesh()
		else
			-- takes a minute to try and find the portal, if it cant, oh well...
			timer.Create("seamless_portal_init" .. PortalManager.PortalIndex, 1, 60, function()
				if !ent or !ent:IsValid() or !ent.UpdatePhysmesh then return end

				ent:UpdatePhysmesh()
				timer.Remove("seamless_portal_init" .. PortalManager.PortalIndex)
			end)
		end

		local size = ent:GetSize()
		ent:SetRenderBounds(-size, size)
	end
	PortalManager.PortalIndex = PortalManager.PortalIndex + 1
end

function ENT:Initialize()
	if SERVER then
		self:SetOpenTime(CurTime())
		self:SetModel("models/hunter/plates/plate2x2.mdl")
		self:SetAngles(self:GetAngles() + Angle(90, 0, 0))
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:PhysWake()
		self:SetRenderMode(RENDERMODE_TRANSCOLOR)
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)
		self:DrawShadow(false)

		self:SetSize(Vector(PORTAL_HEIGHT / 2, PORTAL_WIDTH / 2, 7))

		PortalManager.PortalIndex = PortalManager.PortalIndex + 1
	end
	
	PortalManager.UpdateTraceline()
end

function ENT:SpawnFunction(ply, tr)
	local portal1 = ents.Create("prop_portal")
	portal1:SetPos(tr.HitPos + tr.HitNormal * 160)
	portal1:SetCreator(ply)
	portal1:Spawn()

	local portal2 = ents.Create("prop_portal")
	portal2:SetPos(tr.HitPos + tr.HitNormal * 50)
	portal2:SetCreator(ply)
	portal2:Spawn()

	if CPPI then portal2:CPPISetOwner(ply) end

	portal1:LinkPortal(portal2)
	portal2:LinkPortal(portal1)

	portal1:SetRemoveExit(true)
	portal2:SetRemoveExit(true)

	return portal1
end

function ENT:OnRemove()
	PortalManager.PortalIndex = math.Max(PortalManager.PortalIndex - 1, 0)
	if SERVER and self.PORTAL_REMOVE_EXIT then
		SafeRemoveEntity(self:GetExitPortal())
	end

	PortalManager.UpdateTraceline()
end

-- theres gonna be a bunch of magic numbers in this rendering code, since garry decided a hunterplate should be 47.9 rendering units wide and 51 physical units
if CLIENT then
	local drawMat = Material("models/dav0r/hoverball")
	local stencilHole = Material("models/portals/portal_stencil_hole")
	local PORTAL_OVERLAYS = {
		Material("models/portals/portalstaticoverlay_1"),
		Material("models/portals/portalstaticoverlay_2"),
	}

	local function getRenderMesh()
		if not PortalRendering.PortalMeshes[4] then
			PortalRendering.PortalMeshes[4] = {nil, Mesh()}

			local invMeshTable = {}

			local corners = {
				Vector(-1, -1, -1),
				Vector(1, -1, -1),
				Vector(1, 1, -1),
				Vector(-1, 1, -1)
			}

			local uv = {
				Vector(0, 1),
				Vector(1, 1),
				Vector(1, 0),
				Vector(0, 0)
			}

			for i = 1, 4 do	  
				table.insert(invMeshTable, {pos = corners[i], u = uv[i].y, v = 1 - uv[i].x})
				table.insert(invMeshTable, {pos = Vector(0, 0, -1), u = 0.5, v = 0.5})
				table.insert(invMeshTable, {pos = corners[i % 4 + 1], u = uv[i % 4 + 1].y, v = 1 - uv[i % 4 + 1].x})
			end

			PortalRendering.PortalMeshes[4][2]:BuildFromTriangles(invMeshTable)
		end

		return PortalRendering.PortalMeshes[4][2]
	end
	
	function ENT:Draw()
		if halo.RenderedEntity() == self then return end
		local render = render
		local cam = cam
		local size = self:GetSize()
		local renderMesh = getRenderMesh()
		-- render the outside frame
		local backface = self:GetDisableBackface()
		if self.RENDER_MATRIX:GetTranslation() != self:GetPos() or self.RENDER_MATRIX:GetScale() != size then
			self.RENDER_MATRIX:Identity()
			self.RENDER_MATRIX:SetTranslation(self:GetPos())
			self.RENDER_MATRIX:SetAngles(self:GetAngles())
			self.RENDER_MATRIX:SetScale(size * 0.999)
			
			if self.RENDER_MATRIX_LOCAL then
				self.RENDER_MATRIX_LOCAL:Identity()
			else
				self.RENDER_MATRIX_LOCAL = Matrix()
			end
			self.RENDER_MATRIX_LOCAL:SetScale(size)
			
			self:SetRenderBounds(-size, size)

			size[3] = 0
		end

		-- No PortalOpenAmount proxy
		-- because it uses mesh rather entity's model
		local portalType = self:GetType() + 1
		stencilHole:SetFloat("$portalopenamount", self:GetOpenAmount())
		PORTAL_OVERLAYS[portalType]:SetFloat("$portalopenamount", self:GetOpenAmount())
		
		if IsValid(self:GetExitPortal()) then
			PORTAL_OVERLAYS[portalType]:SetFloat("$portalstatic", self:GetStaticAmount())
		else
			PORTAL_OVERLAYS[portalType]:SetFloat("$portalstatic", 1)
		end

		if not (PortalRendering.Rendering or not IsValid(self:GetExitPortal()) or not PortalManager.ShouldRender(self, EyePos(), EyeAngles(), PortalRendering.GetDrawDistance())) then
			-- do cursed stencil stuff
			render.ClearStencil()
			render.SetStencilEnable(true)
			render.SetStencilWriteMask(1)
			render.SetStencilTestMask(1)
			render.SetStencilReferenceValue(1)
			render.SetStencilFailOperation(STENCIL_KEEP)
			render.SetStencilZFailOperation(STENCIL_KEEP)
			render.SetStencilPassOperation(STENCIL_REPLACE)
			render.SetStencilCompareFunction(STENCIL_ALWAYS)
			render.SetMaterial(stencilHole)

			-- draw inside of portal
			cam.PushModelMatrix(self.RENDER_MATRIX)
				renderMesh:Draw()
			cam.PopModelMatrix()

			-- draw the actual portal texture
			local portalmat = PortalRendering.PortalMaterials
			render.SetMaterial(portalmat[self.PORTAL_RT_NUMBER or 1])
			render.SetStencilCompareFunction(STENCIL_EQUAL)
				render.DrawScreenQuadEx(0, 0, ScrW(), ScrH())
			render.SetStencilEnable(false)

			print('lol')
		end

		-- Render portal border
		render.SetMaterial(PORTAL_OVERLAYS[portalType])
		cam.PushModelMatrix(self.RENDER_MATRIX)
			renderMesh:Draw()
		cam.PopModelMatrix()
	end

	-- hacky bullet fix
	if game.SinglePlayer() then
		function ENT:TestCollision(startpos, delta, isbox, extents, mask)
			if bit.band(mask, CONTENTS_GRATE) != 0 then return true end
		end
	end
end

-- scale the physmesh
function ENT:UpdatePhysmesh()

end

function ENT:UpdateTransmitState()
	return TRANSMIT_PVS
end

function ENT:OnPhysgunPickup(ply, ent)
    return false
end

function ENT:OnPhysgunDrop(ply, ent)
    return false
end

function ENT:GetOpenAmount()
	local currentTime = CurTime()
	local elapsedTime = currentTime - self:GetOpenTime()
	elapsedTime = math.min(elapsedTime, PORTAL_OPEN_DURATION)
	local progress = elapsedTime / PORTAL_OPEN_DURATION
	return progress
end

function ENT:GetStaticAmount()
	local currentTime = CurTime()
	local elapsedTime = currentTime - self:GetStaticTime()
	elapsedTime = math.min(elapsedTime, PORTAL_STATIC_DURATION)
	local progress = elapsedTime / PORTAL_STATIC_DURATION
	return 1 - progress
end

-- set physmesh pos on client
if CLIENT then
	-- this code creates the rendertargets to be used for the portals
	for i = 1, PortalRendering.MaxRTs do
		PortalRendering.PortalRTs[i] = GetRenderTarget("_rt_portal" .. i, ScrW(), ScrH())
		PortalRendering.PortalMaterials[i] = CreateMaterial("PortalMaterial" .. i, "GMODScreenspace", {
			["$basetexture"] = PortalRendering.PortalRTs[i]:GetName(),
			["$model"] = "1"
		})
	end

	-- Create square mesh used for the portals
	PortalRendering.PortalMeshes = {}

	function ENT:Think()
		local phys = self:GetPhysicsObject()
		if phys:IsValid() then
			phys:EnableMotion(false)
			phys:SetMaterial("glass")
			phys:SetPos(self:GetPos())
			phys:SetAngles(self:GetAngles())
		elseif self:GetVelocity() == Vector() then
			self:UpdatePhysmesh()
		end
	end

	hook.Add("NetworkEntityCreated", "seamless_portal_init", function(ent)
		if ent:GetClass() == "prop_portal" then
			ent.RENDER_MATRIX = Matrix()
			timer.Simple(0, function()
				incrementPortal(ent)
			end)
		end
	end)
end
