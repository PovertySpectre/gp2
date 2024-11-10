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
	self:NetworkVar("Bool", "PlacedByMap")
	self:NetworkVar("Entity", "LinkedPartnerInternal")
	self:NetworkVar("Vector", "SizeInternal")
	self:NetworkVar("Int", "SidesInternal")
	self:NetworkVar("Int", "Type")
	self:NetworkVar("Int", "LinkageGroup")
	self:NetworkVar("Float", "OpenTime")
	self:NetworkVar("Float", "StaticTime")
	self:NetworkVar("Vector", "ColorVectorInternal")
	self:NetworkVar("Vector", "ColorVector01Internal")

	if SERVER then
		self:SetSize(Vector(PORTAL_HEIGHT / 2, PORTAL_WIDTH / 2, 7))
		self:SetColorVectorInternal(Vector(255,255,255))
		self:SetPlacedByMap(true)
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
	["OnEntityTeleportFromMe"] = true,
	["OnEntityTeleportToMe"] = true,
	["OnPlayerTeleportFromMe"] = true,
	["OnPlayerTeleportToMe"] = true,
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

		self:SetColor()
		self:SetAngles(angles)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_NONE)
		self:SetRenderMode(RENDERMODE_TRANSCOLOR)
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)
		self:DrawShadow(false)

		self:SetPos(self:GetPos() + self:GetAngles():Up() * 7.1)

		PortalManager.PortalIndex = PortalManager.PortalIndex + 1
	end
	
	-- Override portal in LinkageGroup
	PortalManager.SetPortal(self:GetLinkageGroup(), self)
	PortalManager.UpdateTraceline()
end

function ENT:OnRemove()
	PortalManager.PortalIndex = math.Max(PortalManager.PortalIndex - 1, 0)
	if SERVER and self.PORTAL_REMOVE_EXIT then
		SafeRemoveEntity(self:GetLinkedPartner())
	end
	
	if CLIENT and IsValid(self.RingParticle) then
		self.RingParticle:StopEmissionAndDestroyImmediately()
	end

	PortalManager.UpdateTraceline()
end

