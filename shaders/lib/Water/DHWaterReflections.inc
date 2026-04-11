#if defined DISTANT_HORIZONS
vec4 CalculateDHSpecularReflections(
	in vec3 normal,
	in float skylight,
	in vec3 viewPos,
	in float depth,
	in uint materialID
) {
	skylight = smoothstep(0.3, 0.8, skylight);
	vec3 viewDir = normalize(viewPos);
	vec3 rayDir = reflect(viewDir, normal);

	float NdotL = dot(normal, rayDir);
	if (NdotL < 1e-6) return vec4(0.0);

	float dither = InterleavedGradientNoiseTemporal(gl_FragCoord.xy);
	vec3 screenPos = vec3(gl_FragCoord.xy * screenPixelSize, depth);
	float NdotV = max(1e-6, dot(normal, -viewDir));

	bool hit = ScreenSpaceRayTraceDH(viewPos, rayDir, dither, RAYTRACE_SAMPLES, screenPos);

	vec3 reflection = vec3(0.0);
	if (hit) {
		reflection = texelFetch(colortex4, ivec2(screenPos.xy), 0).rgb;
	}
	#if defined IS_OVERWORLD
		else if (skylight > 1e-3) {
			if (isEyeInWater == 0) {
				vec3 rayDirWorld = mat3(gbufferModelViewInverse) * rayDir;
				float NdotU = saturate((dot(normal, gbufferModelView[1].xyz) + 0.7) * 2.0) * 0.75 + 0.25;
				vec4 skyboxData = textureBicubic(colortex5, ProjectSky(rayDirWorld) + vec2(0.0, skyCaptureRes.y * screenPixelSize.y));

				#ifdef REAL_SKY_REFLECTION
					vec3 sunmoon = RenderSunReflection(rayDirWorld, worldSunVector);
					sunmoon += RenderMoonReflection(rayDirWorld, worldSunVector);
					reflection = skyboxData.rgb * skylight * NdotU;
					reflection += sunmoon * skyboxData.a * skylight * AtmosphereAbsorption(rayDirWorld, AtmosphereExtent);
				#else
					reflection = skyboxData.rgb * skylight * NdotU;
				#endif
			} else {
				reflection = vec3(0.05, 0.7, 1.0) * 0.25 * (timeNoon + timeMidnight * NIGHT_BRIGHTNESS);
			}
		}
	#endif

	float specular;
	if (isEyeInWater == 1) {
		specular = FresnelDielectricN(NdotV, 1.0 / WATER_REFRACT_IOR);
	} else {
		specular = FresnelDielectricN(NdotV, materialID == 17u ? WATER_REFRACT_IOR : GLASS_REFRACT_IOR);
	}

	return clamp16F(vec4(reflection * specular, 1.0 - specular));
}
#endif
