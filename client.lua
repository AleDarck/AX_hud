local ESX = exports['es_extended']:getSharedObject()
local PlayerData = {}
-- Variables de GPS
local hasGPS = false
local minimapEnabled = false
-- Variables de arma
local currentWeapon = nil
local currentWeaponName = ""
local currentAmmo = 0
local currentAmmoInClip = 0
local isArmed = false

-- Variables de estado
local statusData = {
    health = 100,
    armor = 0,
    hunger = 100,
    thirst = 100,
    stress = 0,
    oxygen = 100,
    temperature = 36.5,
    isDead = false
}

-- Variables de voz
local currentVoiceMode = 2
local isTalking = false

-- Variables de vehículo
local inVehicle = false
local seatbeltOn = false

-- Variable para estado del HUD
local hudEnabled = true

-- Inicialización
Citizen.CreateThread(function()
    Wait(1000)
    SendNUIMessage({
        action = "setColors",
        colors = Config.Colors
    })
    
    -- Enviar logo por separado
    if Config.ShowLogo and Config.LogoURL then
        Wait(100)
        SendNUIMessage({
            action = "setLogo",
            url = Config.LogoURL
        })
    end
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
end)

RegisterNetEvent('esx:onPlayerDeath')
AddEventHandler('esx:onPlayerDeath', function()
    statusData.isDead = true
    DisplayRadar(false) -- Ocultar minimapa al morir
end)

RegisterNetEvent('esx:onPlayerSpawn')
AddEventHandler('esx:onPlayerSpawn', function()
    statusData.isDead = false
end)

-- Escuchar cambios de modo de voz (pma-voice)
AddEventHandler('pma-voice:setTalkingMode', function(mode)
    currentVoiceMode = mode
    SendNUIMessage({
        action = "updateVoice",
        voice = currentVoiceMode,
        isTalking = isTalking
    })
end)

-- Thread principal optimizado
Citizen.CreateThread(function()
    while true do
        local sleep = 500
        
        if not statusData.isDead then
            local playerPed = PlayerPedId()
            
            -- SALUD
            local health = GetEntityHealth(playerPed)
            local maxHealth = GetEntityMaxHealth(playerPed)
            statusData.health = math.floor(((health - 100) / (maxHealth - 100)) * 100)
            if statusData.health < 0 then statusData.health = 0 end
            if statusData.health > 100 then statusData.health = 100 end
            
            -- ARMADURA
            statusData.armor = GetPedArmour(playerPed)
            
            -- SED
            TriggerEvent('esx_status:getStatus', 'thirst', function(status)
                if status then
                    statusData.thirst = math.floor(status.getPercent())
                end
            end)
            
            -- HAMBRE
            TriggerEvent('esx_status:getStatus', 'hunger', function(status)
                if status then
                    statusData.hunger = math.floor(status.getPercent())
                end
            end)
            
            -- ESTRÉS
            TriggerEvent('esx_status:getStatus', 'stress', function(status)
                if status then
                    statusData.stress = math.floor(status.getPercent())
                end
            end)
            
            -- OXÍGENO
            if IsPedSwimmingUnderWater(playerPed) then
                local oxygenLevel = GetPlayerUnderwaterTimeRemaining(PlayerId()) * 10
                statusData.oxygen = math.floor(oxygenLevel)
                if statusData.oxygen < 0 then statusData.oxygen = 0 end
                if statusData.oxygen > 100 then statusData.oxygen = 100 end
            else
                statusData.oxygen = 100
            end
            
            -- TEMPERATURA
            if Config.UseTemperature then
                statusData.temperature = Config.TemperatureDefault
            end
            
            -- Enviar TODOS los datos al NUI en un solo mensaje
            SendNUIMessage({
                action = "updateStats",
                data = {
                    health = statusData.health,
                    armor = statusData.armor,
                    thirst = statusData.thirst,
                    hunger = statusData.hunger,
                    stress = statusData.stress,
                    oxygen = statusData.oxygen,
                    temperature = statusData.temperature,
                    showArmor = Config.ShowArmor and statusData.armor > 0,
                    isUnderwater = IsPedSwimmingUnderWater(playerPed)
                }
            })
        end
        
        Citizen.Wait(sleep)
    end
end)

