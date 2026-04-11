
#define EMISSION_MODE 2 // [0 1 2]
#define EMISSION_BRIGHTNESS 1.0
#define EMISSIVE_ORES
float lightSourceMask = 1.0;
float albedoLuminance = length(albedo);
GetBlocklightFalloff(mcLightmap.r);

#if EMISSION_MODE < 2
vec3 EmissionColor = vec3(0.0);
switch (materialID) {
    case 27: break;
}
sceneData += EmissionColor * TORCHLIGHT_BRIGHTNESS;
#endif

#if EMISSION_MODE == 2
vec3 EmissionColor = vec3(0.0);
switch (materialID) {
    // Total glowing
    case 20: EmissionColor += albedoLuminance; lightSourceMask = 0.1; break;
   
    // Torch like
case 21:
#ifdef IS_END
    vec3 endLightColor = vec3(0.6, 0.2, 1.0) * (1.0 + 0.3 * sin(frameTimeCounter * 10.0));
    // Проверка на красный ИЛИ зелёный
    float redGlow = float(albedoRaw.r > 0.8 || albedoRaw.r > albedoRaw.g * 1.4);
    float greenGlow = float(albedoRaw.g > 0.8 || albedoRaw.g > albedoRaw.r * 1.4 && albedoRaw.g > albedoRaw.b * 1.4);
    EmissionColor += 6.0 * endLightColor * max(redGlow, greenGlow);
    lightSourceMask = 0.05;
#else
    // Проверка на красный ИЛИ зелёный
    float redGlow = float(albedoRaw.r > 0.8 || albedoRaw.r > albedoRaw.g * 1.4);
    float greenGlow = float(albedoRaw.g > 0.8 || albedoRaw.g > albedoRaw.r * 1.4 && albedoRaw.g > albedoRaw.b * 1.4);
    EmissionColor += 6.0 * blocklightColor * max(redGlow, greenGlow);
    lightSourceMask = 0.05;
#endif
break;
   
    // Fire
    case 22: case 15:
    #ifdef IS_END
        vec3 endFireColor = vec3(0.6, 0.2, 1.0) * (1.0 + 0.3 * sin(frameTimeCounter * 10.0));
        EmissionColor += 6.0 * endFireColor * cube(albedoLuminance);
        lightSourceMask = 0.1;
    #else
        EmissionColor += 6.0 * blocklightColor * cube(albedoLuminance);
        lightSourceMask = 0.1;
    #endif
    #ifdef IS_ENTITY
    if (gl_EntityID == 37) {
        vec3 enderFireColor = vec3(0.4, 0.1, 0.9) * (1.0 + 0.5 * sin(frameTimeCounter * 8.0));
        EmissionColor = mix(EmissionColor, enderFireColor * 7.0 * cube(albedoLuminance), 0.8);
        lightSourceMask = 0.05;
    }
    #endif
    break;
   
    // Glowstone like
// Glowstone like
case 23: 
{
    // Проверка на медные оттенки (телесные/коричневые цвета)
    float isCopper = float(
        albedoRaw.r > 0.4 && albedoRaw.r < 0.8 &&
        albedoRaw.g > 0.3 && albedoRaw.g < 0.6 &&
        albedoRaw.b > 0.2 && albedoRaw.b < 0.5 &&
        albedoRaw.r > albedoRaw.g * 1.1 &&
        albedoRaw.g > albedoRaw.b * 1.0
    );
    
    // Для меди - слабое свечение (0.3x), для остальных - нормальное (4.0x)
    float emissionStrength = mix(4.0, 0.3, isCopper);
    EmissionColor += emissionStrength * blocklightColor * cube(albedoLuminance);
    lightSourceMask = 0.05;
}
break;
   
    // Sea lantern like
    case 24: EmissionColor += 2.0 * cube(albedoLuminance); lightSourceMask = 0.0; break;
   
    // Redstone
    case 25:
        if (fract(worldPos.y + cameraPosition.y) > 0.18)
            EmissionColor += step(0.65, albedoRaw.r);
        else
            EmissionColor += step(1.25, albedo.r / (albedo.g + albedo.b)) * step(0.5, albedoRaw.r);
        EmissionColor *= vec3(2.1, 0.9, 0.9) * 8.0;
    break;
   
    // Soul fire
    case 26:
        vec3 soulLightColor = vec3(0.2, 0.6, 1.0) * (1.0 + 0.3 * sin(frameTimeCounter * 8.0));
        EmissionColor += 8.0 * soulLightColor * float(albedoRaw.b > 0.5 || albedoRaw.g > albedoRaw.r * 1.4);
        lightSourceMask = 0.03;
    break;


    case 59:
{
    // Проверка на фиолетовый
    float isPurple = float(albedoRaw.b > albedoRaw.r && albedoRaw.b > albedoRaw.g);
    
    // Проверка на зелёный
    float isGreen = float(albedoRaw.g > albedoRaw.r && albedoRaw.g > albedoRaw.b);
    
    // Анимация затухания
    float pulse = 0.75 + 0.25 * sin(frameTimeCounter * 2.0);
    
    // Фиолетовое свечение
    EmissionColor += isPurple * vec3(0.5, 0.2, 1.0) * pulse * 6.0 * cube(albedoLuminance);
    
    // Зелёное свечение
    EmissionColor += isGreen * vec3(0.3, 1.0, 0.4) * pulse * 5.0 * cube(albedoLuminance);
    
    lightSourceMask = 0.08;
}
break;

    

 case 80: case 81: case 82: case 83: case 84: case 85: case 86: case 87:
    {
        float pureYellow = float(albedoRaw.r > 0.76 && albedoRaw.g > 0.66 && albedoRaw.g < 0.90 && albedoRaw.b < 0.30 && albedoRaw.b > 0.10);
        float pureOrange = float(albedoRaw.r > 0.83 && albedoRaw.g > 0.46 && albedoRaw.g < 0.70 && albedoRaw.b < 0.23 && albedoRaw.b > 0.07);
        float lightMask = max(pureYellow, pureOrange);
        lightSourceMask = mix(1.0, 0.008, lightMask);
        
        vec3 lightColor = vec3(3.3, 2.5, 1.0);
        float flicker = 0.92 + 0.16 * sin(frameTimeCounter * 12.0);
        lightColor *= flicker;
        #ifdef IS_END
            lightColor = vec3(0.9, 0.5, 1.4) * flicker;
        #endif
        EmissionColor += 20.0 * lightColor * lightMask;
    }
    break;
    

    // Остальные блоки
    case 27: break;
    case 28: EmissionColor += saturate(dot(saturate(albedo - 0.1), vec3(1.0, -0.6, -0.99))) * vec3(28.0, 25.0, 21.0); lightSourceMask = 0.4; break;
    case 29: EmissionColor += vec3(2.1, 0.9, 0.9) * albedoLuminance * step(albedoRaw.g * 2.0 + albedoRaw.b, albedoRaw.r); break;
    case 30:
        vec3 midBlockPos = abs(fract(worldPos + cameraPosition) - 0.5);
        if (maxOf(midBlockPos) < 0.4 && albedo.b > 0.5)
            EmissionColor += 6.0 * albedoLuminance;
        lightSourceMask = 0.2;
    break;
    case 31:
        if (albedoRaw.b > 0.6) {
            float pulse = 1.0 + 0.5 * sin(frameTimeCounter * 12.0);
            vec3 sensorGlow = vec3(0.3, 0.6, 1.0) * pulse;
            EmissionColor += 5.0 * sensorGlow * pow(albedoLuminance, 2.0);
            lightSourceMask = 0.2;
        }
    break;
    case 32:
        if (albedoRaw.r > albedoRaw.b * 1.2)
            EmissionColor += 3.0;
        else
            EmissionColor += albedoLuminance * 0.1;
    break;
    case 33: EmissionColor += 30.0 * albedoLuminance * cube(saturate(albedo - 0.5)); lightSourceMask = 0.5; break;
    case 34:
        vec2 midBlockPosXZ = abs(fract(worldPos.xz + cameraPosition.xz) - 0.5);
        EmissionColor += step(maxOf(midBlockPosXZ), 0.063) * albedoLuminance;
    break;
    case 36:
        vec3 blockPos = fract(worldPos + cameraPosition);
        float edgeDist = max(max(abs(blockPos.x - 0.5), abs(blockPos.y - 0.5)), abs(blockPos.z - 0.5));
        float outlineStrength = smoothstep(0.45, 0.5, edgeDist);
        EmissionColor += albedoLuminance + 2.0 * outlineStrength * vec3(0.6, 0.2, 1.0);
        lightSourceMask = 0.05;
    break;


case 88: // chorus_plant - ВСЕ жёлтые/тёплые оттенки
{
    // Расширенная проверка на жёлтые, телесные, песочные, оранжевые оттенки
    float isWarmYellow = float(
        // Классический жёлтый
        (albedoRaw.r > 0.65 && albedoRaw.g > 0.55 && albedoRaw.b < 0.50 &&
         albedoRaw.r > albedoRaw.g * 0.95 && albedoRaw.g > albedoRaw.b * 1.3) ||
        
        // Песочный/бежевый
        (albedoRaw.r > 0.70 && albedoRaw.r < 0.95 &&
         albedoRaw.g > 0.60 && albedoRaw.g < 0.88 &&
         albedoRaw.b > 0.35 && albedoRaw.b < 0.65 &&
         albedoRaw.r > albedoRaw.g * 1.02) ||
        
        // Телесный/кремовый
        (albedoRaw.r > 0.75 && albedoRaw.g > 0.65 && 
         albedoRaw.b > 0.50 && albedoRaw.b < 0.75 &&
         albedoRaw.r > albedoRaw.g * 1.05) ||
        
        // Оранжевый
        (albedoRaw.r > 0.80 && albedoRaw.g > 0.40 && albedoRaw.g < 0.70 &&
         albedoRaw.b < 0.40 && albedoRaw.r > albedoRaw.g * 1.2) ||
        
        // Золотистый
        (albedoRaw.r > 0.75 && albedoRaw.g > 0.60 && 
         albedoRaw.b < 0.45 && albedoRaw.r > albedoRaw.g * 1.1)
    );
    
    // Тёплое золотистое свечение с лёгкой пульсацией
    float pulse = 0.85 + 0.15 * sin(frameTimeCounter * 3.0);
    vec3 warmGlow = vec3(1.0, 0.85, 0.4) * pulse;
    EmissionColor += 4.5 * warmGlow * cube(albedoLuminance) * isWarmYellow;
    lightSourceMask = 0.06;
}
break;



    
    // Ores
    case 51: case 57:
    {
        float isLapis = saturate((max(max(dot(albedoRaw, vec3(2.0, -1.0, -1.0)),
                                       dot(albedoRaw, vec3(-1.0, 2.0, -1.0))),
                                   dot(albedoRaw, vec3(-1.0, -1.0, 2.0))) - 0.1) * rcp(0.3));
        EmissionColor += LinearToSRGB(isLapis * (pow5(max0(albedoRaw - vec3(0.1))))) * 2.0;
        lightSourceMask = max(lightSourceMask, 0.15);
    }
    break;
    case 58:
    {
        float isEmerald = saturate(dot(albedoRaw, vec3(-20.0, 30.0, 10.0)));
        EmissionColor += LinearToSRGB(isEmerald * (cube(max0(albedoRaw - vec3(0.1))))) * 2.0;
        lightSourceMask = max(lightSourceMask, 0.15);
    }
    break;
    case 10033:
    {
        float isYellowChorus = saturate(dot(albedoRaw, vec3(1.0, 1.0, -2.0))) * step(albedoRaw.r, albedoRaw.g * 1.2) * step(albedoRaw.b, 0.3);
        vec3 yellowGlowColor = vec3(1.0, 0.9, 0.2) * (1.0 + 0.3 * sin(frameTimeCounter * 6.0));
        EmissionColor += 5.0 * yellowGlowColor * cube(albedoLuminance) * isYellowChorus;
        lightSourceMask = 0.005;
    }
    break;
    case 10025: case 10029:
        EmissionColor += vec3(material.emissiveness) * max(albedoLuminance, 0.15) * 3.0;
        lightSourceMask = max(lightSourceMask, 0.12);
        break;
   
    default: break;
}


