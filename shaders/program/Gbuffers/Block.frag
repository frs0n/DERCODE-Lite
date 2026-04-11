layout(location = 0) out vec4 albedoData;
layout(location = 1) out vec3 colortex7Out;
layout(location = 2) out vec4 colortex3Out;

/* DRAWBUFFERS:673 */

#include "/lib/Head/Common.inc"
#include "/lib/Surface/ManualTBN.glsl"
#include "/Settings.glsl"

uniform sampler2D tex;
#ifdef MC_NORMAL_MAP
uniform sampler2D normals;
#endif
#ifdef MC_SPECULAR_MAP
uniform sampler2D specular;
#endif

uniform float frameTimeCounter;
uniform mat4 gbufferModelViewInverse;

in vec4 tint;
in vec2 texcoord;
in vec3 minecraftPos;
in vec4 viewPos;
in vec2 lightmap;
flat in int materialIDs;

#define PROGRAM_GBUFFERS_BLOCK
#ifndef RAIN_SPLASH_EFFECT
#undef PROGRAM_GBUFFERS_BLOCK
#endif

#if defined IS_OVERWORLD
uniform sampler2D noisetex;
uniform sampler2D colortex7;
uniform float wetnessCustom;
#include "/lib/Surface/RainEffect.glsl"
#endif

mat2 mat2RotateZ(in float radian) {
    return mat2(cos(radian), -sin(radian), sin(radian), cos(radian));
}

vec2 endPortalLayer(in vec2 coord, in float layer) {
    vec2 offset = vec2(8.5 / layer, (1.0 + layer / 3.0) * (frameTimeCounter * 0.0015)) + 0.25;
    mat2 rotate = mat2RotateZ(radians(layer * layer * 8642.0 + layer * 18.0));
    return (4.5 - layer / 4.0) * (rotate * coord) + offset;
}

float bayer2(vec2 a) { a = 0.5 * floor(a); return fract(1.5 * fract(a.y) + a.x); }
#define bayer4(a) (bayer2(0.5 * (a)) * 0.25 + bayer2(a))

// === Функция для определения деталей ===
float detectDetails(vec3 albedo) {
    float brightness = dot(albedo.rgb, vec3(0.299, 0.587, 0.114));
    
    if (brightness < 0.25) return 1.0;
    if (brightness < 0.35) return 0.7;
    
    float contrast = abs(brightness - 0.5);
    if (contrast > 0.25 && brightness < 0.4) return 0.5;
    
    return 0.0;
}

// === Функция для определения чистоты меди ===
float detectCopperPurity(vec3 albedo) {
    float copperScore = albedo.r * (1.0 - albedo.b) * 0.7;
    float oxidizedScore = albedo.g * (1.0 - albedo.r) * 0.6;
    
    float total = copperScore + oxidizedScore + 0.001;
    return copperScore / total;
}

// === Функция для определения металлических частей ===
bool isMetalPart(vec3 albedo, int matID) {
    float brightness = dot(albedo.rgb, vec3(0.299, 0.587, 0.114));
    
    if (matID == 2020) {
        bool isDarkMetal = brightness < 0.35;
        bool isGoldenMetal = (albedo.r > 0.6 && albedo.g > 0.5 && albedo.b < 0.4);
        return isDarkMetal || isGoldenMetal;
    }
    
    if (matID == 2019) {
        return brightness < 0.3;
    }
    
    return false;
}








float detectPlankLines(vec3 albedo) {
    float brightness = dot(albedo.rgb, vec3(0.299, 0.587, 0.114));
    
    // Только тёмные линии между досками
    if (brightness < 0.10) return 1.0;
    if (brightness < 0.20) return 0.6;
    
    return 0.0;
}

