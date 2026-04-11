// Parallax Occlusion Mapping для labPBR 1.3+ и SEUS PTGI
// Поддержка OM (Occlusion Mapping) и Height Map
// С процедурной генерацией нормалей (IPBR-style)

// Дефайны по умолчанию (если не заданы в shaders.properties)
#ifndef PARALLAX_SHADOW_SAMPLES
    #define PARALLAX_SHADOW_SAMPLES PARALLAX_SAMPLES
#endif

#ifndef PARALLAX_SHADOW_STRENGTH
    #define PARALLAX_SHADOW_STRENGTH 0.8
#endif

#ifndef PROCEDURAL_NORMALS_STRENGTH
    #define PROCEDURAL_NORMALS_STRENGTH 0.5
#endif

// ========================================
// ПРОЦЕДУРНАЯ ГЕНЕРАЦИЯ НОРМАЛЕЙ (IPBR)
// ========================================

// Улучшенный шум для процедурных нормалей
float hash(vec2 p) {
    p = fract(p * vec2(443.8975, 397.2973));
    p += dot(p.xy, p.yx + 19.19);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // Hermite interpolation
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// FBM (Fractional Brownian Motion) для детализации
float fbm(vec2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    
    return value;
}

// Генерация процедурной heightmap из albedo
float GenerateProceduralHeight(in vec2 coord, in vec3 albedo, in uint materialID) {
    float baseHeight = 0.5;
    
    // Используем яркость текстуры как основу
    float luminance = dot(albedo, vec3(0.299, 0.587, 0.114));
    
    // Масштабированные координаты
    vec2 scaledCoord = coord * 16.0;
    
    // Базовый шум (детали текстуры)
    float noiseBase = fbm(scaledCoord, 3);
    
    // Детальный шум (микро-детали)
    float noiseDetail = fbm(scaledCoord * 4.0, 2) * 0.3;
    
    // Комбинируем с альбедо
    baseHeight = mix(noiseBase, luminance, 0.4);
    baseHeight += noiseDetail;
    
    // Специфичные настройки для разных материалов
    if (materialID >= 2068u && materialID <= 2076u) {
        // Деревянные доски - добавляем линии между досками
        float plankPattern = abs(fract(coord.y * 16.0) - 0.5) * 2.0;
        plankPattern = smoothstep(0.85, 1.0, plankPattern);
        baseHeight = mix(baseHeight, baseHeight * 0.3, plankPattern * 0.7);
        
        // Текстура древесины
        float woodGrain = fbm(vec2(coord.x * 32.0, coord.y * 8.0), 4) * 0.15;
        baseHeight += woodGrain;
    }
    else if (materialID >= 2012u && materialID <= 2055u) {
        // Медные блоки - более гладкие с окислением
        float oxidationNoise = fbm(scaledCoord * 2.0, 2) * 0.2;
        baseHeight = mix(baseHeight, baseHeight + oxidationNoise, 0.5);
    }
    else if (materialID == 2016u) {
        // Obsidian - очень гладкий с редкими трещинами
        float cracks = step(0.95, fbm(scaledCoord * 8.0, 4)) * 0.3;
        baseHeight = baseHeight * 0.5 + cracks;
    }
    else if (materialID == 2010u || materialID == 2022u || materialID == 2023u) {
        // Железо/двери - заклепки и детали
        float rivetPattern = step(0.92, noise(scaledCoord * 6.0)) * 0.4;
        baseHeight += rivetPattern;
    }
    else if (materialID == 10u || materialID == 21u) {
        // Снег/лёд - мягкие неровности
        baseHeight = fbm(scaledCoord * 2.0, 3) * 0.8;
    }
    
    return clamp(baseHeight, 0.0, 1.0);
}

// Генерация нормалей из heightmap
vec3 GenerateProceduralNormal(in vec2 coord, in vec3 albedo, in uint materialID) {
    float offset = 0.01; // Шаг для градиента
    
    // Сэмплируем высоту в 4 точках
    float heightC = GenerateProceduralHeight(coord, albedo, materialID);
    float heightR = GenerateProceduralHeight(coord + vec2(offset, 0.0), albedo, materialID);
    float heightU = GenerateProceduralHeight(coord + vec2(0.0, offset), albedo, materialID);
    
    // Вычисляем градиенты
    float dx = (heightR - heightC) / offset;
    float dy = (heightU - heightC) / offset;
    
    // Создаём нормаль
    vec3 proceduralNormal = normalize(vec3(-dx * PROCEDURAL_NORMALS_STRENGTH, 
                                           -dy * PROCEDURAL_NORMALS_STRENGTH, 
                                           1.0));
    
    return proceduralNormal;
}

// ========================================
// БИЛИНЕЙНАЯ ФИЛЬТРАЦИЯ (опционально)
// ========================================

#ifdef SMOOTH_PARALLAX
float BilinearHeightSample(in vec2 coord) {
    ivec2 tileOffset = ivec2(voxelCoord * tileScale);
    coord = coord * atlasSize - 0.5;
    ivec2 i = ivec2(floor(coord));
    vec2 f = fract(coord);
    
    // Сэмплируем 4 точки
    vec4 heights = vec4(
        texelFetch(normals, (i + ivec2(0, 1)) % atlasSize + tileOffset, 0).a,
        texelFetch(normals, (i + ivec2(1, 1)) % atlasSize + tileOffset, 0).a,
        texelFetch(normals, (i + ivec2(1, 0)) % atlasSize + tileOffset, 0).a,
        texelFetch(normals, (i + ivec2(0, 0)) % atlasSize + tileOffset, 0).a
    );
    
    // Обработка пустых высот
    heights = max(heights, vec4(1e-5));
    
    // Билинейная интерполяция
    vec2 h01 = mix(heights.wx, heights.zy, f.x);
    return mix(h01.x, h01.y, f.y);
}
#endif

// ========================================
// ОСНОВНОЙ POM АЛГОРИТМ
// ========================================

vec3 CalculateParallax(in vec3 tangentViewVector, in mat2 texGrad, in float dither) {
    // Версия без процедурных нормалей (для совместимости)
    vec3 offsetCoord = vec3(tileCoord, 1.0);
    float invViewZ = 1.0 / max(abs(tangentViewVector.z), 0.05);
    vec3 stepSize = vec3(tangentViewVector.xy * PARALLAX_DEPTH * invViewZ, -1.0);
    stepSize /= float(PARALLAX_SAMPLES);
    offsetCoord += stepSize * dither;
    
    #ifdef PARALLAX_REFINEMENT
    int refinementCount = 0;
    float lastHeight = 1.0;
    #endif
    
    for (uint i = 0u; i < PARALLAX_SAMPLES; ++i) {
        #ifdef SMOOTH_PARALLAX
            float sampleHeight = BilinearHeightSample(OffsetCoord(offsetCoord.xy));
        #else
            float sampleHeight = textureGrad(normals, OffsetCoord(offsetCoord.xy), texGrad[0], texGrad[1]).a;
        #endif
        
        if (sampleHeight > offsetCoord.z) {
            #ifdef PARALLAX_REFINEMENT
                if (refinementCount < PARALLAX_REFINEMENT_STEPS) {
                    offsetCoord -= stepSize;
                    stepSize *= 0.5;
                    refinementCount++;
                    continue;
                } else {
                    float delta = (offsetCoord.z - sampleHeight) / (stepSize.z + lastHeight - sampleHeight);
                    offsetCoord -= stepSize * clamp(delta, 0.0, 1.0);
                    break;
                }
            #else
                break;
            #endif
        }
        
        #ifdef PARALLAX_REFINEMENT
        lastHeight = sampleHeight;
        #endif
        
        offsetCoord += stepSize;
    }
    
    return offsetCoord;
}

// Версия с процедурными нормалями
vec3 CalculateParallaxProcedural(in vec3 tangentViewVector, in mat2 texGrad, in float dither, 
                                 in vec3 albedo, in uint materialID) {
    // Инициализация
    vec3 offsetCoord = vec3(tileCoord, 1.0);
    
    // Нормализация шага по Z
    float invViewZ = 1.0 / max(abs(tangentViewVector.z), 0.05);
    
    // Базовый шаг
    vec3 stepSize = vec3(tangentViewVector.xy * PARALLAX_DEPTH * invViewZ, -1.0);
    stepSize /= float(PARALLAX_SAMPLES);
    
    // Dithering для сглаживания
    offsetCoord += stepSize * dither;
    
    #ifdef PARALLAX_REFINEMENT
    int refinementCount = 0;
    float lastHeight = 1.0;
    #endif
    
    // Проверяем наличие height map в текстуре
    float testHeight = textureGrad(normals, OffsetCoord(tileCoord), texGrad[0], texGrad[1]).a;
    bool hasHeightMap = (testHeight > 1e-3 && testHeight < 0.999);
    
    // Ray marching
    for (uint i = 0u; i < PARALLAX_SAMPLES; ++i) {
        float sampleHeight;
        
        // Выбираем источник высоты
        if (hasHeightMap) {
            #ifdef SMOOTH_PARALLAX
                sampleHeight = BilinearHeightSample(OffsetCoord(offsetCoord.xy));
            #else
                sampleHeight = textureGrad(normals, OffsetCoord(offsetCoord.xy), texGrad[0], texGrad[1]).a;
            #endif
        } else {
            // Используем процедурную генерацию
            sampleHeight = GenerateProceduralHeight(offsetCoord.xy, albedo, materialID);
        }
        
        // Проверка пересечения
        if (sampleHeight > offsetCoord.z) {
            #ifdef PARALLAX_REFINEMENT
                // Binary search refinement
                if (refinementCount < PARALLAX_REFINEMENT_STEPS) {
                    offsetCoord -= stepSize;
                    stepSize *= 0.5;
                    refinementCount++;
                    continue;
                } else {
                    // Линейная интерполяция
                    float delta = (offsetCoord.z - sampleHeight) / (stepSize.z + lastHeight - sampleHeight);
                    offsetCoord -= stepSize * clamp(delta, 0.0, 1.0);
                    break;
                }
            #else
                break;
            #endif
        }
        
        #ifdef PARALLAX_REFINEMENT
        lastHeight = sampleHeight;
        #endif
        
        offsetCoord += stepSize;
    }
    
    return offsetCoord;
}

// ========================================
// PARALLAX SELF-SHADOWING
// ========================================

#ifdef PARALLAX_SHADOW
float CalculateParallaxShadow(in vec3 tangentLightVector, in vec3 offsetCoord, in mat2 texGrad, in float dither) {
    // Оригинальная логика из твоего кода
    float parallaxShadow = 1.0;
    
    vec3 stepSize = vec3(tangentLightVector.xy, 1.0) * offsetCoord.z * rcp(PARALLAX_SAMPLES);
    stepSize.xy *= PARALLAX_DEPTH * rcp(tangentLightVector.z);
    stepSize *= 2.0 / PARALLAX_SAMPLES;
    
    offsetCoord += stepSize * dither;
    for (uint i = 1u; i < PARALLAX_SAMPLES; ++i) {
        offsetCoord += stepSize * i;
        
        #ifdef SMOOTH_PARALLAX
            float sampleHeight = BilinearHeightSample(OffsetCoord(offsetCoord.xy));
        #else
            float sampleHeight = textureGrad(normals, OffsetCoord(offsetCoord.xy), texGrad[0], texGrad[1]).a;
        #endif
        
        parallaxShadow *= float(offsetCoord.z > sampleHeight);
        if (parallaxShadow < 1e-4) break;
    }
    
    return 1.0 - parallaxShadow;
}

// Версия с процедурными нормалями
float CalculateParallaxShadowProcedural(in vec3 tangentLightVector, in vec3 offsetCoord, in mat2 texGrad, 
                                        in float dither, in vec3 albedo, in uint materialID) {
    // Оригинальная логика из твоего кода
    float parallaxShadow = 1.0;
    
    vec3 stepSize = vec3(tangentLightVector.xy, 1.0) * offsetCoord.z * rcp(PARALLAX_SAMPLES);
    stepSize.xy *= PARALLAX_DEPTH * rcp(tangentLightVector.z);
    stepSize *= 2.0 / PARALLAX_SAMPLES;
    
    // Проверяем наличие height map
    float testHeight = textureGrad(normals, OffsetCoord(tileCoord), texGrad[0], texGrad[1]).a;
    bool hasHeightMap = (testHeight > 1e-3 && testHeight < 0.999);
    
    offsetCoord += stepSize * dither;
    for (uint i = 1u; i < PARALLAX_SAMPLES; ++i) {
        offsetCoord += stepSize * i;
        
        float sampleHeight;
        
        // Выбираем источник высоты
        if (hasHeightMap) {
            #ifdef SMOOTH_PARALLAX
                sampleHeight = BilinearHeightSample(OffsetCoord(offsetCoord.xy));
            #else
                sampleHeight = textureGrad(normals, OffsetCoord(offsetCoord.xy), texGrad[0], texGrad[1]).a;
            #endif
        } else {
            // Используем процедурную генерацию
            sampleHeight = GenerateProceduralHeight(offsetCoord.xy, albedo, materialID);
        }
        
        parallaxShadow *= float(offsetCoord.z > sampleHeight);
        if (parallaxShadow < 1e-4) break;
    }
    
    return 1.0 - parallaxShadow;
}
#endif
// ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
// ========================================

// Edge fading для избежания артефактов на краях
float GetParallaxEdgeFade(in vec2 coord) {
    vec2 edgeDist = min(coord, 1.0 - coord);
    float fade = min(edgeDist.x, edgeDist.y);
    return smoothstep(0.0, 0.05, fade);
}

// Применение процедурных нормалей к существующим
vec3 BlendNormals(in vec3 baseNormal, in vec3 proceduralNormal, in float strength) {
    // Reoriented Normal Mapping
    vec3 t = baseNormal;
    vec3 u = proceduralNormal;
    vec3 r = normalize(vec3(t.xy + u.xy, t.z * u.z));
    return normalize(mix(baseNormal, r, strength));
}

// Adaptive sampling (опционально)
#ifdef ADAPTIVE_PARALLAX
uint GetAdaptiveSamples(in float viewAngle) {
    float factor = 1.0 - abs(viewAngle);
    return uint(mix(float(PARALLAX_SAMPLES) * 0.5, float(PARALLAX_SAMPLES), factor));
}
#endif