-- Thread para voz (más rápido solo para voz)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(150)
        
        if not statusData.isDead then
            local wasTalking = isTalking
            isTalking = NetworkIsPlayerTalking(PlayerId())
            
            -- Solo actualizar si cambió el estado de hablar
            if wasTalking ~= isTalking then
                SendNUIMessage({
                    action = "updateVoice",
                    voice = currentVoiceMode,
                    isTalking = isTalking
                })
            end
        end
    end
end)

-- Thread para stamina
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)
        
        if not statusData.isDead then
            local playerPed = PlayerPedId()
            local stamina = 100 - GetPlayerSprintStaminaRemaining(PlayerId())
            if stamina < 0 then stamina = 0 end
            if stamina > 100 then stamina = 100 end
            
            SendNUIMessage({
                action = "updateStamina",
                stamina = stamina,
                inVehicle = inVehicle
            })
        end
    end
end)

-- Thread para ubicación
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Actualizar cada segundo
        
        if not statusData.isDead then
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)
            
            -- Obtener nombre de la zona
            local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
            
            -- Obtener nombre de la calle
            local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
            local street = GetStreetNameFromHashKey(streetHash)
            
            -- Si no hay nombre de calle, usar "Unknown"
            if street == "" or street == nil then
                street = "Unknown Street"
            end
            
            -- Si la zona es un código, usar "Unknown"
            if zone == "ZONE_" or zone == "" or zone == nil then
                zone = "Unknown Area"
            end
            
            SendNUIMessage({
                action = "updateLocation",
                zone = zone,
                street = street,
                inVehicle = inVehicle
            })
        end
    end
end)

-- Thread para Weapon HUD
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)
        
        if not statusData.isDead then
            local playerPed = PlayerPedId()
            local weaponHash = GetSelectedPedWeapon(playerPed)
            
            -- Si no tiene arma o tiene puños
            if weaponHash == `WEAPON_UNARMED` or weaponHash == 0 then
                if isArmed then
                    isArmed = false
                    SendNUIMessage({
                        action = "hideWeaponHUD"
                    })
                end
            else
                -- Obtener información del arma
                local ammoInClip = GetAmmoInClip(playerPed, weaponHash)
                local _, maxClipAmmo = GetMaxAmmoInClip(playerPed, weaponHash)
                
                -- Obtener munición total de forma segura
                local _, totalAmmoRaw = GetAmmoInPedWeapon(playerPed, weaponHash)
                local totalAmmo = 0
                
                if totalAmmoRaw and type(totalAmmoRaw) == "number" then
                    totalAmmo = totalAmmoRaw - ammoInClip
                    if totalAmmo < 0 then totalAmmo = 0 end
                end
                
                -- Obtener nombre del arma
                local weaponName = GetWeaponLabel(weaponHash)
                
                -- Obtener item name para la imagen
                local weaponItem = GetWeaponItemName(weaponHash)
                
                -- Verificar si es arma de cuerpo a cuerpo (maxClipAmmo será 0 o nil)
                local isMelee = (not maxClipAmmo or maxClipAmmo == 0)
                
                if Config.WeaponHUD.hideWithMelee and isMelee then
                    if isArmed then
                        isArmed = false
                        SendNUIMessage({
                            action = "hideWeaponHUD"
                        })
                    end
                else
                    isArmed = true
                    
                    SendNUIMessage({
                        action = "updateWeaponHUD",
                        data = {
                            weaponName = weaponName,
                            weaponItem = weaponItem,
                            ammoInClip = ammoInClip or 0,
                            maxClipAmmo = maxClipAmmo or 0,
                            totalAmmo = totalAmmo,
                            isMelee = isMelee
                        }
                    })
                end
            end
        else
            if isArmed then
                isArmed = false
                SendNUIMessage({
                    action = "hideWeaponHUD"
                })
            end
        end
    end
end)

