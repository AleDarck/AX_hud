// Colores configurables
let colors = {
    voice: {r: 255, g: 255, b: 255},
    stress: {r: 156, g: 39, b: 176},
    oxygen: {r: 3, g: 169, b: 244},
    temperature: {r: 255, g: 152, b: 0},
    thirst: {r: 3, g: 169, b: 244},
    hunger: {r: 255, g: 193, b: 7},
    armor: {r: 33, g: 150, b: 243},
    health: {r: 244, g: 67, b: 54},
    pee: {r: 255, g: 235, b: 59},        // NUEVO
    defecate: {r: 121, g: 85, b: 72}    // NUEVO
};

// Elementos DOM
const voiceStat = document.getElementById('voice-stat');
const temperatureStat = document.getElementById('temperature-stat');
const thirstStat = document.getElementById('thirst-stat');
const hungerStat = document.getElementById('hunger-stat');
const armorStat = document.getElementById('armor-stat');
const healthStat = document.getElementById('health-stat');
const stressStat = document.getElementById('stress-stat');
const oxygenStat = document.getElementById('oxygen-stat');
const staminaBarContainer = document.getElementById('stamina-bar-container');
const staminaBarFill = document.getElementById('stamina-bar-fill');
const peeStat = document.getElementById('pee-stat');
const defecateStat = document.getElementById('defecate-stat');
// Vehicle elements
const vehicleHud = document.getElementById('vehicle-hud');
const speedValue = document.getElementById('speed-value');
const fuelBar = document.getElementById('fuel-bar');
const engineBar = document.getElementById('engine-bar');
const beltIcon = document.getElementById('belt-icon');
const lockIcon = document.getElementById('lock-icon');
// Location elements
const locationDisplay = document.getElementById('location-display');
const locationZone = document.getElementById('location-zone');
const locationStreet = document.getElementById('location-street');
// Weapon elements
const weaponHud = document.getElementById('weapon-hud');
const weaponIcon = document.getElementById('weapon-icon');
const weaponName = document.getElementById('weapon-name');
const weaponAmmoCurrent = document.getElementById('weapon-ammo-current');
const weaponAmmoTotal = document.getElementById('weapon-ammo-total');
const weaponAmmoBar = document.getElementById('weapon-ammo-bar');

// Función para convertir RGB a Hue
function rgbToHue(r, g, b) {
    r /= 255;
    g /= 255;
    b /= 255;
    
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    const delta = max - min;
    
    let hue = 0;
    
    if (delta !== 0) {
        if (max === r) {
            hue = ((g - b) / delta) % 6;
        } else if (max === g) {
            hue = (b - r) / delta + 2;
        } else {
            hue = (r - g) / delta + 4;
        }
        hue = Math.round(hue * 60);
        if (hue < 0) hue += 360;
    }
    
    return hue;
}

// Función para calcular saturación
function rgbToSaturation(r, g, b) {
    r /= 255;
    g /= 255;
    b /= 255;
    
    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    const delta = max - min;
    
    if (max === 0) return 0;
    
    return Math.round((delta / max) * 100);
}

// Función para actualizar el relleno de un icono
function updateStatFill(element, percentage, colorKey) {
    const fillContainer = element.querySelector('.icon-fill');
    
    if (!fillContainer) return;
    
    // Obtener altura actual
    const currentHeight = parseFloat(fillContainer.style.height) || 0;
    
    // Animar gradualmente
    animateValue(fillContainer, currentHeight, percentage);
    
    // Lógica especial para pee y defecate (INVERSO - crítico cuando es ALTO)
    if (colorKey === 'pee' || colorKey === 'defecate') {
        // Ocultar si está por debajo del 25%
        if (percentage < 25) {
            element.classList.add('hidden');
            element.classList.remove('critical', 'warning', 'caution');
        } else {
            element.classList.remove('hidden');
            
            // Remover todas las clases primero
            element.classList.remove('critical', 'warning', 'caution');
            
            // Aplicar clases según el nivel (INVERSO)
            if (percentage >= 90) {
                element.classList.add('critical'); // Parpadeo rojo >= 90%
            } else if (percentage >= 85) {
                element.classList.add('warning'); // Rojo sin parpadeo >= 85%
            } else if (percentage >= 50) {
                element.classList.add('caution'); // Amarillo/café >= 50%
            }
            // Entre 25-49% mantiene color original
        }
    }
    // Lógica especial para stress (crítico cuando es ALTO, no bajo)
    else if (colorKey === 'stress') {
        if (percentage >= 75) {
            element.classList.add('critical');
        } else {
            element.classList.remove('critical');
        }
    }
    // Para el resto (health, hunger, thirst, oxygen) crítico cuando es BAJO
    else {
        if (percentage <= 25) {
            element.classList.add('critical');
        } else {
            element.classList.remove('critical');
        }
    }
}

