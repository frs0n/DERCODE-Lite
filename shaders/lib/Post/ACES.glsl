
float rgbToSaturation(in vec3 rgb) {
	float max_component = max(maxOf(rgb), 1e-10);
	float min_component = max(minOf(rgb), 1e-10);

	return (max_component - min_component) / max_component;
}

// Returns a geometric hue angle in degrees (0-360) based on RGB values
// For neutral colors, hue is undefined and the function will return zero (The reference
// implementation returns NaN but I think that's silly)
float rgbToHue(in vec3 rgb) {
	if (rgb.r == rgb.g && rgb.g == rgb.b) return 0.0;

	float hue = (360.0 / TAU) * atan(2.0 * rgb.r - rgb.g - rgb.b, sqrt(3.0) * (rgb.g - rgb.b));

	if (hue < 0.0) hue += 360.0;

	return hue;
}

// Converts RGB to a luminance proxy, here called YC
// YC is ~ Y + K * Chroma
float rgbToYc(in vec3 rgb) {
	const float yc_radius_weight = 1.75;

	float chroma = sqrt(rgb.b * (rgb.b - rgb.g) + rgb.g * (rgb.g - rgb.r) + rgb.r * (rgb.r - rgb.b));

	return (rgb.r + rgb.g + rgb.b + yc_radius_weight * chroma) / 3.0;
}

const mat3 ap0ToXyz = mat3(
	 0.9525523959,  0.0000000000,  0.0000936786,
	 0.3439664498,  0.7281660966, -0.0721325464,
	 0.0000000000,  0.0000000000,  1.0088251844
);
const mat3 xyzToAp0 = mat3(
	 1.0498110175,  0.0000000000, -0.0000974845,
	-0.4959030231,  1.3733130458,  0.0982400361,
	 0.0000000000,  0.0000000000,  0.9912520182
);

const mat3 ap1ToXyz = mat3(
	 0.6624541811,  0.1340042065,  0.1561876870,
	 0.2722287168,  0.6740817658,  0.0536895174,
	-0.0055746495,  0.0040607335,  1.0103391003
);
const mat3 xyzToAp1 = mat3(
	 1.6410233797, -0.3248032942, -0.2364246952,
	-0.6636628587,  1.6153315917,  0.0167563477,
	 0.0117218943, -0.0082844420,  0.9883948585
);

const mat3 ap0ToAp1 = ap0ToXyz * xyzToAp1;
const mat3 ap1ToAp0 = ap1ToXyz * xyzToAp0;

/*
--------------------------------------------------------------------------------
	License Terms for Academy Color Encoding System Components

	Academy Color Encoding System (ACES) software and tools are provided by the
	Academy under the following terms and conditions: A worldwide, royalty-free,
	non-exclusive right to copy, modify, create derivatives, and use, in source and
	binary forms, is hereby granted, subject to acceptance of this license.

	Copyright © 2015 Academy of Motion Picture Arts and Sciences (A.M.P.A.S.).
	Portions contributed by others as indicated. All rights reserved.

	Performance of any of the aforementioned acts indicates acceptance to be bound
	by the following terms and conditions:

	* Copies of source code, in whole or in part, must retain the above copyright
	notice, this list of conditions and the Disclaimer of Warranty.

	* Use in binary form must retain the above copyright notice, this list of
	conditions and the Disclaimer of Warranty in the documentation and/or other
	materials provided with the distribution.

	* Nothing in this license shall be deemed to grant any rights to trademarks,
	copyrights, patents, trade secrets or any other intellectual property of
	A.M.P.A.S. or any contributors, except as expressly stated herein.

	* Neither the name "A.M.P.A.S." nor the name of any other contributors to this
	software may be used to endorse or promote products derivative of or based on
	this software without express prior written permission of A.M.P.A.S. or the
	contributors, as appropriate.

	This license shall be construed pursuant to the laws of the State of
	California, and any disputes related thereto shall be subject to the
	jurisdiction of the courts therein.

	Disclaimer of Warranty: THIS SOFTWARE IS PROVIDED BY A.M.P.A.S. AND CONTRIBUTORS
	"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
	THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND
	NON-INFRINGEMENT ARE DISCLAIMED. IN NO EVENT SHALL A.M.P.A.S., OR ANY
	CONTRIBUTORS OR DISTRIBUTORS, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
	SPECIAL, EXEMPLARY, RESITUTIONARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
	LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
	PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
	LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
	OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
	ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

	WITHOUT LIMITING THE GENERALITY OF THE FOREGOING, THE ACADEMY SPECIFICALLY
	DISCLAIMS ANY REPRESENTATIONS OR WARRANTIES WHATSOEVER RELATED TO PATENT OR
	OTHER INTELLECTUAL PROPERTY RIGHTS IN THE ACADEMY COLOR ENCODING SYSTEM, OR
	APPLICATIONS THEREOF, HELD BY PARTIES OTHER THAN A.M.P.A.S.,WHETHER DISCLOSED OR
	UNDISCLOSED.
--------------------------------------------------------------------------------
*/