-- Función auxiliar para obtener el nombre del item del arma
function GetWeaponItemName(weaponHash)
    -- Tabla de nombres de items
    local weapons = {
        [`WEAPON_PISTOL`] = "weapon_pistol",
        [`WEAPON_PISTOL_MK2`] = "weapon_pistol_mk2",
        [`WEAPON_COMBATPISTOL`] = "weapon_combatpistol",
        [`WEAPON_APPISTOL`] = "weapon_appistol",
        [`WEAPON_PISTOL50`] = "weapon_pistol50",
        [`WEAPON_SNSPISTOL`] = "weapon_snspistol",
        [`WEAPON_SNSPISTOL_MK2`] = "weapon_snspistol_mk2",
        [`WEAPON_HEAVYPISTOL`] = "weapon_heavypistol",
        [`WEAPON_VINTAGEPISTOL`] = "weapon_vintagepistol",
        [`WEAPON_MARKSMANPISTOL`] = "weapon_marksmanpistol",
        [`WEAPON_REVOLVER`] = "weapon_revolver",
        [`WEAPON_REVOLVER_MK2`] = "weapon_revolver_mk2",
        [`WEAPON_DOUBLEACTION`] = "weapon_doubleaction",
        [`WEAPON_MICROSMG`] = "weapon_microsmg",
        [`WEAPON_SMG`] = "weapon_smg",
        [`WEAPON_SMG_MK2`] = "weapon_smg_mk2",
        [`WEAPON_ASSAULTSMG`] = "weapon_assaultsmg",
        [`WEAPON_COMBATPDW`] = "weapon_combatpdw",
        [`WEAPON_MACHINEPISTOL`] = "weapon_machinepistol",
        [`WEAPON_MINISMG`] = "weapon_minismg",
        [`WEAPON_PUMPSHOTGUN`] = "weapon_pumpshotgun",
        [`WEAPON_PUMPSHOTGUN_MK2`] = "weapon_pumpshotgun_mk2",
        [`WEAPON_SAWNOFFSHOTGUN`] = "weapon_sawnoffshotgun",
        [`WEAPON_ASSAULTSHOTGUN`] = "weapon_assaultshotgun",
        [`WEAPON_BULLPUPSHOTGUN`] = "weapon_bullpupshotgun",
        [`WEAPON_MUSKET`] = "weapon_musket",
        [`WEAPON_HEAVYSHOTGUN`] = "weapon_heavyshotgun",
        [`WEAPON_DBSHOTGUN`] = "weapon_dbshotgun",
        [`WEAPON_AUTOSHOTGUN`] = "weapon_autoshotgun",
        [`WEAPON_ASSAULTRIFLE`] = "weapon_assaultrifle",
        [`WEAPON_ASSAULTRIFLE_MK2`] = "weapon_assaultrifle_mk2",
        [`WEAPON_CARBINERIFLE`] = "weapon_carbinerifle",
        [`WEAPON_CARBINERIFLE_MK2`] = "weapon_carbinerifle_mk2",
        [`WEAPON_ADVANCEDRIFLE`] = "weapon_advancedrifle",
        [`WEAPON_SPECIALCARBINE`] = "weapon_specialcarbine",
        [`WEAPON_SPECIALCARBINE_MK2`] = "weapon_specialcarbine_mk2",
        [`WEAPON_BULLPUPRIFLE`] = "weapon_bullpuprifle",
        [`WEAPON_BULLPUPRIFLE_MK2`] = "weapon_bullpuprifle_mk2",
        [`WEAPON_COMPACTRIFLE`] = "weapon_compactrifle",
        [`WEAPON_MG`] = "weapon_mg",
        [`WEAPON_COMBATMG`] = "weapon_combatmg",
        [`WEAPON_COMBATMG_MK2`] = "weapon_combatmg_mk2",
        [`WEAPON_GUSENBERG`] = "weapon_gusenberg",
        [`WEAPON_SNIPERRIFLE`] = "weapon_sniperrifle",
        [`WEAPON_HEAVYSNIPER`] = "weapon_heavysniper",
        [`WEAPON_HEAVYSNIPER_MK2`] = "weapon_heavysniper_mk2",
        [`WEAPON_MARKSMANRIFLE`] = "weapon_marksmanrifle",
        [`WEAPON_MARKSMANRIFLE_MK2`] = "weapon_marksmanrifle_mk2",
        [`WEAPON_RPG`] = "weapon_rpg",
        [`WEAPON_GRENADELAUNCHER`] = "weapon_grenadelauncher",
        [`WEAPON_GRENADELAUNCHER_SMOKE`] = "weapon_grenadelauncher_smoke",
        [`WEAPON_MINIGUN`] = "weapon_minigun",
        [`WEAPON_FIREWORK`] = "weapon_firework",
        [`WEAPON_RAILGUN`] = "weapon_railgun",
        [`WEAPON_HOMINGLAUNCHER`] = "weapon_hominglauncher",
        [`WEAPON_COMPACTLAUNCHER`] = "weapon_compactlauncher",
        [`WEAPON_GRENADE`] = "weapon_grenade",
        [`WEAPON_STICKYBOMB`] = "weapon_stickybomb",
        [`WEAPON_PROXMINE`] = "weapon_proxmine",
        [`WEAPON_BZGAS`] = "weapon_bzgas",
        [`WEAPON_MOLOTOV`] = "weapon_molotov",
        [`WEAPON_FIREEXTINGUISHER`] = "weapon_fireextinguisher",
        [`WEAPON_PETROLCAN`] = "weapon_petrolcan",
        [`WEAPON_KNIFE`] = "weapon_knife",
        [`WEAPON_NIGHTSTICK`] = "weapon_nightstick",
        [`WEAPON_HAMMER`] = "weapon_hammer",
        [`WEAPON_BAT`] = "weapon_bat",
        [`WEAPON_GOLFCLUB`] = "weapon_golfclub",
        [`WEAPON_CROWBAR`] = "weapon_crowbar",
        [`WEAPON_BOTTLE`] = "weapon_bottle",
        [`WEAPON_DAGGER`] = "weapon_dagger",
        [`WEAPON_HATCHET`] = "weapon_hatchet",
        [`WEAPON_KNUCKLE`] = "weapon_knuckle",
        [`WEAPON_MACHETE`] = "weapon_machete",
        [`WEAPON_FLASHLIGHT`] = "weapon_flashlight",
        [`WEAPON_SWITCHBLADE`] = "weapon_switchblade",
        [`WEAPON_POOLCUE`] = "weapon_poolcue",
        [`WEAPON_WRENCH`] = "weapon_wrench",
        [`WEAPON_BATTLEAXE`] = "weapon_battleaxe",
    }
    
    return weapons[weaponHash] or "weapon_pistol"
