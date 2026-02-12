// Colores configurables
let colors = {
    voice: {r: 255, g: 255, b: 255},
    stamina: {r: 76, g: 175, b: 80},  // NUEVO
    temperature: {r: 255, g: 152, b: 0},
    thirst: {r: 3, g: 169, b: 244},
    hunger: {r: 255, g: 193, b: 7},
    armor: {r: 33, g: 150, b: 243},
    health: {r: 244, g: 67, b: 54}
};

// Elementos DOM
const voiceStat = document.getElementById('voice-stat');
const temperatureStat = document.getElementById('temperature-stat');
const thirstStat = document.getElementById('thirst-stat');
const hungerStat = document.getElementById('hunger-stat');
const armorStat = document.getElementById('armor-stat');
const healthStat = document.getElementById('health-stat');
const staminaStat = document.getElementById('stamina-stat');
// Vehicle elements
const vehicleHud = document.getElementById('vehicle-hud');
const speedValue = document.getElementById('speed-value');
const fuelBar = document.getElementById('fuel-bar');
const engineBar = document.getElementById('engine-bar');
const beltIcon = document.getElementById('belt-icon');
const lockIcon = document.getElementById('lock-icon');

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
    
    // Agregar clase crítica si es menor a 25%
    if (percentage <= 25) {
        element.classList.add('critical');
    } else {
        element.classList.remove('critical');
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
function updateVoiceIndicator(mode, isTalking) {
    const voiceText = document.getElementById('voice-text');
    const voiceStat = document.getElementById('voice-stat');
    
    if (!voiceText || !voiceStat) return;
    
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
    voiceStat.classList.remove('whisper', 'normal', 'shout', 'talking');
    
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
        // Asegurar que 0% sea realmente 0
        const engineWidth = Math.max(0, Math.min(100, data.engine));
        engineBar.style.width = engineWidth + '%';
        
        // Si está en 0, ocultar completamente
        if (engineWidth === 0) {
            engineBar.style.opacity = '0';
        } else {
            engineBar.style.opacity = '1';
        }
        
        // Cambiar color según estado
        engineBar.classList.remove('damaged', 'critical');
        if (data.engine <= 30) {
            engineBar.classList.add('critical'); // Rojo <= 30%
        } else if (data.engine <= 40) {
            engineBar.classList.add('damaged'); // Amarillo <= 40%
        }
        // Blanco si > 40%
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
    
    // STAMINA - NUEVO
    updateStatFill(staminaStat, data.stamina, 'stamina');
    
    // TEMPERATURA
    updateStatFill(temperatureStat, (data.temperature / 40) * 100, 'temperature');
}

// Inicialización
document.addEventListener('DOMContentLoaded', () => {
    console.log('AX_hud - Stats System Loaded');
});