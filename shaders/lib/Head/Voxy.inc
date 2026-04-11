vec3 VoxyFaceNormal(in uint face) {
	return vec3(
		uint((face >> 1) == 2u),
		uint((face >> 1) == 0u),
		uint((face >> 1) == 1u)
	) * (float(int(face) & 1) * 2.0 - 1.0);
}

uint VoxyGetMaterialID(in uint customId) {
	uint materialID = customId;
	if (materialID >= 10000u) materialID -= 10000u;
	return min(materialID, 255u);
}

float VoxyDither(in vec2 coord) {
	return fract(52.9829189 * fract(0.06711056 * coord.x + 0.00583715 * coord.y + 0.00623715 * float(frameCounter & 63)));
}

vec4 VoxyReflectionData(in uint materialID, in vec2 lightmap, in vec3 normal) {
	float NoV = saturate(dot(normal, vec3(0.0, 0.0, 1.0)));
	float ior = materialID == 17u ? WATER_REFRACT_IOR : GLASS_REFRACT_IOR;
	float f0 = sqr((ior - 1.0) / (ior + 1.0));
	float specular = f0 + oneMinus(f0) * pow5(oneMinus(NoV));
	return vec4(vec3(0.0), 1.0 - specular);
}
