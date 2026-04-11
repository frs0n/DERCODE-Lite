
//#define RAYTRACED_REFRACTION
//#define REFRACTIVE_DISPERSION

// ============================================================================
// УЛУЧШЕННАЯ РЕФРАКЦИЯ С DEPTH-AWARE DISTORTION
// ============================================================================

vec3 fastRefract(in vec3 dir, in vec3 normal, in float eta) {
    float NdotD = dot(normal, dir);
    float k = 1.0 - eta * eta * oneMinus(NdotD * NdotD);
    if (k < 0.0) return vec3(0.0);

    return dir * eta - normal * (sqrt(k) + NdotD * eta);
}

#ifdef RAYTRACED_REFRACTION

#define RAYTRACE_SAMPLES 32 // [4 8 12 16 24 32 48 64 128 256 512] - Увеличено до 32

bool ScreenSpaceRayTrace(in vec3 viewPos, in vec3 viewDir, in float dither, in uint steps, inout vec3 rayPos) {
    const float maxLength = 1.0 / steps;
    const float minLength = length(screenPixelSize);

    vec3 position = ViewToScreenSpace(viewDir * abs(viewPos.z) + viewPos);
    vec3 screenDir = normalize(position - rayPos);
    float stepWeight = 1.0 / abs(screenDir.z);

    float stepLength = minOf((step(0.0, screenDir) - rayPos) / screenDir) * rcp(steps);

    screenDir.xy *= screenSize;
    rayPos.xy *= screenSize;

    vec3 rayStep = screenDir * stepLength;
    
    // Улучшенный dithering для рефракции
    float stabilizedDither = fract(dither + frameTimeCounter * 0.08);
    rayPos += rayStep * stabilizedDither + screenDir * minLength;

    // Более точный tolerance для рефракции
    float depthTolerance = max(abs(rayStep.z) * 2.0, 0.012 / sqr(viewPos.z));

    for (uint i = 0u; i < steps; ++i) {
        if (clamp(rayPos.xy, vec2(0.0), screenSize) != rayPos.xy) break;
        if (rayPos.z >= 1.0) break;

        float depth = texelFetch(depthtex1, ivec2(rayPos.xy), 0).x;
        stepLength = abs(depth - rayPos.z) * stepWeight;
        rayPos += screenDir * clamp(stepLength, minLength, maxLength);

        if (depth < rayPos.z && abs(depthTolerance - (rayPos.z - depth)) < depthTolerance) {
            return true;
        }
    }

    return false;
}

vec2 CalculateRefractCoord(in TranslucentMask mask, in vec3 normal, in vec3 viewDir, in vec3 viewPos, in float depth, in float ior) {
	if (!mask.translucent) return screenCoord;

	vec3 refractedDir = fastRefract(viewDir, normal, 1.0 / ior);

    vec3 hitPos = vec3(screenCoord, depth);
	if (ScreenSpaceRayTrace(viewPos, refractedDir, InterleavedGradientNoiseTemporal(gl_FragCoord.xy), RAYTRACE_SAMPLES, hitPos)) {
		hitPos.xy *= screenPixelSize;
	} else {
		hitPos.xy = ViewToScreenSpace(viewPos + refractedDir * 0.5).xy;
	}

	return saturate(hitPos.xy);
}

#else

#include "/lib/Water/WaterWave.glsl"

// ============================================================================
// УЛУЧШЕННАЯ NON-RAYTRACED РЕФРАКЦИЯ
// ============================================================================

