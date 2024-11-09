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