// === Функция для определения типа древесины по цвету ===
int detectWoodType(vec3 albedo) {
    // Oak (2068) - средне-коричневый
    if (albedo.r > 0.50 && albedo.r < 0.70 && albedo.g > 0.35 && albedo.g < 0.50) return 0;
    
    // Spruce (2069) - тёмно-коричневый с серым оттенком
    if (albedo.r > 0.35 && albedo.r < 0.50 && albedo.g > 0.25 && albedo.g < 0.40) return 1;
    
    // Birch (2070) - светло-жёлтый
    if (albedo.r > 0.70 && albedo.g > 0.60 && albedo.b < 0.50) return 2;
    
    // Jungle (2071) - тёплый коричневый
    if (albedo.r > 0.55 && albedo.r < 0.70 && albedo.g > 0.40 && albedo.g < 0.55) return 3;
    
    // Acacia (2072) - оранжево-красноватый
    if (albedo.r > 0.60 && albedo.g > 0.35 && albedo.g < 0.50 && albedo.b < 0.35) return 4;
    
    // Dark Oak (2073) - очень тёмный коричневый
    if (albedo.r < 0.40 && albedo.g < 0.30 && albedo.b < 0.25) return 5;
    
    // Mangrove (2074) - красноватый
    if (albedo.r > 0.50 && albedo.g < 0.40 && albedo.b < 0.35) return 6;
    
    // Cherry (2075) - розоватый
    if (albedo.r > 0.60 && albedo.g > 0.45 && albedo.b > 0.45) return 7;
    
    // Pale Oak (2076) - очень светлый
    if (albedo.r > 0.75 && albedo.g > 0.70 && albedo.b > 0.65) return 8;
    
    return 0; // По умолчанию Oak
}

















// === Универсальная функция для настройки отражений по степени окисления ===
void applyOxidationLevel(inout float smoothness, inout float metalness, inout float fresnelStrength, 
                         inout vec3 metalTint, inout float reflectionSharpness, int oxidationLevel) {
    if (oxidationLevel == 0) { // Clean copper
        smoothness = 0.85;
        metalness = 0.92;
        fresnelStrength = 1.05;
        metalTint = vec3(1.0, 0.85, 0.75);
        reflectionSharpness = 0.95;
    } else if (oxidationLevel == 1) { // Exposed
        smoothness = 0.68;
        metalness = 0.85;
        fresnelStrength = 0.85;
        metalTint = vec3(0.95, 0.80, 0.70);
        reflectionSharpness = 0.70;
    } else if (oxidationLevel == 2) { // Weathered
        smoothness = 0.48;
        metalness = 0.70;
        fresnelStrength = 0.65;
        metalTint = vec3(0.85, 0.85, 0.75);
        reflectionSharpness = 0.45;
    } else { // Oxidized
        smoothness = 0.28;
        metalness = 0.50;
        fresnelStrength = 0.45;
        metalTint = vec3(0.80, 0.90, 0.85);
        reflectionSharpness = 0.22;
    }
}

