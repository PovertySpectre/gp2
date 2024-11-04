-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Portals
-- Original code: Mee
-- ----------------------------------------------------------------------------
AddCSLuaFile()

ENT.Type = "anim"
ENT.Spawnable    = false

function ENT:SetupDataTables()
	self:NetworkVar("Bool", "Activated")
	self:NetworkVar("Entity", "LinkedPartnerInternal")
	self:NetworkVar("Vector", "SizeInternal")
	self:NetworkVar("Int", "SidesInternal")
	self:NetworkVar("Int", "Type")
	self:NetworkVar("Int", "LinkageGroup")
	self:NetworkVar("Float", "OpenTime")
	self:NetworkVar("Float", "StaticTime")

	if SERVER then
		self:SetSize(Vector(PORTAL_HEIGHT / 2, PORTAL_WIDTH / 2, 7))
	end

	self:NetworkVarNotify("Activated", self.OnActivated)
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
	function ENT:KeyValue(k, v)
		if k == "Activated" then
			self:SetActivated(tobool(v))
		elseif k == "LinkageGroupID" then
			self:SetLinkageGroup(tonumber(v))
		elseif k == "HalfWidth" then
			local value = tonumber(v) > 0 and tonumber(v) or PORTAL_WIDTH / 2

			local size = self:GetSize()
			self:SetSize(Vector(size.x, value, 7))
		elseif k == "HalfHeight" then
			local value = tonumber(v) > 0 and tonumber(v) or PORTAL_HEIGHT / 2

			local size = self:GetSize()
			self:SetSize(Vector(value, size.y, 7))
		elseif k == "PortalTwo" then
			self:SetType(tonumber(v))
		elseif outputs[key] then
			self:StoreOutput(key, value)
		end
	end

	function ENT:AcceptInput(name, activator, caller, data)
		name = name:lower()

		if name == "setactivatedstate" then
			self:SetActivated(tobool(data))
			PortalManager.SetPortal(self:GetLinkageGroup(), self)
		elseif name == "setname" then
			self:SetName(data)
		elseif name == "fizzle" then
			self:Fizzle()
		elseif name == "setlinkagegroupid" then
			self:SetLinkageGroup(tonumber(v))
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
		--self:SetModel("models/hunter/plates/plate2x2.mdl")
		self:SetModel("models/props_hacks/portal_collision.mdl")
		local angles = self:GetAngles() + Angle(90, 0, 0)
		angles:RotateAroundAxis(angles:Up(), 180)

		
		self:SetAngles(angles)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetRenderMode(RENDERMODE_TRANSCOLOR)
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)
		self:DrawShadow(false)

		print(self:GetPos())
		print(self:GetPos() + self:GetAngles():Right() * 16)
		self:SetPos(self:GetPos() + self:GetAngles():Up() * 7.1)

		PortalManager.PortalIndex = PortalManager.PortalIndex + 1
	end
	
	PortalManager.SetPortal(self:GetLinkageGroup(), self)
	PortalManager.UpdateTraceline()
end

function ENT:OnRemove()
	PortalManager.PortalIndex = math.Max(PortalManager.PortalIndex - 1, 0)
	if SERVER and self.PORTAL_REMOVE_EXIT then
		SafeRemoveEntity(self:GetLinkedPartner())
	end

	PortalManager.UpdateTraceline()
end

if CLIENT then
	local drawMat = Material("models/dav0r/hoverball")
	local stencilHole = Material("models/portals/portal_stencil_hole")
	local dummyBlue = CreateMaterial("portalringdummy-blue", "UnlitGeneric", {
		["$basetexture"] = "models/portals/dummy-blue",
		["$nocull"] = 1
	})
	local dummyOrange = CreateMaterial("portalringdummy-orange", "UnlitGeneric", {
		["$basetexture"] = "models/portals/dummy-orange",
		["$nocull"] = 1
	})
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
		if not self:GetActivated() then return end

		debugoverlay.Text(self:GetPos(), self:GetLinkageGroup(), 0.1)

		if halo.RenderedEntity() == self then return end
		local render = render
		local cam = cam
		local size = self:GetSize()
		local renderMesh = getRenderMesh()
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
		PORTAL_OVERLAYS[portalType]:SetFloat("$portalcolorscale", 1)
		
		if IsValid(self:GetLinkedPartner()) then
			PORTAL_OVERLAYS[portalType]:SetFloat("$portalstatic", self:GetStaticAmount())
		else
			PORTAL_OVERLAYS[portalType]:SetFloat("$portalstatic", 1)
		end

		if not (PortalRendering.Rendering or not IsValid(self:GetLinkedPartner()) or not PortalManager.ShouldRender(self, EyePos(), EyeAngles(), PortalRendering.GetDrawDistance())) then
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

function ENT:UpdatePhysmesh()
	if true then return end

	self:PhysicsInit(6)
	if self:GetPhysicsObject():IsValid() then
		local finalMesh = {}
		local size = self:GetSize()
		local sides = 4
		local angleMul = 360 / sides
		local degreeOffset = (sides * 90 + (sides % 4 != 0 and 0 or 45)) * (math.pi / 180)
		for side = 1, sides do
			local sidea = math.rad(side * angleMul) + degreeOffset
			local sidex = math.sin(sidea)
			local sidey = math.cos(sidea)
			local side1 = Vector(sidex, sidey, -1)
			local side2 = Vector(sidex, sidey,  0)
			table.insert(finalMesh, side1 * size)
			table.insert(finalMesh, side2 * size)
		end
		self:PhysicsInitConvex(finalMesh)
		self:EnableCustomCollisions(true)
		self:GetPhysicsObject():EnableMotion(false)
		self:GetPhysicsObject():SetMaterial("glass")
		self:GetPhysicsObject():SetMass(250)
		self:GetPhysicsObject():SetContents(bit.bor(CONTENTS_SOLID, CONTENTS_MONSTER))
	else
		self:PhysicsDestroy()
		self:EnableCustomCollisions(false)
		print("Failure to create a portal physics mesh " .. self:EntIndex())
	end
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

function ENT:OnActivated(name, old, new)
	if SERVER then
		self:SetOpenTime(CurTime())
	end
	
	PortalManager.SetPortal(self:GetLinkageGroup(), self)
	print('PropPortal::OnActivated')
end

function ENT:SetLinkedPartner(partner)
	if partner:GetClass() ~= self:GetClass() then
		GP2.Print("partner:GetClass() ~= self:GetClass()")
		return
	end

	if not partner:GetActivated() then 
		GP2.Print("not partner:GetActivated()")
		return 
	end
	
	partner:SetStaticTime(CurTime())
	self:SetStaticTime(CurTime())
	self:SetLinkedPartnerInternal(partner)
	partner:SetLinkedPartnerInternal(self)	

	GP2.Print("Setting partner for " .. tostring(partner) .. " on portal " .. tostring(self))
end

function ENT:GetLinkedPartner()
	return self:GetLinkedPartnerInternal()
end