end

-- Función auxiliar para obtener el label del arma
function GetWeaponLabel(weaponHash)
    -- Tabla de nombres personalizados
    local weaponLabels = {
        [`WEAPON_PISTOL`] = "PISTOL",
        [`WEAPON_PISTOL_MK2`] = "PISTOL MK2",
        [`WEAPON_COMBATPISTOL`] = "COMBAT PISTOL",
        [`WEAPON_APPISTOL`] = "AP PISTOL",
        [`WEAPON_PISTOL50`] = "PISTOL .50",
        [`WEAPON_SNSPISTOL`] = "SNS PISTOL",
        [`WEAPON_SNSPISTOL_MK2`] = "SNS PISTOL MK2",
        [`WEAPON_HEAVYPISTOL`] = "HEAVY PISTOL",
        [`WEAPON_VINTAGEPISTOL`] = "VINTAGE PISTOL",
        [`WEAPON_MARKSMANPISTOL`] = "MARKSMAN PISTOL",
        [`WEAPON_REVOLVER`] = "REVOLVER",
        [`WEAPON_REVOLVER_MK2`] = "REVOLVER MK2",
        [`WEAPON_DOUBLEACTION`] = "DOUBLE ACTION",
        [`WEAPON_MICROSMG`] = "MICRO SMG",
        [`WEAPON_SMG`] = "SMG",
        [`WEAPON_SMG_MK2`] = "SMG MK2",
        [`WEAPON_ASSAULTSMG`] = "ASSAULT SMG",
        [`WEAPON_COMBATPDW`] = "COMBAT PDW",
        [`WEAPON_MACHINEPISTOL`] = "MACHINE PISTOL",
        [`WEAPON_MINISMG`] = "MINI SMG",
        [`WEAPON_PUMPSHOTGUN`] = "PUMP SHOTGUN",
        [`WEAPON_PUMPSHOTGUN_MK2`] = "PUMP SHOTGUN MK2",
        [`WEAPON_SAWNOFFSHOTGUN`] = "SAWED-OFF",
        [`WEAPON_ASSAULTSHOTGUN`] = "ASSAULT SHOTGUN",
        [`WEAPON_BULLPUPSHOTGUN`] = "BULLPUP SHOTGUN",
        [`WEAPON_MUSKET`] = "MUSKET",
        [`WEAPON_HEAVYSHOTGUN`] = "HEAVY SHOTGUN",
        [`WEAPON_DBSHOTGUN`] = "DOUBLE BARREL",
        [`WEAPON_AUTOSHOTGUN`] = "AUTO SHOTGUN",
        [`WEAPON_ASSAULTRIFLE`] = "AK-47",
        [`WEAPON_ASSAULTRIFLE_MK2`] = "AK-47 MK2",
        [`WEAPON_CARBINERIFLE`] = "CARBINE",
        [`WEAPON_CARBINERIFLE_MK2`] = "CARBINE MK2",
        [`WEAPON_ADVANCEDRIFLE`] = "ADVANCED RIFLE",
        [`WEAPON_SPECIALCARBINE`] = "SPECIAL CARBINE",
        [`WEAPON_SPECIALCARBINE_MK2`] = "SPECIAL CARBINE MK2",
        [`WEAPON_BULLPUPRIFLE`] = "BULLPUP RIFLE",
        [`WEAPON_BULLPUPRIFLE_MK2`] = "BULLPUP RIFLE MK2",
        [`WEAPON_COMPACTRIFLE`] = "COMPACT RIFLE",
        [`WEAPON_MG`] = "MG",
        [`WEAPON_COMBATMG`] = "COMBAT MG",
        [`WEAPON_COMBATMG_MK2`] = "COMBAT MG MK2",
        [`WEAPON_GUSENBERG`] = "GUSENBERG",
        [`WEAPON_SNIPERRIFLE`] = "SNIPER RIFLE",
        [`WEAPON_HEAVYSNIPER`] = "HEAVY SNIPER",
        [`WEAPON_HEAVYSNIPER_MK2`] = "HEAVY SNIPER MK2",
        [`WEAPON_MARKSMANRIFLE`] = "MARKSMAN RIFLE",
        [`WEAPON_MARKSMANRIFLE_MK2`] = "MARKSMAN RIFLE MK2",
        [`WEAPON_RPG`] = "RPG",
        [`WEAPON_GRENADELAUNCHER`] = "GRENADE LAUNCHER",
        [`WEAPON_GRENADELAUNCHER_SMOKE`] = "SMOKE LAUNCHER",
        [`WEAPON_MINIGUN`] = "MINIGUN",
        [`WEAPON_FIREWORK`] = "FIREWORK",
        [`WEAPON_RAILGUN`] = "RAILGUN",
        [`WEAPON_HOMINGLAUNCHER`] = "HOMING LAUNCHER",
        [`WEAPON_COMPACTLAUNCHER`] = "COMPACT LAUNCHER",
        [`WEAPON_GRENADE`] = "GRENADE",
        [`WEAPON_STICKYBOMB`] = "STICKY BOMB",
        [`WEAPON_PROXMINE`] = "PROXIMITY MINE",
        [`WEAPON_BZGAS`] = "BZ GAS",
        [`WEAPON_MOLOTOV`] = "MOLOTOV",
        [`WEAPON_FIREEXTINGUISHER`] = "FIRE EXTINGUISHER",
        [`WEAPON_PETROLCAN`] = "JERRY CAN",
        [`WEAPON_KNIFE`] = "KNIFE",
        [`WEAPON_NIGHTSTICK`] = "NIGHTSTICK",
        [`WEAPON_HAMMER`] = "HAMMER",
        [`WEAPON_BAT`] = "BAT",
        [`WEAPON_GOLFCLUB`] = "GOLF CLUB",
        [`WEAPON_CROWBAR`] = "CROWBAR",
        [`WEAPON_BOTTLE`] = "BOTTLE",
        [`WEAPON_DAGGER`] = "DAGGER",
        [`WEAPON_HATCHET`] = "HATCHET",
        [`WEAPON_KNUCKLE`] = "BRASS KNUCKLES",
        [`WEAPON_MACHETE`] = "MACHETE",
        [`WEAPON_FLASHLIGHT`] = "FLASHLIGHT",
        [`WEAPON_SWITCHBLADE`] = "SWITCHBLADE",
        [`WEAPON_POOLCUE`] = "POOL CUE",
        [`WEAPON_WRENCH`] = "WRENCH",
        [`WEAPON_BATTLEAXE`] = "BATTLE AXE",
    }
    
    return weaponLabels[weaponHash] or "WEAPON"
