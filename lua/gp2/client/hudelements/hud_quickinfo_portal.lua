-- ----------------------------------------------------------------------------
-- GP2 Framework
-- Quick info on crosshair
-- ----------------------------------------------------------------------------

AddCSLuaFile()

local surface_SetDrawColor = surface.SetDrawColor
local surface_SetMaterial = surface.SetMaterial
local surface_DrawRect = surface.DrawRect
local surface_DrawTexturedRectUV = surface.DrawTexturedRectUV

local PANEL = {}
PANEL.BaseClass = baseclass.Get("GP2Panel")

local VALID_CLASSES = {
    ["weapon_portalgun"] = true
}

local crosshairParts = {
    { width = 47, height = 64, xOffset = 0 },
    { width = 46, height = 64, xOffset = 49 },
    { width = 46, height = 64, xOffset = 97 },
    { width = 46, height = 64, xOffset = 145 },
    { width = 30, height = 64, xOffset = 185 }
}

local crosshairMaterial = Material("hud/portal_crosshairs.png")
local ref = Material("hud/ref1.png")

local function drawCrosshairPart(id, x, y, color)
    local part = crosshairParts[id]
    if not part then
        print("Invalid crosshair part ID:", id)
        return
    end

    surface_SetDrawColor(color or Color(255, 255, 255, 255))
    surface_SetMaterial(crosshairMaterial)

    local textureWidth = crosshairMaterial:Width()

    local u0 = (part.xOffset / textureWidth)
    local v0 = 0
    local u1 = ((part.xOffset + part.width) / textureWidth)
    local v1 = 1

    surface_DrawTexturedRectUV(x, y, part.width, part.height, u0, v0, u1, v1)
end

function PANEL:Init()
    self:SetWidth(ScrW())
    self:SetTall(ScrH())
    self:SetParent(GetHUDPanel())
end

local PORTAL_COLOR1 = Color(111, 185, 255)
local PORTAL_COLOR2 = Color(255, 185, 84)

function PANEL:Paint(w, h)
    self.ply = self.ply or LocalPlayer()

    local ply = self.ply
    local weapon = ply:GetActiveWeapon()

    if not (IsValid(weapon) and VALID_CLASSES[weapon:GetClass()]) then
        return
    end

    surface_SetMaterial(crosshairMaterial)

    local can1 = weapon:GetCanFirePortal1()
    local can2 = weapon:GetCanFirePortal2()

    if not (can1 or can2) then return end

    local group = PortalManager.LinkageGroups[weapon:GetLinkageGroup()]
    local placed1 = can1 and group[0] or group[1]
    local placed2 = can2 and group[1] or group[0]

    local leftColor = can1 and PORTAL_COLOR1 or PORTAL_COLOR2
    local rightColor = can2 and PORTAL_COLOR2 or PORTAL_COLOR1

    leftColor.a = IsValid(placed1) and 255 or 196
    rightColor.a = IsValid(placed2) and 255 or 196

    if IsValid(placed1) then
        drawCrosshairPart(3, w / 2 - 29, h / 2 - 44, leftColor)
    else
        drawCrosshairPart(1, w / 2 - 31, h / 2 - 44, leftColor)
    end
    
    if IsValid(placed2) then
        drawCrosshairPart(4, w / 2 - 17, h / 2 - 22, rightColor)
    else
        drawCrosshairPart(2, w / 2 - 18, h / 2 - 22, rightColor)
    end

    surface_SetDrawColor(255,255,255,255)
    surface_DrawRect(w / 2 - 1, h / 2, 1, 1)
    surface_DrawRect(w / 2 - 1, h / 2 + 11, 1, 1)
    surface_DrawRect(w / 2 - 1, h / 2 - 11, 1, 1)
    surface_DrawRect(w / 2 - 11, h / 2, 1, 1)
    surface_DrawRect(w / 2 + 9, h / 2, 1, 1)
end

function PANEL:ShouldDraw()
    if not self.BaseClass.ShouldDraw() then
        return false
    end

    return true
end

vgui.Register("GP2HudQuickinfoPortal", PANEL, "GP2Panel")