// Constants
const float rrtGlowGain  = 0.05;   	// Default: 0.05
const float rrtGlowMid   = 0.08;   	// Default: 0.08

const float rrtRedScale  = 1.0;  	// Default: 0.82
const float rrtRedPivot  = 0.03;    // Default: 0.03
const float rrtRedHue    = 0.0;     // Default: 0.0
const float rrtRedWidth  = 135.0; 	// Default: 135.0

const float rrtSatFactor = 0.96; 	// Default: 0.96
const float odtSatFactor = 0.93; 	// Default: 0.93

const float rrtGammaCurve = 1.0;	// Default: 1.0
const float odtGammaCurve = 1.0;    // Default: 1.0

// "Glow module" functions
float GlowFwd(in float yc_in, in float glow_gain_in, in const float glow_mid) {
	float glow_gain_out;

	if (yc_in <= 2.0 / 3.0 * glow_mid)
		glow_gain_out = glow_gain_in;
	else if (yc_in >= 2.0 * glow_mid)
		glow_gain_out = 0.0;
	else
		glow_gain_out = glow_gain_in * (glow_mid / yc_in - 0.5);

	return glow_gain_out;
}

// Sigmoid function in the range 0 to 1 spanning -2 to +2
float SigmoidShaper(in float x) {
	float t = max0(1.0 - abs(0.5 * x));
	float y = 1.0 + sign(x) * oneMinus(t * t);

	return 0.5 * y;
}

float CubicBasisShaperFit(in float x, in const float width) {
	float radius = 0.5 * width;
	return abs(x) < radius
		? sqr(curve(1.0 - abs(x) / radius))
		: 0.0;
}

float CenterHue(in float hue, in float centerH) {
	float hueCentered = hue - centerH;

	if (hueCentered < -180.0) {
		return hueCentered + 360.0;
	} else if (hueCentered > 180.0) {
		return hueCentered - 360.0;
	} else {
		return hueCentered;
	}
}

vec3 RRTSweeteners(in vec3 ACES2065) {
	// Glow module
	float saturation = rgbToSaturation(ACES2065);
	float ycIn = rgbToYc(ACES2065);
	float s = SigmoidShaper(5.0 * saturation - 2.0);
	float addedGlow = 1.0 + GlowFwd(ycIn, rrtGlowGain * s, rrtGlowMid);

	ACES2065 *= addedGlow;

	// Red modifier
	float hue = rgbToHue(ACES2065);
	float centeredHue = CenterHue(hue, rrtRedHue);
	float hueWeight = CubicBasisShaperFit(centeredHue, rrtRedWidth);

	ACES2065.r += hueWeight * saturation * (rrtRedPivot - ACES2065.r) * oneMinus(rrtRedScale);

    // Transform AP0 ACES2065-1 to AP1 ACEScg
    ACES2065 = clamp16F(ACES2065);

	vec3 ACEScg = clamp16F(ACES2065 * ap0ToAp1);

	// Global desaturation
	float luminance = GetLuminance(ACEScg);
	ACEScg = mix(vec3(luminance), ACEScg, rrtSatFactor);

	// Added gamma adjustment before the RRT
	ACEScg = pow(ACEScg, vec3(rrtGammaCurve));

	return ACEScg;
}