end

-- Thread para detectar vehículo
Citizen.CreateThread(function()
    while true do
        local sleep = 500
        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        
        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == playerPed then
            if not inVehicle then
                inVehicle = true
                SendNUIMessage({action = "showVehicleHUD", state = true})
            end
            sleep = 100
        else
            if inVehicle then
                inVehicle = false
                seatbeltOn = false
                SendNUIMessage({action = "showVehicleHUD", state = false})
            end
        end
        
        Citizen.Wait(sleep)
    end
end)

-- Thread para actualizar datos del vehículo
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(200)
        
        if inVehicle then
            local playerPed = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            
            if vehicle ~= 0 then
                -- Velocidad
                local speed = math.floor(GetEntitySpeed(vehicle) * 3.6)
                
                -- Combustible (fix para AX_LegacyFuel)
                local fuel = 0
                if Config.VehicleHUD.useFuel then
                    if Config.VehicleHUD.fuelScript == "AX_LegacyFuel" or Config.VehicleHUD.fuelScript == "LegacyFuel" then
                        -- Intentar obtener fuel del Entity State
                        fuel = Entity(vehicle).state.fuel or 0
                        
                        -- Si no funciona, intentar con export
                        if fuel == 0 then
                            local success, fuelValue = pcall(function()
                                return exports[Config.VehicleHUD.fuelScript]:GetFuel(vehicle)
                            end)
                            
                            if success and fuelValue then
                                fuel = fuelValue
                            end
                        end
                    else
                        fuel = GetVehicleFuelLevel(vehicle)
                    end
                else
                    fuel = 100
                end
                
                -- Estado del motor (CORREGIDO)
                local engineHealth = GetVehicleEngineHealth(vehicle)
                local vehicleHealth = 0
                
                if engineHealth >= 1000 then
                    vehicleHealth = 100
                elseif engineHealth <= 0 then
                    vehicleHealth = 0
                else
                    -- Mapear de 0-1000 a 0-100
                    vehicleHealth = (engineHealth / 1000) * 100
                end
                
                -- Asegurar que esté en rango
                if vehicleHealth < 0 then vehicleHealth = 0 end
                if vehicleHealth > 100 then vehicleHealth = 100 end
                
                -- Estado de llave (bloqueado)
                local isLocked = false
                if Config.VehicleHUD.useKeys then
                    local lockStatus = exports['t1ger_keys']:GetVehicleLockedStatus(vehicle)
                    -- lockStatus 1 o 2 = cerrado, otros = abierto
                    isLocked = (lockStatus == 1 or lockStatus == 2)
                end
                
                SendNUIMessage({
                    action = "updateVehicle",
                    data = {
                        speed = speed,
                        fuel = math.floor(fuel),
                        engine = math.floor(vehicleHealth),
                        belt = seatbeltOn,
                        locked = isLocked
                    }
                })
            end
        end
    end
