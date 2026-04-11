#include "/lib/Head/Common.inc"
#include "/lib/Head/Voxy.inc"

layout(location = 0) out vec3 colortex7Out;
layout(location = 1) out vec4 reflectionData;
layout(location = 2) out vec4 colortex3Out;

void voxy_emitFragment(VoxyFragmentParameters parameters) {
	vec4 albedo = parameters.sampledColour * parameters.tinting;
	vec3 normal = normalize(mat3(gbufferModelView) * VoxyFaceNormal(parameters.face));

	uint materialID = VoxyGetMaterialID(parameters.customId);
	if (materialID == 0u) materialID = 16u;

	colortex7Out.xy = parameters.lightMap + (VoxyDither(gl_FragCoord.xy) - 0.5) * rcp(255.0);
	colortex7Out.z = float(materialID) * rcp(255.0);

	colortex3Out.xy = EncodeNormal(normal);
	colortex3Out.z = PackUnorm2x8(albedo.rg);
	colortex3Out.w = PackUnorm2x8(albedo.ba);

	reflectionData = VoxyReflectionData(materialID, parameters.lightMap, normal);
}
