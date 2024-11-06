-- this is the rendering code for the portals, some references from: https://github.com/MattJeanes/world-portals

AddCSLuaFile()

if SERVER then return end

PortalRendering = {}

PortalRendering.PortalRTs = {}
PortalRendering.PortalMaterials = {}

-- max amount of portals being rendered at a time
PortalRendering.MaxRTs = 6

local sky_cvar = GetConVar("sv_skyname")
local sky_name = ""
local sky_materials = {}

local portals = {}
local oldHalo = 0
local timesRendered = 0

local skysize = 16384	--2^14, default zfar limit
local angle_zero = Angle(0, 0, 0)

local gp2_portal_drawdistance = CreateClientConVar("gp2_portal_drawdistance", "250", true, true, "Sets the multiplier of how far a portal should render", 0)
local gp2_portal_refreshrate = CreateClientConVar("gp2_portal_refreshrate", "1", false, false, "How many frames to skip before rendering the next portal", 1)
local gp2_portal_draw_ghosting = CreateClientConVar("gp2_portal_draw_ghosting", "1", true, false, "Toggles the outline visible on portals through walls")

local renderViewTable = {
	x = 0,
	y = 0,
	w = ScrW(),
	h = ScrH(),
	origin = Vector(),
	angles = Angle(),
	drawviewmodel = false,
}

-- sort the portals by distance since draw functions do not obey the z buffer
timer.Create("seamless_portal_distance_fix", 0.25, 0, function()
	if !PortalManager or PortalManager.PortalIndex < 1 then return end
	portals = ents.FindByClass("prop_portal")
	table.sort(portals, function(a, b) 
		return a:GetPos():DistToSqr(EyePos()) < b:GetPos():DistToSqr(EyePos())
	end)

	-- update sky material (I guess it can change?)
	if sky_name != sky_cvar:GetString() then
		sky_name = sky_cvar:GetString()

		local prefix = "skybox/" .. sky_name
		sky_materials[1] = Material(prefix .. "bk")
		sky_materials[2] = Material(prefix .. "dn")
		sky_materials[3] = Material(prefix .. "ft")
		sky_materials[4] = Material(prefix .. "lf")
		sky_materials[5] = Material(prefix .. "rt")
		sky_materials[6] = Material(prefix .. "up")
	end
end)

-- update the rendertarget here since we cant do it in postdraw (cuz of infinite recursion)
local nofunc = function() end
local render_PushRenderTarget = render.PushRenderTarget
local render_PopRenderTarget = render.PopRenderTarget
local render_PushCustomClipPlane = render.PushCustomClipPlane
local render_PopCustomClipPlane = render.PopCustomClipPlane
local render_RenderView = render.RenderView
local render_EnableClipping = render.EnableClipping


local skip = 0
hook.Add("RenderScene", "seamless_portal_draw", function(eyePos, eyeAngles, fov)
	if PortalManager.PortalIndex < 1 then return end
	skip = (skip + 1) % gp2_portal_refreshrate:GetInt()
	if skip != 0 then return end

	PortalRendering.Rendering = true
	local oldHalo = halo.Add	-- black clipping plane fix
	halo.Add = nofunc
	local maxAm = --[[PortalRendering.ToggleMirror() and 1 or]] 0

	local render = render
	for k, v in ipairs(portals) do
		if timesRendered >= PortalRendering.MaxRTs - maxAm then break end
		if !v:IsValid() or !v:GetLinkedPartner():IsValid() then continue end
		
		if timesRendered < PortalRendering.MaxRTs and PortalManager.ShouldRender(v, eyePos, eyeAngles, gp2_portal_drawdistance:GetFloat()) then
			local linkedPartner = v:GetLinkedPartner()
			local editedPos, editedAng = PortalManager.TransformPortal(v, linkedPartner, eyePos, eyeAngles)

			renderViewTable.origin = editedPos
			renderViewTable.angles = editedAng
			renderViewTable.fov = fov

			//local pos1 = v:LocalToWorld(v:OBBMins()):ToScreen()
			//local pos2 = v:LocalToWorld(v:OBBMaxs()):ToScreen()
			//renderViewTable.x = v:LocalToWorld(Vector(-10, 0, 0)):ToScreen()

			timesRendered = timesRendered + 1
			v.PORTAL_RT_NUMBER = timesRendered	-- the number index of the rendertarget it will use in rendering

			-- render the scene
			local up = linkedPartner:GetUp()
			local oldClip = render.EnableClipping(true)
			render_PushRenderTarget(PortalRendering.PortalRTs[timesRendered])
			render_PushCustomClipPlane(up, up:Dot(linkedPartner:GetPos()))
			render_RenderView(renderViewTable)
			render_PopCustomClipPlane()
			render_EnableClipping(oldClip)
			render_PopRenderTarget()
		end
	end

	halo.Add = oldHalo
	PortalRendering.Rendering = false
	timesRendered = 0
end)

-- draw the player in renderview
hook.Add("ShouldDrawLocalPlayer", "seamless_portal_drawplayer", function()
	if PortalRendering.Rendering and !PortalRendering.DrawPlayerInView then 
		return true 
	end
end)

-- (REWRITE THIS!)
-- draw the 2d skybox in place of the black (Thanks to Fafy2801)
local render_SetMaterial = render.SetMaterial
local render_DrawQuadEasy = render.DrawQuadEasy
local function drawsky(pos, ang, size, size_2, color, materials)
	-- BACK
	render_SetMaterial(materials[1])
	render_DrawQuadEasy(pos + Vector(0, size, 0), Vector(0, -1, 0), size_2, size_2, color, 0)
	-- DOWN
	render_SetMaterial(materials[2])
	render_DrawQuadEasy(pos - Vector(0, 0, size), Vector(0, 0, 1), size_2, size_2, color, 180)
	-- FRONT
	render_SetMaterial(materials[3])
	render_DrawQuadEasy(pos - Vector(0, size, 0), Vector(0, 1, 0), size_2, size_2, color, 0)
	-- LEFF
	render_SetMaterial(materials[4])
	render_DrawQuadEasy(pos - Vector(size, 0, 0), Vector(1, 0, 0), size_2, size_2, color, 0)
	-- RIGHT
	render_SetMaterial(materials[5])
	render_DrawQuadEasy(pos + Vector(size, 0, 0), Vector(-1, 0, 0), size_2, size_2, color, 0)
	-- UP
	render_SetMaterial(materials[6])
	render_DrawQuadEasy(pos + Vector(0, 0, size), Vector(0, 0, -1), size_2, size_2, color, 180)
end

hook.Add("PostDrawTranslucentRenderables", "seamless_portal_skybox", function()
	//render.DrawWireframeBox(Vector(), Angle(), Vector(1, 1, 1) * -2^14, Vector(1, 1, 1) * 2^14, Color(0, 0, 255, 255))
	if !PortalRendering.Rendering or util.IsSkyboxVisibleFromPoint(renderViewTable.origin) then return end
	render.OverrideDepthEnable(true, false)
	drawsky(renderViewTable.origin, angle_zero, skysize, -skysize * 2, color_white, sky_materials)
	render.OverrideDepthEnable(false , false)
end)

function PortalRendering.GetDrawDistance()
	return gp2_portal_drawdistance:GetFloat()
end

function PortalRendering.GetShowGhosting()
	return gp2_portal_draw_ghosting:GetBool()
end