end)

-- Cinturón de seguridad (tecla B)
local beltPressed = false

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if inVehicle then
            -- Detectar tecla B (29)
            if IsControlJustPressed(0, 29) then -- B
                if not beltPressed then
                    beltPressed = true
                    seatbeltOn = not seatbeltOn
                    
                    local playerPed = PlayerPedId()
                    if seatbeltOn then
                        SetPedConfigFlag(playerPed, 32, true)
                        ESX.ShowNotification('Cinturón de seguridad puesto','success')
                    else
                        SetPedConfigFlag(playerPed, 32, false)
                        ESX.ShowNotification('Cinturón de seguridad quitado','warning')
                    end
                    
                    Citizen.Wait(200) -- Anti-spam
                    beltPressed = false
                end
            end
        else
            Citizen.Wait(500)
        end
    end
end)

-- Desactivar radio nativa del vehículo
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        
        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        
        if vehicle ~= 0 then
            SetVehicleRadioEnabled(vehicle, false)
        end
    end
end)

-- Comando para toggle HUD
RegisterCommand('togglehud', function()
    hudEnabled = not hudEnabled
    SendNUIMessage({
        action = "toggleHUD",
        state = hudEnabled
    })
    
    if hudEnabled then
        ESX.ShowNotification('HUD ~g~activado')
    else
        ESX.ShowNotification('HUD ~r~desactivado')
    end
end, false)