// Función de animación suave
function animateValue(element, start, end) {
    const duration = 300; // ms
    const startTime = performance.now();
    
    function update(currentTime) {
        const elapsed = currentTime - startTime;
        const progress = Math.min(elapsed / duration, 1);
        
        // Easing suave
        const easeProgress = progress < 0.5 
            ? 2 * progress * progress 
            : -1 + (4 - 2 * progress) * progress;
        
        const current = start + (end - start) * easeProgress;
        element.style.height = current + '%';
        
        if (progress < 1) {
            requestAnimationFrame(update);
        }
    }
    
    requestAnimationFrame(update);
}

// Actualizar indicador de voz
function updateVoiceIndicator(mode, isTalking, isRadio) {
    const voiceText = document.getElementById('voice-text');
    const voiceStat = document.getElementById('voice-stat');
    
    if (!voiceText || !voiceStat) return;
    
    // Si está hablando por radio, override todo
    if (isRadio || mode === -1) {
        voiceText.textContent = 'RADIO';
        voiceStat.classList.remove('whisper', 'normal', 'shout', 'talking');
        voiceStat.classList.add('radio');
        
        if (isTalking) {
            voiceStat.classList.add('talking');
        }
        return;
    }
    
    // Mapeo de modos (debe coincidir con Config.VoiceLabels en Lua)
    const modeLabels = {
        1: 'SUSURRAR',
        2: 'NORMAL',
        3: 'GRITAR'
    };
    
    const modeClasses = {
        1: 'whisper',
        2: 'normal',
        3: 'shout'
    };
    
    // Actualizar texto
    voiceText.textContent = modeLabels[mode] || 'NORMAL';
    
    // Remover clases previas
    voiceStat.classList.remove('whisper', 'normal', 'shout', 'radio', 'talking');
    
    // Agregar clase de modo
    voiceStat.classList.add(modeClasses[mode] || 'normal');
    
    // Agregar clase si está hablando
    if (isTalking) {
        voiceStat.classList.add('talking');
    }
}

// Mostrar/ocultar HUD de vehículo
function showVehicleHUD(state) {
    if (!vehicleHud) return;
    
    if (state) {
        vehicleHud.classList.remove('hidden');
    } else {
        vehicleHud.classList.add('hidden');
    }
}

// Actualizar datos del vehículo
function updateVehicle(data) {
    // VELOCIDAD
    if (speedValue) {
        const speedStr = data.speed.toString().padStart(3, '0');
        speedValue.textContent = speedStr;
        
        // Cambiar color según velocidad
        if (data.speed > 0) {
            speedValue.classList.add('active');
        } else {
            speedValue.classList.remove('active');
        }
    }
    
    // COMBUSTIBLE
    if (fuelBar) {
        fuelBar.style.width = data.fuel + '%';
        
        // Cambiar color si está bajo
        if (data.fuel <= 20) {
            fuelBar.classList.add('low');
        } else {
            fuelBar.classList.remove('low');
        }
    }
    
    // MOTOR
    if (engineBar) {
        // Redondear a entero y asegurar rango
        const engineWidth = Math.round(Math.max(0, Math.min(100, data.engine)));
        engineBar.style.width = engineWidth + '%';
        
        // Si está en 0 o muy cerca, forzar a 0
        if (engineWidth <= 1) {
            engineBar.style.width = '0%';
            engineBar.style.opacity = '0';
        } else {
            engineBar.style.opacity = '1';
        }
        
        // Cambiar color según estado
        engineBar.classList.remove('damaged', 'critical');
        if (engineWidth <= 30) {
            engineBar.classList.add('critical');
        } else if (engineWidth <= 40) {
            engineBar.classList.add('damaged');
        }
    }
    
    // CINTURÓN
    if (beltIcon) {
        if (data.belt) {
            beltIcon.classList.add('active');
        } else {
            beltIcon.classList.remove('active');
        }
    }
    
    // LLAVE (BLOQUEADO)
    if (lockIcon) {
        if (data.locked) {
            lockIcon.classList.add('active');
        } else {
            lockIcon.classList.remove('active');
        }
    }
}