/*
 * RRT + ODT fit by Stephen Hill
 * https://github.com/TheRealMJP/BakingLab/blob/master/BakingLab/ACES.hlsl
 */
vec3 RRTAndODTFit(in vec3 rgb) {
	vec3 a = rgb * (rgb + 0.0245786) - 0.000090537;
	vec3 b = rgb * (0.983729 * rgb + 0.4329510) + 0.238081;

	return a / b;
}

// ACES RRT and ODT approximation
vec3 AcademyFit(in vec3 rgb) {
	rgb *= 1.4; // Match the exposure to the RRT

	rgb = RRTSweeteners(rgb * ap1ToAp0);
	rgb = RRTAndODTFit(rgb);

	// Global desaturation
	rgb = mix(vec3(GetLuminance(rgb)), rgb, odtSatFactor);

	#ifdef COLOR_GRADING
		rgb = Contrast(rgb * BRIGHTNESS);
		rgb = pow(rgb, vec3(rcp(GAMMA)));
		rgb = ColorSaturation(rgb, SATURATION);
		#if WHITE_BALANCE != 6500
			rgb *= WhiteBalanceMatrix();
		#endif
	#endif

	return LinearToSRGB(rgb);
}

//------------------------------------------------------------------------------------------------//

const mat3 xyzToSRGB = mat3(
	 3.2409699419, -1.5373831776, -0.4986107603,
	-0.9692436363,  1.8759675015,  0.0415550574,
	 0.0556300797, -0.2039769589,  1.0569715142
);

const mat3 d60ToD65 = mat3(
	 0.9872240000, -0.0061132700,  0.0159533000,
	-0.0075983600,  1.0018600000,  0.0053300200,
	 0.0030725700, -0.0050959500,  1.0816800000
);

const mat3 ap0ToSRGB = ap1ToXyz * d60ToD65 * xyzToSRGB;

vec4 splineOperator(in vec4 aces) {
    aces   *= 1.313;

    vec4 a  = aces * (aces + 0.0313) - 0.00006;
    vec4 b  = aces * (0.983729 * aces + 0.5129510) + 0.168081;

    return clamp16F(a / b);
}

vec3 academyCustom(in vec3 ACES2065) {
    const float white = PI * 4.0;
    //const splineParam curve = splineParam(0.0313, 0.00006, 0.983729, 0.5129510, 0.168081);

    vec3 rgbPre         = RRTSweeteners(ACES2065);

    vec4 mapped         = splineOperator(vec4(rgbPre, white)/*, curve*/);

    vec3 mappedColor    = mapped.rgb / mapped.a;

    // Global Desaturation as it would be done in the Output Device Transform (ODT) otherwise
        mappedColor     = mix(vec3(GetLuminance(mappedColor)), mappedColor, odtSatFactor);
        mappedColor     = clamp(mappedColor, 0.0, 65000.0);

    // Added Gamma Correction to allow for color response tuning
        mappedColor     = pow(mappedColor, vec3(odtGammaCurve));

    return mappedColor * ap1ToAp0;
}

vec3 AcademyCustom(in vec3 rgb) {
	rgb = academyCustom(rgb * ap1ToAp0) * ap0ToSRGB;

	#ifdef COLOR_GRADING
		rgb = Contrast(rgb * BRIGHTNESS);
		rgb = pow(rgb, vec3(rcp(GAMMA)));
		rgb = ColorSaturation(rgb, SATURATION);
		#if WHITE_BALANCE != 6500
			rgb *= WhiteBalanceMatrix();
		#endif
	#endif

	return LinearToSRGB(rgb);
}
