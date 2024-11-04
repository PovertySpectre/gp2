AddCSLuaFile()

PortalManager = {}

-- the number of portals in the map
PortalManager.PortalIndex = 0

PortalManager.LinkageGroups = {
	[0] = { NULL, NULL },
}

function PortalManager.SetPortal(linkageGroup, entity)
	if not IsValid(entity) or entity:GetClass() ~= "prop_portal" then
		return
	end

	if PortalManager.LinkageGroups[linkageGroup] == nil then
		PortalManager.LinkageGroups[linkageGroup] = { NULL, NULL }
	end

	local portalType = entity:GetType()
	local oppositePortalType = entity:GetType() == PORTAL_TYPE_BLUE and PORTAL_TYPE_ORANGE or PORTAL_TYPE_BLUE
	local portal = PortalManager.LinkageGroups[linkageGroup][portalType]
	local oppositePortal = PortalManager.LinkageGroups[linkageGroup][oppositePortalType]

	print(PortalManager.LinkageGroups[linkageGroup][PORTAL_TYPE_ORANGE])
	
	GP2.Print("Setting portal for linkageGroup == " .. linkageGroup .. " to " .. tostring(entity) .. " (type " .. portalType .. ")")

	if IsValid(portal) and portal ~= entity then
		if SERVER then
			portal:Remove()
		end
	end

	if IsValid(oppositePortal) then
		entity:SetLinkedPartner(oppositePortal)
	end

	if entity:GetActivated() then
		PortalManager.LinkageGroups[linkageGroup][portalType] = entity
	end
end

function PortalManager.TransformPortal(a, b, pos, ang)
	if !IsValid(a) or !IsValid(b) then return Vector(), Angle() end
	local editedPos = Vector()
	local editedAng = Angle()

	if pos then
		editedPos = a:WorldToLocal(pos) * (b:GetSize()[1] / a:GetSize()[1])
		editedPos = b:LocalToWorld(Vector(editedPos[1], -editedPos[2], -editedPos[3]))
		editedPos = editedPos + b:GetUp() * 0.01	// so you dont become trapped
	end

	if ang then
		local localAng = a:WorldToLocalAngles(ang)
		editedAng = b:LocalToWorldAngles(Angle(-localAng[1], -localAng[2], localAng[3] + 180))
	end

	-- mirror portal
	if a == b then
		if pos then
			editedPos = a:LocalToWorld(a:WorldToLocal(pos) * Vector(1, 1, -1)) 
		end

		if ang then
			local localAng = a:WorldToLocalAngles(ang)
			editedAng = a:LocalToWorldAngles(Angle(-localAng[1], localAng[2], -localAng[3] + 180))
		end
	end

	return editedPos, editedAng
end

function PortalManager.UpdateTraceline()
	if PortalManager.PortalIndex > 0 then
		util.TraceLine = PortalManager.TraceLinePortal	-- traceline that can go through portals
	else
		util.TraceLine = PortalManager.TraceLine	-- original traceline
	end
end

PortalManager.TraceLine = util.TraceLine
function PortalManager.TraceLinePortal(data)
	local tr = PortalManager.TraceLine(data)
	if tr.Entity:IsValid() then
		if tr.Entity:GetClass() == "prop_portal" and IsValid(tr.Entity:GetLinkedPartner()) then
			local hitPortal = tr.Entity
			if tr.HitNormal:Dot(hitPortal:GetUp()) > 0.9 then
				local editeddata = table.Copy(data)
				local exitportal = hitPortal:GetLinkedPartner()
				editeddata.start = PortalManager.TransformPortal(hitPortal, exitportal, tr.HitPos)
				editeddata.endpos = PortalManager.TransformPortal(hitPortal, exitportal, data.endpos)
				-- filter the exit portal from being hit by the ray
				if IsEntity(data.filter) and data.filter:GetClass() != "player" then
					editeddata.filter = {data.filter, exitportal}
				else
					if istable(editeddata.filter) then
						table.insert(editeddata.filter, exitportal)
					else
						editeddata.filter = exitportal
					end
				end
				return PortalManager.TraceLinePortal(editeddata)
			end
		end
		if data["WorldDetour"] then tr.Entity = game.GetWorld() end
	end
	return tr
end

-- Should be in PortalRendering, but it's here
-- PortalRendering is CLIENTSIDE
function PortalManager.ShouldRender(portal, eyePos, eyeAngle, distance)
    -- Check if the portal is dormant
    if portal:IsDormant() then return false end
    
    local portalPos = portal:GetPos()
    local portalUp = portal:GetUp()
    local exitSize = portal:GetSize()
    local max = math.max(exitSize[1], exitSize[2])
    local eye = (eyePos - portalPos)

    -- Check if the eye position is behind the portal
    if eye:Dot(portalUp) <= -exitSize[3] then return false end

    -- Check if the eye position is close enough to the portal
    if eye:LengthSqr() >= distance^2 * max then return false end

    -- Check if the eye position is looking towards the portal
    return eye:Dot(eyeAngle:Forward()) < max
end