// Escuchar mensajes desde Lua
window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch(data.action) {
        case 'setColors':
            setColors(data.colors);
            break;
            
        case 'updateStats':
            updateStats(data.data);
            break;
            
        case 'updateVoice':
            updateVoiceIndicator(data.voice, data.isTalking);
            break;

        case 'updateVoice':
            updateVoiceIndicator(data.voice, data.isTalking, data.isRadio);
            break;

        case 'toggleHUD':
            toggleHUD(data.state);
            break;

        case 'showVehicleHUD':
            showVehicleHUD(data.state);
            break;
            
        case 'updateVehicle':
            updateVehicle(data.data);
            break;

        case 'setColors':
            setColors(data.colors);
            break;

        case 'toggleMinimapFrame':
            toggleMinimapFrame(data.state);
            break;

        case 'setLogo':
            const logoImg = document.getElementById('logo-img');
            if (logoImg && data.url) {
                console.log('Loading logo from:', data.url); // Debug
                logoImg.src = data.url;
                logoImg.onerror = function() {
                    console.error('Failed to load logo');
                };
                logoImg.onload = function() {
                    console.log('Logo loaded successfully');
                };
            }
            break;

        case 'updateStamina':
            updateStaminaBar(data.stamina, data.inVehicle);
            break;

        case 'updateLocation':
            updateLocation(data.zone, data.street, data.inVehicle);
            break;

        case 'updateWeaponHUD':
            updateWeaponHUD(data.data);
            break;
            
        case 'hideWeaponHUD':
            hideWeaponHUD();
            break;
    }
});

function setColors(configColors) {
    // Convertir array RGB a objeto
    for (let key in configColors) {
        if (configColors[key] && configColors[key].length === 3) {
            colors[key] = {
                r: configColors[key][0],
                g: configColors[key][1],
                b: configColors[key][2]
            };
        }
    }
}

function toggleHUD(state) {
    const statsContainer = document.getElementById('stats-container');
    const serverLogo = document.getElementById('server-logo');
    
    if (state) {
        statsContainer.style.display = 'flex';
        if (serverLogo) serverLogo.style.display = 'block';
    } else {
        statsContainer.style.display = 'none';
        if (serverLogo) serverLogo.style.display = 'none';
    }
}

function updateStats(data) {
    // SALUD
    updateStatFill(healthStat, data.health, 'health');
    
    // ARMADURA
    if (data.showArmor) {
        armorStat.classList.remove('hidden');
        updateStatFill(armorStat, data.armor, 'armor');
    } else {
        armorStat.classList.add('hidden');
    }
    
    // SED
    updateStatFill(thirstStat, data.thirst, 'thirst');
    
    // HAMBRE
    updateStatFill(hungerStat, data.hunger, 'hunger');
    
    // ESTRÉS
    updateStatFill(stressStat, data.stress, 'stress');

    // PEE
    updateStatFill(peeStat, data.pee, 'pee');

    // DEFECATE
    updateStatFill(defecateStat, data.defecate, 'defecate');
        
    // OXÍGENO (solo mostrar si está bajo el agua)
    if (data.isUnderwater) {
        oxygenStat.classList.remove('hidden');
        updateStatFill(oxygenStat, data.oxygen, 'oxygen');
    } else {
        oxygenStat.classList.add('hidden');
    }

    // STAMINA (barra horizontal)
    if (data.stamina !== undefined) {
        staminaBarFill.style.width = data.stamina + '%';
        
        // Añadir animación si está baja
        if (data.stamina <= 25) {
            staminaBarFill.setAttribute('data-low', 'true');
        } else {
            staminaBarFill.removeAttribute('data-low');
        }
    }

    // Ocultar stamina si está en vehículo
    if (data.inVehicle !== undefined) {
        if (data.inVehicle) {
            staminaBarContainer.classList.add('hidden');
        } else {
            staminaBarContainer.classList.remove('hidden');
        }
    }
    
    // TEMPERATURA
    updateStatFill(temperatureStat, (data.temperature / 40) * 100, 'temperature');
}

function toggleMinimapFrame(state) {
    const frame = document.getElementById('minimap-frame');
    if (!frame) return;
    
    if (state) {
        frame.classList.remove('hidden');
    } else {
        frame.classList.add('hidden');
    }
}

