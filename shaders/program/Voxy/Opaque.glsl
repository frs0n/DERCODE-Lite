#include "/lib/Head/Common.inc"
#include "/lib/Head/Voxy.inc"

layout(location = 0) out vec3 albedoData;
layout(location = 1) out vec3 colortex7Out;
layout(location = 2) out vec4 colortex3Out;

void voxy_emitFragment(VoxyFragmentParameters parameters) {
	vec3 albedo = parameters.sampledColour.rgb * parameters.tinting.rgb;
	vec3 normal = normalize(mat3(gbufferModelView) * VoxyFaceNormal(parameters.face));

	uint materialID = VoxyGetMaterialID(parameters.customId);
	if (materialID > 0u) materialID = max(materialID, 6u);

	float dither = VoxyDither(gl_FragCoord.xy);

	albedoData = albedo;

	colortex7Out.xy = parameters.lightMap + (dither - 0.5) * rcp(255.0);
	colortex7Out.z = float(materialID) * rcp(255.0);

	vec4 specularData = vec4(0.0);

	#if TEXTURE_FORMAT == 0
		if (materialID == 6u) specularData.b = 0.45;
		if (materialID == 7u || materialID == 10u) specularData.b = 0.25;
	#elif SUBSERFACE_SCATTERING_MODE < 2
		if (materialID == 6u) specularData.a = 0.45;
		if (materialID == 7u || materialID == 10u) specularData.a = 0.7;
	#endif

	colortex3Out.xy = EncodeNormal(normal);
	colortex3Out.z = PackUnorm2x8(specularData.rg);
	colortex3Out.w = PackUnorm2x8(specularData.ba);
}
