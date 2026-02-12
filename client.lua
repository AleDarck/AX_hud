local ESX = exports['es_extended']:getSharedObject()
local PlayerData = {}
-- Variables de GPS
local hasGPS = false
local minimapEnabled = false

-- Variables de estado
local statusData = {
    health = 100,
    armor = 0,
    hunger = 100,
    thirst = 100,
    stamina = 100,
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
        local sleep = 500 -- Actualizar cada 500ms
        
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
            
            -- STAMINA
            statusData.stamina = 100 - GetPlayerSprintStaminaRemaining(PlayerId())
            if statusData.stamina < 0 then statusData.stamina = 0 end
            if statusData.stamina > 100 then statusData.stamina = 100 end
            
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
            
            -- TEMPERATURA (simulada - puedes integrar un sistema real)
            if Config.UseTemperature then
                statusData.temperature = Config.TemperatureDefault
            end
            
            -- Enviar datos al NUI
            SendNUIMessage({
                action = "updateStats",
                data = {
                    health = statusData.health,
                    armor = statusData.armor,
                    thirst = statusData.thirst,
                    hunger = statusData.hunger,
                    stamina = statusData.stamina,
                    temperature = statusData.temperature,
                    showArmor = Config.ShowArmor and statusData.armor > 0
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
            
            -- Mostrar/ocultar minimapa según tenga GPS y esté en vehículo
            local shouldShowMinimap = hasGPS and inVehicle
            
            if shouldShowMinimap ~= minimapEnabled then
                minimapEnabled = shouldShowMinimap
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

exports('GetStamina', function()
    return statusData.stamina
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