-- Comando para recargar posición del minimapa
RegisterCommand('reloadmap', function()
    -- Forzar recargar la posición del minimapa
    SetMinimapComponentPosition('minimap', 'L', 'B', 0.015, 0.025, 0.150, 0.188)
    SetMinimapComponentPosition('minimap_mask', 'L', 'B', 0.035, 0.055, 0.111, 0.159)
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.01, 0.021, 0.266, 0.237)
    SetRadarZoom(1100)
    
    ESX.ShowNotification('Minimapa recargado')
end, false)

-- Ocultar HUD nativo (optimizado)
local hideHudComponents = {1, 2, 3, 4, 6, 7, 8, 9, 13, 17, 20}

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        for _, component in ipairs(hideHudComponents) do
            HideHudComponentThisFrame(component)
        end
    end
end)

-- Sistema de GPS (requiere item)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(2000)
        
        if Config.RequireGPS then
            -- Verificar si tiene el item GPS
            local itemCount = exports.ox_inventory:Search('count', Config.GPSItem)
            hasGPS = (itemCount and itemCount > 0)
            
            -- Mostrar minimapa si tiene GPS (sin importar si está en vehículo)
            if hasGPS ~= minimapEnabled then
                minimapEnabled = hasGPS
                DisplayRadar(minimapEnabled)
            end
        else
            -- Si no requiere GPS, mostrar siempre en vehículo
            if inVehicle ~= minimapEnabled then
                minimapEnabled = inVehicle
                DisplayRadar(minimapEnabled)
            end
        end
    end
end)

-- Ocultar minimapa al inicio
Citizen.CreateThread(function()
    Wait(500)
    if Config.RequireGPS then
        DisplayRadar(false)
    end
end)

-- Personalizar minimapa
Citizen.CreateThread(function()
    while not HasStreamedTextureDictLoaded("circlemap") do
        Wait(100)
    end
    
    -- Ajustamos X (de -0.0045 a 0.015) para mover a la derecha
    -- Ajustamos Y (de 0.002 a 0.025) para subirlo
    SetMinimapComponentPosition('minimap', 'L', 'B', 0.015, 0.025, 0.150, 0.188)
    SetMinimapComponentPosition('minimap_mask', 'L', 'B', 0.035, 0.055, 0.111, 0.159)
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.01, 0.021, 0.266, 0.237)
    
    SetRadarBigmapEnabled(false, false)
    SetRadarZoom(1100)
end)

-- EXPORTS
exports('GetHealth', function()
    return statusData.health
end)

exports('GetArmor', function()
    return statusData.armor
end)

exports('GetHunger', function()
    return statusData.hunger
end)

exports('GetThirst', function()
    return statusData.thirst
end)

exports('GetStress', function()
    return statusData.stress
end)

exports('GetOxygen', function()
    return statusData.oxygen
end)

exports('ToggleHUD', function(state)
    hudEnabled = state
    SendNUIMessage({
        action = "toggleHUD",
        state = hudEnabled
    })
end)

exports('IsHUDEnabled', function()
    return hudEnabled
end)