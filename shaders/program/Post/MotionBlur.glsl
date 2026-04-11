

out vec3 blurColor;

/* DRAWBUFFERS:2 */

uniform sampler2D colortex2; // velocity
uniform sampler2D colortex5; // color

uniform vec2 screenSize;
uniform vec2 screenPixelSize;
uniform vec3 cameraSpeed;

#include "/lib/Head/Common.inc"

// ======================================================================
// CONFIG
// ======================================================================
// 0 = default
// 1 = smooth / animated
// 2 = Garry's Mod style
// 3 = linear
// 4 = dynamic (only player movement)
// ======================================================================
#define MOTION_BLUR_STYLE 3 // [0 1 2 3 4]

// ===== UE STYLE CLAMP =====
#define MAX_BLUR_RADIUS 40.0   // в пикселях (UE обычно 30–60)

// ======================================================================
// NOISE
// ======================================================================

float InterleavedGradientNoise(in vec2 coord) {
    return fract(52.9829189 * fract(0.06711056 * coord.x + 0.00583715 * coord.y));
}

// ======================================================================
// UE VELOCITY CLAMP (SOFT)
// ======================================================================

vec2 UEVelocityClamp(vec2 velocityPx) {
    float len = length(velocityPx);

    // мягкое сжатие как в Unreal
    float clampedLen = mix(
        len,
        MAX_BLUR_RADIUS,
        smoothstep(MAX_BLUR_RADIUS * 0.6, MAX_BLUR_RADIUS, len)
    );

    return velocityPx * (clampedLen / max(len, 1e-6));
}

// ======================================================================
// MOTION BLUR
// ======================================================================

vec3 MotionBlur() {
    ivec2 texel = ivec2(gl_FragCoord.xy);
    vec2 screenCoord = gl_FragCoord.xy * screenPixelSize;

    vec2 velocity = texelFetch(colortex2, texel, 0).xy;
    vec3 baseColor = texelFetch(colortex5, texel, 0).rgb;

    if (length(velocity) < 1e-7)
        return baseColor;

    // ===== CAMERA SPEED =====
    float horizSpeed = length(cameraSpeed.xz);
    float vertSpeed  = abs(cameraSpeed.y);
    float moveSpeed  = max(horizSpeed, vertSpeed * 0.7);

    float dither  = InterleavedGradientNoise(gl_FragCoord.xy);
    float samples = float(MOTION_BLUR_SAMPLES);
    float rSteps  = rcp(samples);

    // velocity в пикселях (как в UE)
    vec2 blurVelocity = velocity * screenSize;

    // ==================================================================
    // STYLES
    // ==================================================================

    #if MOTION_BLUR_STYLE == 0
        blurVelocity *= MOTION_BLUR_STRENGTH;

    #elif MOTION_BLUR_STYLE == 1
        float smoothFactor = smoothstep(2.0, 12.0, length(blurVelocity));
        smoothFactor *= smoothFactor;
        blurVelocity *= MOTION_BLUR_STRENGTH * smoothFactor;

    #elif MOTION_BLUR_STYLE == 2
        blurVelocity = normalize(blurVelocity + 1e-6) *
                       pow(length(blurVelocity), 1.2) *
                       MOTION_BLUR_STRENGTH * 2.2;

#elif MOTION_BLUR_STYLE == 3
    // LINEAR (50% strength)
    blurVelocity *= MOTION_BLUR_STRENGTH * 0.5;

    #elif MOTION_BLUR_STYLE == 4
        float moveFactor = smoothstep(0.02, 0.15, moveSpeed);
        if (moveFactor < 0.01)
            return baseColor;

        blurVelocity *= MOTION_BLUR_STRENGTH * moveFactor;
    #endif

    // ==================================================================
    // UE VELOCITY CLAMP
    // ==================================================================

    blurVelocity = UEVelocityClamp(blurVelocity);

    // обратно в UV
    blurVelocity *= screenPixelSize;

    // нормализация под количество сэмплов
    blurVelocity *= rSteps;

    vec2 sampleCoord = screenCoord + blurVelocity * dither;
    sampleCoord -= blurVelocity * samples * 0.5;

    vec3 blur = vec3(0.0);

    for (uint i = 0u; i < MOTION_BLUR_SAMPLES; ++i) {
        blur += texelFetch(
            colortex5,
            ivec2(clamp(sampleCoord * screenSize, vec2(2.0), screenSize - 2.0)),
            0
        ).rgb;

        sampleCoord += blurVelocity;
    }

    return clamp16F(blur * rSteps);
}

// ======================================================================
// MAIN
// ======================================================================

void main() {
    #ifdef MOTION_BLUR
        blurColor = MotionBlur();
    #else
        blurColor = texelFetch(colortex5, ivec2(gl_FragCoord.xy), 0).rgb;
    #endif
}
