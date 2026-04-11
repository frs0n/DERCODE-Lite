flat out float exposure;

#include "/lib/Head/Common.inc"
#include "/lib/Head/Uniforms.inc"

#ifdef DOF_ENABLED
    flat out float centerDepthSmooth;
#endif



// EXPOSURE_STYLE 0 //[Off/Original, UE5 Cinematic, CoD HDR, UE5 Balanced, Vanilla-like, Smooth, Bliss-like, Realistic]

#ifndef EXPOSURE_STYLE
    #define EXPOSURE_STYLE 0 // [1 2 3 4 5 6 7 0]
#endif


#if EXPOSURE_STYLE == 0

    float CalculateAverageExposure() {
        const float tileSize = exp2(float(AUTO_EXPOSURE_LOD));

        ivec2 tileSteps = ivec2(screenSize * rcp(tileSize));

        float exposure = 0.0;
        float sumWeight = 0.0;

        for (uint x = 0u; x < tileSteps.x; ++x) {
            for (uint y = 0u; y < tileSteps.y; ++y) {
                float luminance = GetLuminance(texelFetch(colortex4, ivec2(x, y), AUTO_EXPOSURE_LOD).rgb);

                float weight = 1.0 - remap(0.25, 0.75, length(vec2(x, y) / tileSteps * 2.0 - 1.0));
                weight = curve(weight) * 0.9 + 0.1;

                exposure += max(log(luminance), -18.0) * weight;
                sumWeight += weight;
            }
        }

        exposure /= max(sumWeight, 1.0);

        return expf(exposure * 0.75);
    }

#endif

// ---- Параметры для стилей (1–7) ----
#if EXPOSURE_STYLE >= 1

    #if EXPOSURE_STYLE == 1   // UE5 Cinematic
        #define MIDDLE_GREY             0.36
        #define EXPOSURE_BIAS           -0.4
        #define ADAPT_SPEED_BRIGHTEN    2.2
        #define ADAPT_SPEED_DARKEN      1.4
        #define MAX_LUMINANCE_CLAMP     18.0
        #define MIN_EXPOSURE            0.04
        #define MAX_EXPOSURE            6.5
        #define CENTER_WEIGHT_POWER     2.0
        #define CENTER_BIAS_MULTIPLIER  1.5

    #elif EXPOSURE_STYLE == 2   // CoD HDR
        #define MIDDLE_GREY             0.30
        #define EXPOSURE_BIAS           0.6
        #define ADAPT_SPEED_BRIGHTEN    4.5
        #define ADAPT_SPEED_DARKEN      3.0
        #define MAX_LUMINANCE_CLAMP     30.0
        #define MIN_EXPOSURE            0.015
        #define MAX_EXPOSURE            12.0
        #define CENTER_WEIGHT_POWER     1.4
        #define CENTER_BIAS_MULTIPLIER  1.15

    #elif EXPOSURE_STYLE == 3   // UE5 Balanced
        #define MIDDLE_GREY             0.40
        #define EXPOSURE_BIAS           0.0
        #define ADAPT_SPEED_BRIGHTEN    3.0
        #define ADAPT_SPEED_DARKEN      1.8
        #define MAX_LUMINANCE_CLAMP     20.0
        #define MIN_EXPOSURE            0.05
        #define MAX_EXPOSURE            8.0
        #define CENTER_WEIGHT_POWER     1.8
        #define CENTER_BIAS_MULTIPLIER  1.35

    #elif EXPOSURE_STYLE == 4   // Vanilla-like
        #define MIDDLE_GREY             0.18
        #define EXPOSURE_BIAS           0.0
        #define ADAPT_SPEED_BRIGHTEN    1.5
        #define ADAPT_SPEED_DARKEN      1.0
        #define MAX_LUMINANCE_CLAMP     25.0
        #define MIN_EXPOSURE            0.02
        #define MAX_EXPOSURE            10.0
        #define CENTER_WEIGHT_POWER     1.0
        #define CENTER_BIAS_MULTIPLIER  1.0

    #elif EXPOSURE_STYLE == 5   // Smooth
        #define MIDDLE_GREY             0.32
        #define EXPOSURE_BIAS           -0.15
        #define ADAPT_SPEED_BRIGHTEN    1.1
        #define ADAPT_SPEED_DARKEN      0.9
        #define MAX_LUMINANCE_CLAMP     16.0
        #define MIN_EXPOSURE            0.08
        #define MAX_EXPOSURE            5.0
        #define CENTER_WEIGHT_POWER     2.2
        #define CENTER_BIAS_MULTIPLIER  1.6

    #elif EXPOSURE_STYLE == 6   // Bliss-like
        #define MIDDLE_GREY             0.28
        #define EXPOSURE_BIAS           0.4
        #define ADAPT_SPEED_BRIGHTEN    3.8
        #define ADAPT_SPEED_DARKEN      2.5
        #define MAX_LUMINANCE_CLAMP     22.0
        #define MIN_EXPOSURE            0.025
        #define MAX_EXPOSURE            9.0
        #define CENTER_WEIGHT_POWER     1.6
        #define CENTER_BIAS_MULTIPLIER  1.25

    #elif EXPOSURE_STYLE == 7   // Realistic
        #define MIDDLE_GREY             0.38
        #define EXPOSURE_BIAS           -0.25
        #define ADAPT_SPEED_BRIGHTEN    2.0
        #define ADAPT_SPEED_DARKEN      1.6
        #define MAX_LUMINANCE_CLAMP     15.0
        #define MIN_EXPOSURE            0.06
        #define MAX_EXPOSURE            7.0
        #define CENTER_WEIGHT_POWER     2.1
        #define CENTER_BIAS_MULTIPLIER  1.45

    #endif

    // ---- Функция для стилей 1–7  ----
    float CalculateWeightedExposure() {
        const int lod = AUTO_EXPOSURE_LOD;
        const float scale = exp2(float(lod));
        const ivec2 tileRes = ivec2(screenSize / scale + 0.5);

        float sumLum = 0.0;  
        float sumWeight = 0.0;

        for (int x = 0; x < tileRes.x; ++x) {
            for (int y = 0; y < tileRes.y; ++y) {
                vec2 uv = (vec2(x, y) + 0.5) / vec2(tileRes);
                float dist = length(uv - 0.5) * 1.414213562;

                float weight = 1.0 - smoothstep(0.0, 1.0, dist * dist);
                weight = pow(weight, CENTER_WEIGHT_POWER) * CENTER_BIAS_MULTIPLIER + 0.08;

                vec3 colorSample = texelFetch(colortex4, ivec2(x, y), lod).rgb;
                float lum = GetLuminance(colorSample);

                lum = clamp(lum, 1e-5, MAX_LUMINANCE_CLAMP);

                sumLum += lum * weight;  
                sumWeight += weight;
            }
        }

        if (sumWeight < 1e-4) return MIDDLE_GREY;

        return sumLum / sumWeight;  
    }

