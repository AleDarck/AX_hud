Config = {}

-- Logo del servidor
Config.ShowLogo = true
Config.LogoURL = "https://r2.fivemanage.com/eTJhOKg29yrEEcXKzSAoB/NewLogo.png" -- Cambia por tu URL

-- Sistema de GPS
Config.RequireGPS = true
Config.GPSItem = "money" -- Nombre del item en ox_inventory

-- Location Display
Config.ShowLocation = true

-- Elementos a mostrar
Config.ShowVoice = true        -- Micrófono
Config.ShowTemperature = true  -- Temperatura
Config.ShowThirst = true       -- Sed
Config.ShowHunger = true       -- Hambre
Config.ShowArmor = true        -- Armadura (solo si tiene)
Config.ShowHealth = true       -- Salud
Config.ShowStress = true       -- Estrés
Config.ShowOxygen = true       -- Oxígeno bajo el agua

-- Colores - AGREGA stamina
Config.Colors = {
    outline = {255, 255, 255},
    voice = {255, 255, 255},
    stress = {156, 39, 176},
    oxygen = {3, 169, 244},
    temperature = {255, 152, 0},
    thirst = {3, 169, 244},
    hunger = {255, 193, 7},
    armor = {33, 150, 243},
    health = {244, 67, 54}
}

-- Temperatura (sistema opcional)
Config.UseTemperature = true
Config.TemperatureDefault = 36.5 -- Temperatura corporal normal

-- Configuración de vehículo
Config.ShowVehicleHUD = true
Config.VehicleHUD = {
    useFuel = true,
    fuelScript = "AX_LegacyFuel", -- LegacyFuel, cdn-fuel, etc
    useKeys = true,
    keysScript = "t1ger_keys"
}

-- Weapon HUD
Config.ShowWeaponHUD = true
Config.WeaponHUD = {
    showName = true,
    showAmmo = true,
    showAmmoBar = true,
    hideWithMelee = true,
    inventoryPath = "nui://ox_inventory/web/images/"
}

--[[

local health = exports['AX_hud']:GetHealth()
exports['AX_hud']:ToggleHUD(false) -- Ocultar

]]--