if CLIENT then
	local stencilHole = Material("models/portals/portal_stencil_hole")
	local ghostTexture = CreateMaterial("portal-ghosting", "UnlitGeneric", {
		["$basetexture"] = "models/portals/dummy-gray",
		["$nocull"] = 1,
		["$model"] = 1,
		["$alpha"] = 0.25,
		["$translucent"] = 1,
		["$vertexalpha"] = 1,
		["$vertexcolor"] = 1,
	})

	net.Receive(GP2.Net.SendPortalClose, function()
		local pos = net.ReadVector()
		local angle = net.ReadAngle()
		local color = net.ReadVector()

		local forward, right, up = angle:Forward(), angle:Right(), angle:Up()
	
		local particle = CreateParticleSystemNoEntity("portal_close", pos, angle)
		particle:SetControlPoint(0, pos)
		particle:SetControlPointOrientation(0, right, forward, up)
		particle:SetControlPoint(2, color)
	end)
	

	local function getRenderMesh()
		if not PortalRendering.PortalMeshes[4] then
			PortalRendering.PortalMeshes[4] = { Mesh(), Mesh() }

			local invMeshTable = {}
			local meshTable = {}

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
				table.insert(meshTable, { pos = corners[i % 4 + 1], u = uv[i % 4 + 1].y, v = 1 - uv[i % 4 + 1].x })
				table.insert(meshTable, { pos = Vector(0, 0, -1), u = 0.5, v = 0.5 })
				table.insert(meshTable, { pos = corners[i], u = uv[i].y, v = 1 - uv[i].x })
			end

			for i = 1, 4 do
				table.insert(invMeshTable, { pos = corners[i], u = uv[i].y, v = 1 - uv[i].x })
				table.insert(invMeshTable, { pos = Vector(0, 0, -1), u = 0.5, v = 0.5 })
				table.insert(invMeshTable, { pos = corners[i % 4 + 1], u = uv[i % 4 + 1].y, v = 1 - uv[i % 4 + 1].x })
			end

			PortalRendering.PortalMeshes[4][1]:BuildFromTriangles(meshTable)
			PortalRendering.PortalMeshes[4][2]:BuildFromTriangles(invMeshTable)
		end

		return PortalRendering.PortalMeshes[4][2], PortalRendering.PortalMeshes[4][1]
	end
	
	
	function ENT:Draw()
		if not self:GetActivated() then return end

		if not self.RENDER_MATRIX then
			self.RENDER_MATRIX = Matrix()
		end

		debugoverlay.Text(self:GetPos(), self:GetLinkageGroup(), 0.1)

		if halo.RenderedEntity() == self then return end
		local render = render
		local cam = cam
		local size = self:GetSize()
		local renderMesh = getRenderMesh()
		if self.RENDER_MATRIX:GetTranslation() ~= self:GetPos() or self.RENDER_MATRIX:GetScale() != size then
			self.RENDER_MATRIX:Identity()
			self.RENDER_MATRIX:SetTranslation(self:GetPos())
			self.RENDER_MATRIX:SetAngles(self:GetAngles())
			self.RENDER_MATRIX:SetScale(size * 0.999)
			
			self:SetRenderBounds(-size, size)

			size[3] = 0
		end

		-- Try to build gradient texture for current color
		-- to override color - without shaders :( 
		local portalOverlay = PortalRendering.ValidateAndSetRingRT(self)

		-- No PortalOpenAmount proxy
		-- because it uses mesh rather entity's model
		stencilHole:SetFloat("$portalopenamount", self:GetOpenAmount())
		portalOverlay:SetFloat("$portalopenamount", self:GetOpenAmount())
		portalOverlay:SetFloat("$time", CurTime())
		
		if not PortalRendering.Rendering and IsValid(self:GetLinkedPartner()) then
			portalOverlay:SetFloat("$portalstatic", self:GetStaticAmount())
		else
			portalOverlay:SetFloat("$portalstatic", 1)
		end

		--
		-- Render portal view:
		--	- only when it's not inside portal view
		--	- there's linked partner
		--	- should render (in FOV, distance is less than threshold)
		--
		if not (PortalRendering.Rendering or not IsValid(self:GetLinkedPartner()) or not PortalManager.ShouldRender(self, EyePos(), EyeAngles(), PortalRendering.GetDrawDistance())) then
			render.ClearStencil()
			render.SetStencilEnable(true)
			render.SetStencilWriteMask(255)
			render.SetStencilTestMask(255)
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

		--
		-- Render border material
		-- previously I set open/static values for it
		-- Each material is local to entity
		--
		render.SetMaterial(portalOverlay)
		cam.PushModelMatrix(self.RENDER_MATRIX)
			renderMesh:Draw()
		cam.PopModelMatrix()
		
		-- 
		-- Render the ring particle only not in portal view
		-- after everything
		--
		if not PortalRendering.Rendering and IsValid(self.RingParticle) then
			self.RingParticle:Render()
		end
	end

	function ENT:DrawGhost()
		local renderMesh, renderMesh2 = getRenderMesh()
		local portalType = self:GetType()

		--
		-- Render portal ghosting
		-- Uses stencils too
		-- rendered from render.lua in PostDrawOpaqueRenderables
		--
		if not PortalRendering.Rendering and PortalRendering.GetShowGhosting() then
			render.SetStencilWriteMask( 255 )
			render.SetStencilTestMask( 255 )
			render.SetStencilReferenceValue( 1 )
			render.SetStencilCompareFunction( STENCIL_ALWAYS )
			render.SetStencilPassOperation( STENCIL_KEEP )
			render.SetStencilFailOperation( STENCIL_KEEP )
			render.SetStencilZFailOperation( STENCIL_KEEP )
			render.ClearStencil()

			render.SetStencilEnable( true )

			render.SetStencilReferenceValue( 1 )
			render.SetStencilCompareFunction( STENCIL_ALWAYS )
			render.SetStencilZFailOperation( STENCIL_REPLACE )

			render.SetColorMaterial()
			render.OverrideColorWriteEnable(true, false)
			cam.PushModelMatrix(self.RENDER_MATRIX)
				renderMesh:Draw()
				renderMesh2:Draw()
			cam.PopModelMatrix()    
			render.OverrideColorWriteEnable(false, false)

			render.SetStencilCompareFunction(STENCIL_EQUAL)

			ghostTexture:SetVector("$color", self:GetColorVector01Internal())

			render.SetMaterial(ghostTexture)
			cam.IgnoreZ(true)
			cam.PushModelMatrix(self.RENDER_MATRIX)
				renderMesh:Draw()
				renderMesh2:Draw()
			cam.PopModelMatrix() 
			cam.IgnoreZ(false)
			render.SetBlend(1)

			render.SetStencilEnable(false)
		end		
	end

	-- hacky bullet fix
	if game.SinglePlayer() then
		function ENT:TestCollision(startpos, delta, isbox, extents, mask)
			if bit.band(mask, CONTENTS_GRATE) ~= 0 then return true end
		end
	end
end

function ENT:UpdatePhysmesh()
    self:PhysicsInit(SOLID_VPHYSICS)
    local phys = self:GetPhysicsObject()

    if IsValid(phys) then
        local size = self:GetSize() * 0.75
        local finalMesh = {
            -- Bottom face (z = -size.z)
            Vector(-size.x, -size.y, -size.z), -- Bottom Back Left
            Vector(size.x, -size.y, -size.z),  -- Bottom Back Right
            Vector(size.x, size.y, -size.z),   -- Bottom Front Right
            Vector(-size.x, size.y, -size.z),  -- Bottom Front Left

            -- Top face (z = size.z)
            Vector(-size.x, -size.y, size.z), -- Top Back Left
            Vector(size.x, -size.y, size.z),  -- Top Back Right
            Vector(size.x, size.y, size.z),   -- Top Front Right
            Vector(-size.x, size.y, size.z),  -- Top Front Left
        }

        self:PhysicsInitConvex(finalMesh)
        self:EnableCustomCollisions(true)

        phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
            phys:SetMaterial("glass")
            phys:SetMass(250)
            phys:SetContents(bit.bor(CONTENTS_SOLID, CONTENTS_MONSTER, CONTENTS_WINDOW))
        else
            self:PhysicsDestroy()
            self:EnableCustomCollisions(false)
            print("Failure to create a valid physics object for portal " .. self:EntIndex())
        end
    else
        self:PhysicsDestroy()
        self:EnableCustomCollisions(false)
        print("Failure to initialize physics for portal " .. self:EntIndex())
    end
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
		PropPortal.AddToRenderList(self)

		if not IsValid(self.RingParticle) then
			-- they're lagging
			self.RingParticle = CreateParticleSystem(self, self:GetType() == PORTAL_TYPE_SECOND and "portal_edge_reverse" or "portal_edge", PATTACH_CUSTOMORIGIN)
			self.RingParticle:StartEmission()
			self.RingParticle:SetShouldDraw(false)
		else
			self.RingParticle:SetControlPoint(0, self:GetPos() - self:GetAngles():Up() * 7)

			-- Messed up axes in Seamless Portals
			-- right is forward
			-- forward is right
			-- up is same
			local angles = self:GetAngles()
			local fwd, right, up = angles:Forward(), angles:Right(), angles:Up()
			self.RingParticle:SetControlPointOrientation(0, right, fwd, up)
			self.RingParticle:SetControlPoint(7, self:GetColorVector())
		end

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

function ENT:Fizzle()
	net.Start(GP2.Net.SendPortalClose)
		net.WriteVector(self:GetPos())
		net.WriteAngle(self:GetAngles())
		net.WriteVector(self:GetColorVector())
	net.Broadcast()

	EmitSound(self:GetType() == PORTAL_TYPE_SECOND and "Portal.close_red" or "Portal.close_blue", self:GetPos())

	self:Remove()
end

function ENT:OnActivated(name, old, new)
	if SERVER then
		self:SetOpenTime(CurTime())
		
		if new then
			self:EmitSound(self:GetType() == PORTAL_TYPE_SECOND and "Portal.open_red" or "Portal.open_blue")
		end
	end
	
	-- Override portal in LinkageGroup after activation change
	PortalManager.SetPortal(self:GetLinkageGroup(), self)
end

function ENT:SetLinkedPartner(partner)
	if partner:GetClass() ~= self:GetClass() then
		return
	end

	if not partner:GetActivated() then 
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

function ENT:GetColorVector()
	return self:GetColorVectorInternal()
end

--- Sets portal color (vector and color version)
---@param r number: red component
---@param g number: green component
---@param b number: blue component
function ENT:SetPortalColor(r, g, b)
	self:SetColorVectorInternal(Vector(r, g, b))
	self:SetColorVector01Internal(Vector(r / 255, g / 255, b / 255))
end