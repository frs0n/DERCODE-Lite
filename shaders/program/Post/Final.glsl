out vec3 finalData;

#include "/lib/Head/Common.inc"
#include "/lib/Head/Uniforms.inc"
#include "/lib/Head/Noise.inc"

#define INFO 0		// [0 1 2 3]
#define Version 0	// [0 1 2 3]

//#define DEBUG_DRAWBUFFERS

//----------------------------------------------------------------------------//

#define minOf(a, b, c, d, e, f, g, h, i) min(a, min(b, min(c, min(d, min(e, min(f, min(g, min(h, i))))))))
#define maxOf(a, b, c, d, e, f, g, h, i) max(a, max(b, max(c, max(d, max(e, max(f, max(g, max(h, i))))))))

#define SampleColor(texel) texelFetch(colortex3, texel, 0).rgb

// Contrast Adaptive Sharpening (CAS)
vec3 CASFilter(in ivec2 texel) {
	#ifndef CAS_ENABLED
		return SampleColor(texel);
	#endif

	vec3 a = SampleColor(texel + ivec2(-1, -1));
	vec3 b = SampleColor(texel + ivec2( 0, -1));
	vec3 c = SampleColor(texel + ivec2( 1, -1));
	vec3 d = SampleColor(texel + ivec2(-1,  0));
	vec3 e = SampleColor(texel);
	vec3 f = SampleColor(texel + ivec2( 1,  0));
	vec3 g = SampleColor(texel + ivec2(-1,  1));
	vec3 h = SampleColor(texel + ivec2( 0,  1));
	vec3 i = SampleColor(texel + ivec2( 1,  1));

	vec3 minColor = minOf(a, b, c, d, e, f, g, h, i);
	vec3 maxColor = maxOf(a, b, c, d, e, f, g, h, i);

    vec3 sharpeningAmount = sqrt(min(1.0 - maxColor, minColor) / maxColor);
    vec3 w = sharpeningAmount * mix(-0.125, -0.2, CAS_STRENGTH);

	return ((b + d + f + h) * w + e) / (4.0 * w + 1.0);
}

//----------------------------------------------------------------------------//

vec3 textureCatmullRomFast(in sampler2D tex, in vec2 position, in const float sharpness) {
	vec2 centerPosition = floor(position - 0.5) + 0.5;
	vec2 f = position - centerPosition;
	vec2 f2 = f * f;
	vec2 f3 = f * f2;

	vec2 w0 = -sharpness        * f3 + 2.0 * sharpness         * f2 - sharpness * f;
	vec2 w1 = (2.0 - sharpness) * f3 - (3.0 - sharpness)       * f2 + 1.0;
	vec2 w2 = (sharpness - 2.0) * f3 + (3.0 - 2.0 * sharpness) * f2 + sharpness * f;
	vec2 w3 = sharpness         * f3 - sharpness               * f2;

	vec2 w12 = w1 + w2;

	vec2 tc0 = screenPixelSize * (centerPosition - 1.0);
	vec2 tc3 = screenPixelSize * (centerPosition + 2.0);
	vec2 tc12 = screenPixelSize * (centerPosition + w2 / w12);

	float l0 = w12.x * w0.y;
	float l1 = w0.x  * w12.y;
	float l2 = w12.x * w12.y;
	float l3 = w3.x  * w12.y;
	float l4 = w12.x * w3.y;

	vec3 color =  texture(tex, vec2(tc12.x, tc0.y )).rgb * l0
				+ texture(tex, vec2(tc0.x,  tc12.y)).rgb * l1
				+ texture(tex, vec2(tc12.x, tc12.y)).rgb * l2
				+ texture(tex, vec2(tc3.x,  tc12.y)).rgb * l3
				+ texture(tex, vec2(tc12.x, tc3.y )).rgb * l4;

	return color / (l0 + l1 + l2 + l3 + l4);
}

//----------------------------------------------------------------------------//
// CHROMATIC ABERRATION
//----------------------------------------------------------------------------//

vec3 applyChromaticAberration(vec2 uv, vec3 color) {
    #if CHROMATIC_ABERRATION_ENABLED == 1
        vec2 coord = uv - 0.5;
        float dist = length(coord);
        float fovMask = mix(dist * 2.3, 1.0, CHROMATIC_ABERRATION_CENTER);
        float amount = CHROMATIC_ABERRATION_STRENGTH * fovMask;
        vec2 offset = coord * amount;

        #if CHROMATIC_ABERRATION_STYLE == 1          // 1. КЛАССИЧЕСКАЯ RGB
            color.r = texture2D(colortex3, uv + offset).r;
            color.g = texture2D(colortex3, uv).g;
            color.b = texture2D(colortex3, uv - offset).b;

        #elif CHROMATIC_ABERRATION_STYLE == 2        // 2. НАСТОЯЩИЙ GOPRO
            color.r = texture2D(colortex3, uv + offset * 1.7).r;
            color.g = texture2D(colortex3, uv - offset * 0.4).g;
            color.b = texture2D(colortex3, uv - offset * 0.7).b;

        #elif CHROMATIC_ABERRATION_STYLE == 3        // 3. РАДУЖНАЯ ДИНАМИЧЕСКАЯ
            float time = frameTimeCounter * 0.9;
            float hue = time * 0.3;
            vec3 rainbow = 0.5 + 0.5 * cos(hue + vec3(0.0, 2.094, 4.188));
            
            vec2 offsetR = offset * (0.8 + 0.6 * rainbow.r);
            vec2 offsetG = offset * (0.8 + 0.6 * rainbow.g);
            vec2 offsetB = offset * (0.8 + 0.6 * rainbow.b);

            color.r = texture2D(colortex3, uv + offsetR).r;
            color.g = texture2D(colortex3, uv + offsetG * vec2(1.0, -0.7)).g;
            color.b = texture2D(colortex3, uv - offsetB * vec2(0.8, 1.1)).b;

        #elif CHROMATIC_ABERRATION_STYLE == 4        // 4. ТОЛЬКО СИНЕ-ЗЕЛЁНАЯ
            color.r = texture2D(colortex3, uv).r;
            color.g = texture2D(colortex3, uv + offset * 0.9).g;
            color.b = texture2D(colortex3, uv - offset * 1.3).b;
        #endif
    #endif
    return color;
}

//----// MAIN //----------------------------------------------------------------------------------//
void main() {
    ivec2 texel = ivec2(gl_FragCoord.xy);
    vec2 texcoord = gl_FragCoord.xy / vec2(viewWidth, viewHeight);

	#ifdef DEBUG_DRAWBUFFERS
		finalData = texelFetch(colortex4, texel, 0).rgb;
		return;
	#endif

	if (abs(MC_RENDER_QUALITY - 1.0) < 1e-2) {
    	finalData = CASFilter(texel);
	} else {
		finalData = textureCatmullRomFast(colortex3, texel * MC_RENDER_QUALITY, 0.6);
	}
	
	finalData += (bayer16(gl_FragCoord.xy) - 0.5) * rcp(255.0);
	
	// Применяем хроматическую аберрацию
	finalData = applyChromaticAberration(texcoord, finalData);
}