void main() {
    vec4 albedo = texture(tex, texcoord) * tint;
    #ifdef WHITE_WORLD
    albedo.rgb = vec3(1.0);
    #endif

    mat3 tbnMatrix = manualTBN(viewPos.xyz, texcoord);
    if (albedo.a < 0.1) { discard; return; }

    #ifdef MC_SPECULAR_MAP
    vec4 specularData = texture(specular, texcoord);
    #else
    vec4 specularData = vec4(0.0);
    #endif

	// === СИСТЕМА ОТРАЖЕНИЙ ===
	bool isMetalBlock = false;
	float smoothness = 0.0;
	float metalness = 0.04;
	float fresnelStrength = 1.0;
	vec3 metalTint = vec3(1.0);
	float reflectionSharpness = 1.0;
	
	float detailMask = detectDetails(albedo.rgb);
	
	// === ЖЕЛЕЗНЫЙ БЛОК И ДВЕРЬ (2010, 2022) ===
	if (materialIDs == 2010 || materialIDs == 2022) {
		isMetalBlock = true;
		smoothness = 0.75;
		metalness = 0.95;
		fresnelStrength = 1.0;
		metalTint = vec3(0.95, 0.95, 1.0);
		reflectionSharpness = 0.85;
		
		smoothness = mix(smoothness, smoothness * 0.35, detailMask);
	}
	
	// === ЖЕЛЕЗНЫЙ ЛЮК (2023) ===
	else if (materialIDs == 2023) {
		isMetalBlock = true;
		smoothness = 0.72;
		metalness = 0.93;
		fresnelStrength = 0.95;
		metalTint = vec3(0.95, 0.95, 1.0);
		reflectionSharpness = 0.82;
		
		smoothness = mix(smoothness, smoothness * 0.35, detailMask);
	}
	
	// === ЗОЛОТОЙ БЛОК (2011) ===
	else if (materialIDs == 2011) {
		isMetalBlock = true;
		smoothness = 0.70;
		metalness = 0.98;
		fresnelStrength = 1.1;
		metalTint = vec3(1.0, 0.95, 0.85);
		reflectionSharpness = 0.80;
		
		smoothness = mix(smoothness, smoothness * 0.45, detailMask);
	}
	
	// === МЕДНЫЕ БЛОКИ (2012-2015) ===
	else if (materialIDs >= 2012 && materialIDs <= 2013) {
		isMetalBlock = true;
		int oxidationLevel = materialIDs - 2012;
		applyOxidationLevel(smoothness, metalness, fresnelStrength, metalTint, reflectionSharpness, oxidationLevel);
		
		float purity = detectCopperPurity(albedo.rgb);
		smoothness = mix(smoothness * 0.3, smoothness, purity);
		smoothness = mix(smoothness, smoothness * 0.35, detailMask);
	}



        else if (materialIDs == 2014) {


		isMetalBlock = true;
		smoothness = 0.97;
		metalness = 0.75;
		fresnelStrength = 1.30;
		metalTint = vec3(0.05, 0.05, 0.05);
		reflectionSharpness = 0.85;
		
		smoothness = mix(smoothness, smoothness * 0.5, detailMask);






    }














else if (materialIDs >= 2068 && materialIDs <= 2076) {
    float plankLineMask = detectPlankLines(albedo.rgb);
    int woodType = detectWoodType(albedo.rgb);
    
    // Базовые параметры для всех досок
    isMetalBlock = true;
    smoothness = 0.25;
    metalness = 0.08;
    fresnelStrength = 0.55;
    reflectionSharpness = 0.40;
    
    // Настройка параметров в зависимости от типа дерева
    if (woodType == 0) { // Oak
        metalTint = vec3(0.95, 0.90, 0.85);
        smoothness = 0.28;
    } else if (woodType == 1) { // Spruce
        metalTint = vec3(0.90, 0.88, 0.85);
        smoothness = 0.24;
    } else if (woodType == 2) { // Birch
        metalTint = vec3(1.0, 0.98, 0.90);
        smoothness = 0.32;
        fresnelStrength = 0.60;
    } else if (woodType == 3) { // Jungle
        metalTint = vec3(0.95, 0.88, 0.80);
        smoothness = 0.26;
    } else if (woodType == 4) { // Acacia
        metalTint = vec3(1.0, 0.85, 0.75);
        smoothness = 0.30;
    } else if (woodType == 5) { // Dark Oak
        metalTint = vec3(0.85, 0.82, 0.80);
        smoothness = 0.22;
        metalness = 0.06;
    } else if (woodType == 6) { // Mangrove
        metalTint = vec3(0.98, 0.80, 0.75);
        smoothness = 0.27;
    } else if (woodType == 7) { // Cherry
        metalTint = vec3(1.0, 0.90, 0.90);
        smoothness = 0.35;
        fresnelStrength = 0.65;
    } else if (woodType == 8) { // Pale Oak
        metalTint = vec3(1.0, 0.98, 0.95);
        smoothness = 0.38;
        fresnelStrength = 0.70;
    }
    
    // Усиление отражений на тёмных линиях между досками
    smoothness = mix(smoothness, smoothness * 2.8, plankLineMask);
    metalness = mix(metalness, metalness * 3.0, plankLineMask);
    
    // Небольшое снижение на общих деталях
    smoothness = mix(smoothness, smoothness * 0.75, detailMask * 0.3);
}


























    else if (materialIDs == 2015) {


		isMetalBlock = true;
		smoothness = 0.45;
		metalness = 0.55;
		fresnelStrength = 1.30;
		metalTint = vec3(0.05, 0.05, 0.05);
		reflectionSharpness = 0.85;
		
		smoothness = mix(smoothness, smoothness * 0.5, detailMask);






    }
	
	// === МЕДНЫЕ ДВЕРИ (2024-2031) ===
	else if (materialIDs >= 2024 && materialIDs <= 2031) {
		isMetalBlock = true;
		int oxidationLevel = (materialIDs - 2024) / 2;
		applyOxidationLevel(smoothness, metalness, fresnelStrength, metalTint, reflectionSharpness, oxidationLevel);
		
		smoothness *= 0.92;
		float purity = detectCopperPurity(albedo.rgb);
		smoothness = mix(smoothness * 0.3, smoothness, purity);
		smoothness = mix(smoothness, smoothness * 0.30, detailMask);
	}
	
	// === МЕДНЫЕ ЛЮКИ (2032-2039) ===
	else if (materialIDs >= 2032 && materialIDs <= 2039) {
		isMetalBlock = true;
		int oxidationLevel = (materialIDs - 2032) / 2;
		applyOxidationLevel(smoothness, metalness, fresnelStrength, metalTint, reflectionSharpness, oxidationLevel);
		
		smoothness *= 0.88;
		float purity = detectCopperPurity(albedo.rgb);
		smoothness = mix(smoothness * 0.3, smoothness, purity);
		smoothness = mix(smoothness, smoothness * 0.30, detailMask);
	}
	
	// === МЕДНЫЕ РЕШЁТКИ (2040-2047) ===
	else if (materialIDs >= 2040 && materialIDs <= 2047) {
		isMetalBlock = true;
		int oxidationLevel = (materialIDs - 2040) / 2;
		applyOxidationLevel(smoothness, metalness, fresnelStrength, metalTint, reflectionSharpness, oxidationLevel);
		
		smoothness *= 0.85;
		metalness *= 0.90;
		float purity = detectCopperPurity(albedo.rgb);
		smoothness = mix(smoothness * 0.25, smoothness, purity);
		smoothness = mix(smoothness, smoothness * 0.25, detailMask);
	}
	
	// === РЕЗНАЯ МЕДЬ (2048-2055) ===
	else if (materialIDs >= 2048 && materialIDs <= 2055) {
		isMetalBlock = true;
		int oxidationLevel = (materialIDs - 2048) / 2;
		applyOxidationLevel(smoothness, metalness, fresnelStrength, metalTint, reflectionSharpness, oxidationLevel);
		
		smoothness *= 0.80;
		float purity = detectCopperPurity(albedo.rgb);
		smoothness = mix(smoothness * 0.25, smoothness, purity);
		
		detailMask = max(detailMask, 0.4);
		smoothness = mix(smoothness, smoothness * 0.25, detailMask);
	}
	
	// === ГРОМООТВОД (2064) ===
	else if (materialIDs == 2064) {
		isMetalBlock = true;
		smoothness = 0.82;
		metalness = 0.90;
		fresnelStrength = 1.0;
		metalTint = vec3(1.0, 0.85, 0.75);
		reflectionSharpness = 0.88;
		
		float purity = detectCopperPurity(albedo.rgb);
		smoothness = mix(smoothness * 0.3, smoothness, purity);
		smoothness = mix(smoothness, smoothness * 0.30, detailMask);
	}
	
	// === OBSIDIAN (2016) ===
	else if (materialIDs == 2016) {
		isMetalBlock = true;
		smoothness = 0.78;
		metalness = 0.12;
		fresnelStrength = 0.85;
		metalTint = vec3(0.85, 0.85, 0.95);
		reflectionSharpness = 0.65;
	}
	
	// === QUARTZ (2017) ===
	else if (materialIDs == 2021) {
		isMetalBlock = true;
		smoothness = 0.97;
		metalness = 0.75;
		fresnelStrength = 1.30;
		metalTint = vec3(0.05, 0.05, 0.05);
		reflectionSharpness = 0.85;
		
		smoothness = mix(smoothness, smoothness * 0.5, detailMask);
	}
	
	// === COPPER CHEST (2018) ===
	else if (materialIDs == 2018) {
		isMetalBlock = true;
		smoothness = 0.78;
		metalness = 0.88;
		fresnelStrength = 0.95;
		metalTint = vec3(1.0, 0.85, 0.75);
		reflectionSharpness = 0.90;
		
		float purity = detectCopperPurity(albedo.rgb);
		smoothness = mix(smoothness * 0.3, smoothness, purity);
		smoothness = mix(smoothness, smoothness * 0.35, detailMask);
	}
	
	// === BARREL (2019) ===
	else if (materialIDs == 2019) {
		if (isMetalPart(albedo.rgb, materialIDs)) {
			isMetalBlock = true;
			smoothness = 0.58;
			metalness = 0.75;
			fresnelStrength = 0.8;
			metalTint = vec3(0.9, 0.9, 0.9);
			reflectionSharpness = 0.70;
			smoothness = mix(smoothness, smoothness * 0.4, detailMask);
		}
	}
	
	// === CHEST (2020) ===
	else if (materialIDs == 2020) {
		if (isMetalPart(albedo.rgb, materialIDs)) {
			isMetalBlock = true;
			smoothness = 0.68;
			metalness = 0.80;
			fresnelStrength = 0.88;
			metalTint = vec3(0.95, 0.90, 0.85);
			reflectionSharpness = 0.75;
			smoothness = mix(smoothness, smoothness * 0.45, detailMask);
		}
	}
	












	// === COPPER BULBS ON (80-87) ===
	else if (materialIDs >= 80 && materialIDs <= 87) {
		isMetalBlock = true;
		int oxidationLevel = (materialIDs - 80) / 2;
		applyOxidationLevel(smoothness, metalness, fresnelStrength, metalTint, reflectionSharpness, oxidationLevel);
		
		smoothness *= 0.88;
		float purity = detectCopperPurity(albedo.rgb);
		smoothness = mix(smoothness * 0.3, smoothness, purity);
		smoothness = mix(smoothness, smoothness * 0.35, detailMask);
	}
	
	// === COPPER BULBS OFF (88-95) ===
	else if (materialIDs >= 88 && materialIDs <= 95) {
		isMetalBlock = true;
		int oxidationLevel = (materialIDs - 88) / 2;
		applyOxidationLevel(smoothness, metalness, fresnelStrength, metalTint, reflectionSharpness, oxidationLevel);
		
		smoothness *= 0.86;
		float purity = detectCopperPurity(albedo.rgb);
		smoothness = mix(smoothness * 0.3, smoothness, purity);
		smoothness = mix(smoothness, smoothness * 0.35, detailMask);
	}

    // === Старые materialIDs ===
    if (materialIDs == 9 || materialIDs == 58) {
        if (materialIDs == 9 && albedo.r > 0.6 && albedo.g > 0.6 && albedo.b > 0.6) {
            specularData.r = 0.9; specularData.g = 0.2; specularData.b = 0.0;
        } {
            specularData.r = 0.7; specularData.g = 0.3; specularData.b = 0.0;
        } {
            specularData.r = 0.95; specularData.g = 0.1; specularData.b = 0.0;
            albedo.rgb *= vec3(0.8, 0.9, 1.0);
        }
    }

if (materialIDs == 21) {
    #if TEXTURE_FORMAT == 0 && defined MC_SPECULAR_MAP
        #if SUBSERFACE_SCATTERING_MODE == 1
            specularData.b = max(0.85, specularData.b);
        #elif SUBSERFACE_SCATTERING_MODE == 0
            specularData.b = 0.85;
        #endif
    #elif SUBSERFACE_SCATTERING_MODE < 2
        specularData.a = 0.85;
    #endif
    
    specularData.r = 0.65;  // smoothness (как у снега)
    specularData.g = 0.08;  // metalness (как у снега)
    
    // Применяем те же визуальные эффекты что и у снега
    albedo.rgb = mix(albedo.rgb, albedo.rgb * vec3(1.0, 1.0, 1.0), 0.15);
}
	// === Применяем эффекты для металлических блоков ===
	if (isMetalBlock) {
		smoothness *= reflectionSharpness;
		
		specularData.r = smoothness;
		specularData.g = metalness;
		specularData.b = 0.0;
		specularData.a = 0.0;
		
		albedo.rgb = mix(albedo.rgb, albedo.rgb * metalTint, 0.35);
		albedo.rgb = pow(albedo.rgb, vec3(0.90));
		
		vec3 viewDir = normalize(viewPos.xyz);
		float fresnel = pow(1.0 - abs(dot(tbnMatrix[2], viewDir)), 2.5);
		
		vec3 fresnelColor = vec3(0.15, 0.18, 0.25);
		if (materialIDs == 2011) fresnelColor = vec3(0.25, 0.22, 0.15);
		else if (materialIDs >= 2012 && materialIDs <= 2055) fresnelColor = vec3(0.20, 0.15, 0.12);
		else if (materialIDs == 2016) fresnelColor = vec3(0.12, 0.12, 0.20);
        else if (materialIDs == 2021) fresnelColor = vec3(0.12, 0.12, 0.20);
		else if (materialIDs == 2064) fresnelColor = vec3(0.22, 0.17, 0.13);
		
		fresnel *= mix(0.4, 1.0, reflectionSharpness);
		albedo.rgb += fresnel * fresnelColor * fresnelStrength * (1.0 - detailMask * 0.5);
	}

    #ifdef MC_NORMAL_MAP
    vec3 normalData = texture(normals, texcoord).rgb;
    DecodeNormalTex(normalData);
    #else
    vec3 normalData = vec3(0.0, 0.0, 1.0);
    #endif

	// === NORMAL GENERATION (Super Duper Vanilla style) ===
	#ifdef NORMAL_GENERATION
		// Generate bumped normals from albedo texture
		// Skip for water (11102) and end portal (19)
		if (materialIDs != 11102 && materialIDs != 19) {
			const float autoGenNormPixSize = 1.0 / 64.0;
			
			vec2 texGradX = dFdx(texcoord);
			vec2 texGradY = dFdy(texcoord);
			
			vec2 topRightCorner = texcoord + vec2(autoGenNormPixSize, autoGenNormPixSize);
			vec2 bottomLeftCorner = texcoord - vec2(autoGenNormPixSize, autoGenNormPixSize);
			
			// Sample texture at 3 points
			float d0 = textureGrad(tex, topRightCorner, texGradX, texGradY).r + 
			           textureGrad(tex, topRightCorner, texGradX, texGradY).g + 
			           textureGrad(tex, topRightCorner, texGradX, texGradY).b;
			           
			float d1 = textureGrad(tex, vec2(bottomLeftCorner.x, topRightCorner.y), texGradX, texGradY).r +
			           textureGrad(tex, vec2(bottomLeftCorner.x, topRightCorner.y), texGradX, texGradY).g +
			           textureGrad(tex, vec2(bottomLeftCorner.x, topRightCorner.y), texGradX, texGradY).b;
			           
			float d2 = textureGrad(tex, vec2(topRightCorner.x, bottomLeftCorner.y), texGradX, texGradY).r +
			           textureGrad(tex, vec2(topRightCorner.x, bottomLeftCorner.y), texGradX, texGradY).g +
			           textureGrad(tex, vec2(topRightCorner.x, bottomLeftCorner.y), texGradX, texGradY).b;
			
			vec2 slopeNormal = d0 - vec2(d1, d2);
			float lengthInv = inversesqrt(dot(slopeNormal, slopeNormal) + 1.0);
			vec3 bumpedNormal = vec3(slopeNormal * lengthInv, lengthInv);
			
			const float normalStrength = 1.0;
			normalData = mix(vec3(0.0, 0.0, 1.0), bumpedNormal, normalStrength);
		}
	#endif

    #if defined IS_OVERWORLD
    if (wetnessCustom > 1e-2) {
        float noise = GetRainWetness(minecraftPos.xz - minecraftPos.y);
        noise *= remap(0.5, 0.9, (mat3(gbufferModelViewInverse) * tbnMatrix[2]).y);
        noise *= saturate(lightmap.y * 10.0 - 9.0);
        float wetFact = smoothstep(0.54, 0.62, noise);
        #ifdef RAIN_SPLASH_EFFECT
        normalData = mix(normalData.xyz, vec3(GetRainNormal(minecraftPos), 1.0), wetFact * 0.5);
        #else
        normalData = mix(normalData.xyz, vec3(0.0, 0.0, 1.0), wetFact);
        #endif
        wetFact = sqr(remap(0.35, 0.57, noise));
        #ifdef FORCE_WET_EFFECT
        if (!isMetalBlock) {
            specularData.r = mix(specularData.r, 1.0, wetFact);
            specularData.g = max(specularData.g, 0.04 * wetFact);
            specularData.rg += (bayer4(gl_FragCoord.xy) - 0.5) * rcp(255.0);
        }
        #endif
        vec3 wetAlbedo = ColorSaturation(albedo.rgb, 0.75) * 0.85;
        #ifdef POROSITY
        float porosity = specularData.b > 64.5 / 255.0 ? 0.0 : remap(specularData.b, 0.0, 64.0 / 255.0) * 0.7;
        wetAlbedo *= oneMinus(porosity) / oneMinus(porosity * wetAlbedo);
        #endif
        if (!isMetalBlock) {
            albedo.rgb = mix(albedo.rgb, wetAlbedo, sqr(remap(0.3, 0.56, noise)));
        }
    }
    #endif

    normalData = normalize(tbnMatrix * normalData);
    
    // === END PORTAL LOGIC ===
    if (materialIDs == 19) {
        vec3 colors[16];
        colors[0] = vec3(END_PORTAL_COLOR_0_R, END_PORTAL_COLOR_0_G, END_PORTAL_COLOR_0_B) / 255.0;
        colors[1] = vec3(END_PORTAL_COLOR_1_R, END_PORTAL_COLOR_1_G, END_PORTAL_COLOR_1_B) / 255.0;
        colors[2] = vec3(END_PORTAL_COLOR_2_R, END_PORTAL_COLOR_2_G, END_PORTAL_COLOR_2_B) / 255.0;
        colors[3] = vec3(END_PORTAL_COLOR_3_R, END_PORTAL_COLOR_3_G, END_PORTAL_COLOR_3_B) / 255.0;
        colors[4] = vec3(END_PORTAL_COLOR_4_R, END_PORTAL_COLOR_4_G, END_PORTAL_COLOR_4_B) / 255.0;
        colors[5] = vec3(END_PORTAL_COLOR_5_R, END_PORTAL_COLOR_5_G, END_PORTAL_COLOR_5_B) / 255.0;
        colors[6] = vec3(END_PORTAL_COLOR_6_R, END_PORTAL_COLOR_6_G, END_PORTAL_COLOR_6_B) / 255.0;
        colors[7] = vec3(END_PORTAL_COLOR_7_R, END_PORTAL_COLOR_7_G, END_PORTAL_COLOR_7_B) / 255.0;
        colors[8] = vec3(END_PORTAL_COLOR_8_R, END_PORTAL_COLOR_8_G, END_PORTAL_COLOR_8_B) / 255.0;
        colors[9] = vec3(END_PORTAL_COLOR_9_R, END_PORTAL_COLOR_9_G, END_PORTAL_COLOR_9_B) / 255.0;
        colors[10] = vec3(END_PORTAL_COLOR_10_R, END_PORTAL_COLOR_10_G, END_PORTAL_COLOR_10_B) / 255.0;
        colors[11] = vec3(END_PORTAL_COLOR_11_R, END_PORTAL_COLOR_11_G, END_PORTAL_COLOR_11_B) / 255.0;
        colors[12] = vec3(END_PORTAL_COLOR_12_R, END_PORTAL_COLOR_12_G, END_PORTAL_COLOR_12_B) / 255.0;
        colors[13] = vec3(END_PORTAL_COLOR_13_R, END_PORTAL_COLOR_13_G, END_PORTAL_COLOR_13_B) / 255.0;
        colors[14] = vec3(END_PORTAL_COLOR_14_R, END_PORTAL_COLOR_14_G, END_PORTAL_COLOR_14_B) / 255.0;
        colors[15] = vec3(END_PORTAL_COLOR_15_R, END_PORTAL_COLOR_15_G, END_PORTAL_COLOR_15_B) / 255.0;

        vec3 worldDir = mat3(gbufferModelViewInverse) * normalize(viewPos.xyz);
        vec3 worldDirAbs = abs(worldDir);
        vec3 samplePartAbs = step(maxOf(worldDirAbs), worldDirAbs);
        vec3 samplePart = samplePartAbs * sign(worldDir);
        float intersection = 1.0 / dot(samplePartAbs, worldDirAbs);
        vec3 sampleNDCRaw = samplePart - worldDir * intersection;
        vec2 sampleNDC = sampleNDCRaw.xy * vec2(samplePartAbs.y + samplePart.z, 1.0 - samplePartAbs.y) + sampleNDCRaw.z * vec2(-samplePart.x, samplePartAbs.y);
        vec2 portalCoord = sampleNDC * 0.5 + 0.5;

        vec3 portalColor = texture(tex, portalCoord).rgb * colors[0];
        for (int i = 1; i < 16; ++i) {
            portalColor += texture(tex, endPortalLayer(portalCoord, float(i + 1))).rgb * colors[i];
        }
        albedo.rgb = portalColor;
        specularData = vec4(1.0, 0.04, vec2(254.0 / 255.0));
    }

#if TEXTURE_FORMAT == 0 && defined MC_SPECULAR_MAP
#if SUBSERFACE_SCATTERING_MODE == 1
if (materialIDs == 9) specularData.b = max(0.65, specularData.b);



// === CUSTOM QUARTZ-LIKE BLOCK (10010) SSS + REFLECTIONS ===
if (materialIDs == 10) {
    specularData.b = max(0.65, specularData.b);
    specularData.r = 0.85;  // smoothness
    specularData.g = 0.88;  // metalness
    albedo.rgb = mix(albedo.rgb, albedo.rgb * vec3(1.0, 1.0, 1.0), 0.85);
}
#elif SUBSERFACE_SCATTERING_MODE == 0
if (materialIDs == 9) specularData.b = 0.65;

// === CUSTOM QUARTZ-LIKE BLOCK (10010) SSS + REFLECTIONS ===
if (materialIDs == 10) {
    specularData.b = 0.65;
    specularData.r = 0.85;  // smoothness
    specularData.g = 0.88;  // metalness
    albedo.rgb = mix(albedo.rgb, albedo.rgb * vec3(1.0, 1.0, 1.0), 0.85);
}
#endif
#elif SUBSERFACE_SCATTERING_MODE < 2
specularData.a = 0.0;
if (materialIDs == 9) specularData.a = 0.65;

// === CUSTOM QUARTZ-LIKE BLOCK (10010) SSS + REFLECTIONS ===
if (materialIDs == 10) {
    specularData.a = 0.65;
    specularData.r = 0.85;  // smoothness
    specularData.g = 0.88;  // metalness
    albedo.rgb = mix(albedo.rgb, albedo.rgb * vec3(1.0, 1.0, 1.0), 0.85);
}
#endif


    albedoData = albedo;
    colortex7Out.xy = lightmap + (bayer4(gl_FragCoord.xy) - 0.5) * rcp(255.0);
    colortex7Out.z = float(materialIDs + 0.1) * rcp(255.0);
    colortex3Out.xy = EncodeNormal(normalData);
    colortex3Out.z = PackUnorm2x8(specularData.rg);
    colortex3Out.w = PackUnorm2x8(specularData.ba);
}