#endif

// ---- MAIN ----
void main() {
    gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);

    #ifdef AUTO_EXPOSURE

        #if EXPOSURE_STYLE == 0
   
            float sceneLum = CalculateAverageExposure();

            #if defined IS_END
                const float K = 12.0;
            #else
                const float K = 19.0;
            #endif

            const float calibration = exp2(AUTO_EXPOSURE_BIAS) * K * 1e-2;

            const float a = K * 1e-2 * 18.0;
            const float b = a - K * 1e-2 * 0.04;

            float targetExposure = calibration / (a - b * expf(-sceneLum * rcp(b)));

            float prevExposure = clamp16F(texelFetch(colortex5, ivec2(0), 0).a);

            float speed = targetExposure < prevExposure ? 1.5 : 1.0;
            exposure = mix(targetExposure, prevExposure, expf(-speed * frameTime * EXPOSURE_SPEED));

        #else
          
            float sceneLum = CalculateWeightedExposure();

     
            #if defined IS_END
                const float K = 12.0;
            #else
                const float K = 19.0;
            #endif

    
            float calibration = exp2(EXPOSURE_BIAS) * K * 1e-2 * (0.18 / MIDDLE_GREY);

            const float a = K * 1e-2 * 18.0;
            const float b = a - K * 1e-2 * 0.04;

            float targetExposure = calibration / (a - b * expf(-sceneLum * rcp(b)));
            
           
            targetExposure = clamp(targetExposure, MIN_EXPOSURE, MAX_EXPOSURE);

            float prevExposure = clamp16F(texelFetch(colortex5, ivec2(0), 0).a);
            if (prevExposure <= 0.0) prevExposure = targetExposure;

           
            float speed = (targetExposure < prevExposure) ? ADAPT_SPEED_DARKEN : ADAPT_SPEED_BRIGHTEN;
            
            exposure = mix(targetExposure, prevExposure, expf(-speed * frameTime * EXPOSURE_SPEED));
        #endif

    #else
        exposure = rcp(MANUAL_EXPOSURE_VALUE) * 0.8;
    #endif

    #ifdef DOF_ENABLED
        float centerDepth = texelFetch(depthtex2, ivec2(screenSize * 0.5), 0).x * 2.0 - 1.0;
        centerDepth = 1.0 / (centerDepth * gbufferProjectionInverse[2][3] + gbufferProjectionInverse[3][3]);
        float prevCenterDepth = texelFetch(colortex5, ivec2(1), 0).a;
        centerDepthSmooth = mix(prevCenterDepth, centerDepth, saturate(expf(-0.1 / (frameTime * FOCUSING_SPEED)) / (centerDepth + 0.2)));
    #endif
}