function updateStaminaBar(stamina, inVehicle) {
    if (!staminaBarFill || !staminaBarContainer) return;
    
    staminaBarFill.style.width = stamina + '%';
    
    // Añadir animación si está baja
    if (stamina <= 25) {
        staminaBarFill.setAttribute('data-low', 'true');
    } else {
        staminaBarFill.removeAttribute('data-low');
    }
    
    // Ocultar si está en vehículo
    if (inVehicle) {
        staminaBarContainer.classList.add('hidden');
    } else {
        staminaBarContainer.classList.remove('hidden');
    }
}

function updateLocation(zone, street, inVehicle) {
    if (!locationDisplay || !locationZone || !locationStreet) return;
    
    // Actualizar textos
    if (zone) locationZone.textContent = zone;
    if (street) locationStreet.textContent = street;
    
    // Ocultar si está en vehículo
    if (inVehicle) {
        locationDisplay.classList.add('hidden');
    } else {
        locationDisplay.classList.remove('hidden');
    }
    
    // NUEVO: Mover marco del minimapa
    updateMinimapFrame(inVehicle);
}

function updateMinimapFrame(inVehicle) {
    const frame = document.getElementById('minimap-frame');
    if (!frame) return;
    
    if (inVehicle) {
        // Posición en vehículo (ajusta según tus coordenadas)
        frame.style.bottom = '175px';
        frame.style.left = '86px';
    } else {
        // Posición a pie
        frame.style.bottom = '155px';
        frame.style.left = '74px';
    }
}

function updateWeaponHUD(data) {
    if (!weaponHud) return;
    
    // Mostrar HUD
    weaponHud.classList.remove('hidden');
    
    // Actualizar icono del arma
    if (weaponIcon && data.weaponItem) {
        // Resetear el error handler antes de cambiar src
        weaponIcon.onerror = null;
        
        // Intentar primero con minúsculas
        let imagePath = `nui://ox_inventory/web/images/${data.weaponItem}.png`;
        
        weaponIcon.onerror = function() {
            // Si falla minúsculas, intentar mayúsculas
            const upperItem = data.weaponItem.toUpperCase();
            weaponIcon.onerror = function() {
                // Si también falla mayúsculas, usar imagen por defecto
                weaponIcon.onerror = null; // Evitar loop infinito
                weaponIcon.src = 'icons/weapon_default.png';
            };
            weaponIcon.src = `nui://ox_inventory/web/images/${upperItem}.png`;
        };
        
        weaponIcon.src = imagePath;
    }
    
    // Actualizar nombre
    if (weaponName) {
        weaponName.textContent = data.weaponName || 'WEAPON';
    }
    
    // Actualizar munición
    if (!data.isMelee) {
        if (weaponAmmoCurrent) {
            weaponAmmoCurrent.textContent = data.ammoInClip || 0;
            
            // Añadir clase "low" si la munición es baja
            if (data.maxClipAmmo > 0 && data.ammoInClip <= (data.maxClipAmmo * 0.25)) {
                weaponAmmoCurrent.classList.add('low');
            } else {
                weaponAmmoCurrent.classList.remove('low');
            }
        }
        
        if (weaponAmmoTotal) {
            weaponAmmoTotal.textContent = data.totalAmmo || 0;
        }
        
        // Actualizar barra de munición
        if (weaponAmmoBar && data.maxClipAmmo > 0) {
            const percentage = (data.ammoInClip / data.maxClipAmmo) * 100;
            weaponAmmoBar.style.width = percentage + '%';
            
            // Añadir clase "low" si está baja
            if (percentage <= 25) {
                weaponAmmoBar.classList.add('low');
            } else {
                weaponAmmoBar.classList.remove('low');
            }
        }
    } else {
        // Si es cuerpo a cuerpo, ocultar munición
        if (weaponAmmoCurrent) weaponAmmoCurrent.textContent = '-';
        if (weaponAmmoTotal) weaponAmmoTotal.textContent = '-';
        if (weaponAmmoBar) weaponAmmoBar.style.width = '0%';
    }
}

function hideWeaponHUD() {
    if (weaponHud) {
        weaponHud.classList.add('hidden');
    }
}

// Inicialización
document.addEventListener('DOMContentLoaded', () => {
    console.log('AX_hud - Stats System Loaded');
});