    #ifndef BRDF_GLSL
#define BRDF_GLSL

// ===================================================================
// BRDF
// ===================================================================

// Fresnel Schlick (металлы)
float FresnelSchlick(in float cosTheta, in float f0) {
    float f = pow5(1.0 - cosTheta);
    return saturate(f + oneMinus(f) * f0);
}

// Fresnel диэлектрика (deferred6.fsh)
float FresnelDielectric(in float cosTheta, in float f0) { // 基于反射率f0
    f0 = min(sqrt(f0), 0.99999);
    f0 = (1.0 + f0) * rcp(1.0 - f0);

    float cosR = 1.0 - sqr(sqrt(1.0 - sqr(cosTheta)) * rcp(max(f0, 1e-16)));
    if (cosR < 0.0) return 1.0;

    cosR = sqrt(cosR);
    float a = f0 * cosTheta;
    float b = f0 * cosR;
    float r1 = (a - cosR) / (a + cosR);
    float r2 = (b - cosTheta) / (b + cosTheta);
    return saturate(0.5 * (r1 * r1 + r2 * r2));
}

// Fresnel диэлектрика для RGB (металлы)
vec3 FresnelDielectric(float cosTheta, vec3 F0){
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

float FresnelDielectricN(in float cosTheta, in float n) { // 基于折射系数ior
    float cosR = sqr(n) + sqr(cosTheta) - 1.0;
    if (cosR < 0.0) return 1.0;

    cosR = sqrt(cosR);
    float a = n * cosTheta;
    float b = n * cosR;
    float r1 = (a - cosR) / (a + cosR);
    float r2 = (b - cosTheta) / (b + cosTheta);
    return saturate(0.5 * (r1 * r1 + r2 * r2));
}

// Fresnel диэлектрика для RGB векторов нормалей
vec3 FresnelDielectricN(float cosTheta, vec3 F0){
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

// GGX Distribution
float DistributionGGX(in float NdotH, in float alpha2) {
	return alpha2 * rPI / sqr(1.0 + (NdotH * alpha2 - NdotH) * NdotH);
}

// Smith GGX Visibility
float V1SmithGGXInverse(in float cosTheta, in float alpha2) {
    return cosTheta + sqrt((cosTheta - alpha2 * cosTheta) * cosTheta + alpha2);
}

float V2SmithGGX(in float NdotV, in float NdotL, in float alpha2) {
    float ggxl = NdotL * sqrt(alpha2 + (NdotV - NdotV * alpha2) * NdotV);
    float ggxv = NdotV * sqrt(alpha2 + (NdotL - NdotL * alpha2) * NdotL);
    return 0.5 / (ggxl + ggxv);
}

// Specular BRDF
float SpecularBRDF(in float LdotH, in float NdotV, in float NdotL, in float NdotH, in float alpha2, in float f0) {
	if (NdotL < 1e-5) return 0.0;
    float F = FresnelSchlick(LdotH, f0);
	//if (F < 1e-2) return 0.0;

	float D = DistributionGGX(NdotH, alpha2);
    float V = V2SmithGGX(max(NdotV, 1e-2), max(NdotL, 1e-2), alpha2);

	return min(NdotL * D * V * F, 4.0);
}

// ===================================================================
// Diffuse Hammon
// ===================================================================
vec3 DiffuseHammon(in float LdotV, in float NdotV, in float NdotL, in float NdotH, in float roughness, in vec3 albedo) {
	if (NdotL < 1e-6) return vec3(0.0);
    float facing = max0(LdotV) * 0.5 + 0.5;

    //float singleSmooth = rcp(1.0 - (4.0 * sqrt(f0) + 5.0 * f0 * f0)) * 9.0 * fresnelSchlickInverse(f0, NdotL) * fresnelSchlickInverse(f0, NdotV);
    //float singleSmooth = 1.05 * FresnelSchlickInverse(NdotL, 0.0) * FresnelSchlickInverse(NdotV, 0.0);
    float singleSmooth = 1.05 * oneMinus(pow5(1.0 - max(NdotL, 1e-2))) * oneMinus(pow5(1.0 - max(NdotV, 1e-2)));
    float singleRough = facing * (0.45 - 0.2 * facing) * (rcp(NdotH) + 2.0);

    float single = mix(singleSmooth, singleRough, roughness) * rPI;
    float multi = 0.1159 * roughness;

    return (multi * albedo + single) * NdotL;
}

vec3 DiffuseHammon(float LdotV, float NdotV, float NdotL, float NdotH, float roughness){
    return DiffuseHammon(LdotV, NdotV, NdotL, NdotH, roughness, vec3(1.0));
}

// ===================================================================
// Integrated PBR
// ===================================================================
struct dataPBR {
    vec4 albedo;
    vec3 normal;
    float smoothness;
    float emissive;
    float metallic;
    float porosity;
    float ss;
    float parallaxShd;
    float ambient;
};

uniform sampler2D iron_block_s;
uniform sampler2D iron_block_n;

void getPBR(inout dataPBR material, int id){
    vec2 dcdx = dFdx(vTexCoord);
    vec2 dcdy = dFdy(vTexCoord);
    material.albedo = textureGrad(gtexture, vTexCoord, dcdx, dcdy);
    if (material.albedo.a < ALPHA_THRESHOLD){ discard; return; }
    material.normal = TBN[2];

    // defaults
    material.smoothness = 0.0;
    material.emissive = 0.0;
    material.metallic = 0.04;
    material.porosity = 0.0;
    material.ss = 0.0;
    material.parallaxShd = 1.0;
    material.ambient = 1.0;
    
    // Старые блоки
    if(id >= 10001 && id <= 10007){ material.porosity=1.0; material.smoothness=0.2; }
    else if(id==10009){ material.ss=1.0; material.smoothness=0.4; }
    
    // === СНЕГ С ПРОЦЕДУРНЫМИ НОРМАЛЯМИ (10010) ===
    else if(id==10010){ 
        material.ss=0.85;
        material.smoothness=0.65;
        material.metallic=0.08;
        material.porosity=0.3;
        material.ambient=1.15;
        
        // Процедурная генерация нормалей (parallax эффект)
        vec2 coord = vTexCoord * 16.0; // масштаб текстуры
        
        // Шум для неровностей снега
        float noise1 = fract(sin(dot(coord, vec2(12.9898, 78.233))) * 43758.5453);
        float noise2 = fract(sin(dot(coord + vec2(1.0, 0.0), vec2(12.9898, 78.233))) * 43758.5453);
        float noise3 = fract(sin(dot(coord + vec2(0.0, 1.0), vec2(12.9898, 78.233))) * 43758.5453);
        
        // Градиенты высоты
        float dx = (noise2 - noise1) * 0.5;
        float dy = (noise3 - noise1) * 0.5;
        
        // Дополнительный детальный шум
        vec2 coordDetail = coord * 4.0;
        float detailNoise = fract(sin(dot(coordDetail, vec2(45.123, 67.890))) * 23456.789);
        dx += (detailNoise - 0.5) * 0.15;
        dy += (detailNoise - 0.5) * 0.15;
        
        // Создаем нормаль из градиентов
        vec3 proceduralNormal = normalize(vec3(-dx, -dy, 1.0));
        
        // Смешиваем с исходной нормалью
        material.normal = normalize(TBN * proceduralNormal);
    }

else if(id == 12021) {
    // Копируем параметры ТОЧНО как у block.10010 (snow/ice)
    material.ss = 0.85;
    material.smoothness = 0.65;
    material.metallic = 0.08;
    material.porosity = 0.3;
    material.ambient = 1.15;
    material.emissive = 0.0;
    
    // Процедурная генерация нормалей (как у снега)
    vec2 coord = vTexCoord * 16.0;
    
    float noise1 = fract(sin(dot(coord, vec2(12.9898, 78.233))) * 43758.5453);
    float noise2 = fract(sin(dot(coord + vec2(1.0, 0.0), vec2(12.9898, 78.233))) * 43758.5453);
    float noise3 = fract(sin(dot(coord + vec2(0.0, 1.0), vec2(12.9898, 78.233))) * 43758.5453);
    
    float dx = (noise2 - noise1) * 0.5;
    float dy = (noise3 - noise1) * 0.5;
    
    vec2 coordDetail = coord * 4.0;
    float detailNoise = fract(sin(dot(coordDetail, vec2(45.123, 67.890))) * 23456.789);
    dx += (detailNoise - 0.5) * 0.15;
    dy += (detailNoise - 0.5) * 0.15;
    
    vec3 proceduralNormal = normalize(vec3(-dx, -dy, 1.0));
    material.normal = normalize(TBN * proceduralNormal);
}

    
    else if(id==10015){ material.emissive=1.0; material.smoothness=0.8; material.metallic=0.0; }
    else if(id==10017 || id==10018){ material.smoothness=0.96; material.metallic=0.02; }

    else if(id==10020 || id==10021 || id==10023 || id==10024 || id==10026 || id==10030 || id==10033 || id==10034){ 
        material.emissive=1.0; material.smoothness=0.9; 
    }
    else if(id==10025 || id==10029){ 
        material.emissive=material.albedo.r*0.5; material.smoothness=0.9; material.metallic=1.0; 
    }
    else if(id==10027){ 
        float avg=dot(material.albedo.rgb,vec3(0.333)); 
        material.smoothness=avg*0.6+0.3; 
        material.emissive=avg*avg*avg; 
        material.metallic=0.17; 
    }
    else if(id==10028){ 
        material.emissive = smoothstep(0.3,0.9,max(material.albedo.rgb)); 
    }
    else if(id==10031){ 
        material.emissive=0.5; material.smoothness=0.8; 
    }
    else if(id==10032){ 
        material.emissive=1.0; material.smoothness=0.8; 
    }





else if(id >= 13060 && id <= 13067){ 
    // Оставляем дефолтные значения, только свечение
}


    
    
    // Железный блок нет блять золотой 
    else if(id == 10070){
        material.albedo = texture(iron_block_s, vTexCoord);
        vec3 normalMap = texture(iron_block_n, vTexCoord).rgb;
        material.normal = normalize(TBN * (normalMap * 2.0 - 1.0));
        material.smoothness = 0.95;
        material.metallic = 0.9;
        material.emissive = 0.0;
    }


    
    else if(id == 11001){
        material.albedo.rgb *= 0.5;
        material.smoothness = 0.95;
        material.metallic = 1.0;
        material.emissive = 1.0;
    }
    else if(id==10057 || id==10058){ material.smoothness=0.8; material.metallic=0.6; }
   
}