sceneData += EmissionColor * TORCHLIGHT_BRIGHTNESS;
#endif

#if EMISSION_MODE > 0
sceneData += material.emissiveness * 1.5 * EMISSION_BRIGHTNESS;
#endif

#ifdef EMISSIVE_ORES
if (EMISSION_MODE != 2) {
    if (materialID == 51 || materialID == 57) {
        float isLapis = saturate((max(max(dot(albedoRaw, vec3(2.0, -1.0, -1.0)),
                                       dot(albedoRaw, vec3(-1.0, 2.0, -1.0))),
                                   dot(albedoRaw, vec3(-1.0, -1.0, 2.0))) - 0.1) * rcp(0.3));
        sceneData += LinearToSRGB(isLapis * (pow5(max0(albedoRaw - vec3(0.1))))) * 2.0;
    }
    if (materialID == 58) {
        float isNetherOre = saturate(dot(albedoRaw, vec3(-20.0, 30.0, 10.0)));
        sceneData += LinearToSRGB(isNetherOre * (cube(max0(albedoRaw - vec3(0.1))))) * 2.0;
    }
}
#endif

#if defined IS_NETHER
if (mcLightmap.r > 1e-5)
    sceneData += mcLightmap.r * (ao * oneMinus(mcLightmap.r) + mcLightmap.r) * 20.0 * blocklightColor * TORCHLIGHT_BRIGHTNESS * lightSourceMask * metalMask;
#else
if (mcLightmap.r > 1e-5)
    sceneData += mcLightmap.r * (ao * oneMinus(mcLightmap.r) + mcLightmap.r) * 2.0 * blocklightColor * TORCHLIGHT_BRIGHTNESS * lightSourceMask;
#endif

#ifdef HELD_TORCHLIGHT
if (heldBlockLightValue + heldBlockLightValue2 > 1e-3) {
    float falloff = rcp(dotSelf(worldPos) + 1.0);
    falloff *= fma(NdotV, 0.8, 0.2);
#if defined IS_NETHER
    sceneData += falloff * (ao * oneMinus(falloff) + falloff) * 2.0 * max(heldBlockLightValue, heldBlockLightValue2) * HELDLIGHT_BRIGHTNESS * blocklightColor * metalMask;
#else
    sceneData += falloff * (ao * oneMinus(falloff) + falloff) * 0.2 * max(heldBlockLightValue, heldBlockLightValue2) * HELDLIGHT_BRIGHTNESS * blocklightColor;
#endif
}
#endif

sceneData += float(materialID == 12) * 12.0 + float(materialID == 36) * 2.0 + float(materialID == 19) * albedoLuminance * 2e2;