vec2 CalculateRefractCoord(in TranslucentMask mask, in vec3 normal, in vec3 worldPos, in vec3 viewPos, in float depth, in float depthT) {
	if (!mask.translucent) return screenCoord;

	vec2 refractCoord;
	float waterDepth = GetDepthLinear(depthT);
	float refractionDepth = GetDepthLinear(depth) - waterDepth;

	if (mask.water) {
        worldPos += cameraPosition;
		vec3 wavesNormal = GetWavesNormal(worldPos.xz - worldPos.y).xzy;
		vec3 waterNormal = mat3(gbufferModelView) * wavesNormal;
		vec3 wavesNormalView = normalize(waterNormal);

		vec3 nv = normalize(gbufferModelView[1].xyz);

		// УЛУЧШЕННАЯ РЕФРАКЦИЯ: более точный расчет с учетом глубины
		refractCoord = nv.xy - wavesNormalView.xy;
		
		// Увеличенная сила рефракции в зависимости от глубины
		float depthFactor = saturate(refractionDepth);
		float refractionStrength = 0.65; // Увеличено с 0.5
		
		// Нелинейная зависимость от глубины для более реалистичного эффекта
		depthFactor = sqrt(depthFactor);
		
		refractCoord *= depthFactor * refractionStrength / (waterDepth + 1e-4);
		
		// Добавляем chromatic aberration для рефракции
		#ifdef REFRACTIVE_DISPERSION
			vec2 chromaticOffset = refractCoord * 0.015;
			vec2 refractCoordR = screenCoord + refractCoord + chromaticOffset;
			vec2 refractCoordG = screenCoord + refractCoord;
			vec2 refractCoordB = screenCoord + refractCoord - chromaticOffset;
			
			// Проверяем depth для всех каналов
			float refractDepthR = texture(depthtex1, refractCoordR).x;
			float refractDepthG = texture(depthtex1, refractCoordG).x;
			float refractDepthB = texture(depthtex1, refractCoordB).x;
			
			if (refractDepthR < depthT || refractDepthG < depthT || refractDepthB < depthT) {
				return screenCoord;
			}
			
			// Возвращаем средний координат (можно настроить)
			refractCoord = refractCoordG;
		#else
			refractCoord += screenCoord;
		#endif
	} else {
		// Рефракция для стекла
		vec3 refractDir = fastRefract(normalize(viewPos), normal, 1.0 / GLASS_REFRACT_IOR);
		refractDir /= saturate(dot(refractDir, -normal));
		
		// Увеличенная сила рефракции для стекла
		float glassRefractionStrength = 0.35; // Увеличено с 0.25
		refractDir *= saturate(refractionDepth * 2.0) * glassRefractionStrength;

		refractCoord = ViewToScreenSpace(viewPos + refractDir).xy;
	}

	// Проверка depth
	float refractDepth = texture(depthtex1, refractCoord).x;
	if (refractDepth < depthT) return screenCoord;

	return saturate(refractCoord);
}

#if defined DISTANT_HORIZONS
	vec2 CalculateRefractCoordDH(in TranslucentMask mask, in vec3 normal, in vec3 worldPos, in vec3 viewPos, in float depth, in float depthT) {
		if (!mask.translucent) return screenCoord;

		vec2 refractCoord;
		float waterDepth = GetDepthLinearDH(depthT);
		float refractionDepth = GetDepthLinearDH(depth) - waterDepth;

		if (mask.water) {
			worldPos += cameraPosition;
			vec3 wavesNormal = GetWavesNormal(worldPos.xz - worldPos.y).xzy;
			vec3 waterNormal = mat3(gbufferModelView) * wavesNormal;
			vec3 wavesNormalView = normalize(waterNormal);

			vec3 nv = normalize(gbufferModelView[1].xyz);

			// УЛУЧШЕННАЯ РЕФРАКЦИЯ для DH
			refractCoord = nv.xy - wavesNormalView.xy;
			
			float depthFactor = saturate(refractionDepth);
			float refractionStrength = 0.65;
			depthFactor = sqrt(depthFactor);
			
			refractCoord *= depthFactor * refractionStrength / (waterDepth + 1e-4);
			refractCoord += screenCoord;
		} else {
			vec3 refractDir = fastRefract(normalize(viewPos), normal, 1.0 / GLASS_REFRACT_IOR);
			refractDir /= saturate(dot(refractDir, -normal));
			refractDir *= saturate(refractionDepth * 2.0) * 0.35;

			refractCoord = ViewToScreenSpaceDH(viewPos + refractDir).xy;
		}

		float refractDepth = texture(dhDepthTex1, refractCoord).x;
		if (refractDepth < depthT) return screenCoord;

		return saturate(refractCoord);
	}
#endif

#endif
