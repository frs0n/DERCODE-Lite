
const float overlap = 0.2;

const float rgOverlap = 0.1 * overlap;
const float rbOverlap = 0.01 * overlap;
const float gbOverlap = 0.04 * overlap;

const mat3 coneOverlap = mat3(1.0, 		 rgOverlap, rbOverlap,
							  rgOverlap, 1.0, 		gbOverlap,
							  rbOverlap, rgOverlap, 1.0);

const mat3 coneOverlapInverse = mat3(1.0 + rgOverlap + rbOverlap, -rgOverlap, 				   -rbOverlap,
									 -rgOverlap, 				  1.0 + rgOverlap + gbOverlap, -gbOverlap,
									 -rbOverlap, 				  -rgOverlap, 				   1.0 + rbOverlap + rgOverlap);

// ACES
const mat3 ACESInputMat = mat3(
    0.59719, 0.35458, 0.04823,
    0.07600, 0.90834, 0.01566,
    0.02840, 0.13383, 0.83777
);

const mat3 ACESOutputMat = mat3(
     1.60475, -0.53108, -0.07367,
    -0.10208,  1.10813, -0.00605,
    -0.00327, -0.07276,  1.07602
);

vec3 SEUSTonemap(in vec3 color)
{
	color *= 1.1;

	color *= coneOverlap;

	const float p = 1.5;
	color = pow(color, vec3(p));
	color = color / (1.0 + color);
	color = pow(color, vec3((1.0 / GAMMA) / p));

	color *= coneOverlapInverse;
	//color = saturate(color);

	{
		const float a = 0.3;
		float l = curve(a);

		vec3 c = color * oneMinus(a) + a;
		
		color = curve(c);
		color -= l;
		color /= oneMinus(l);
		color = max0(color);
		//color = pow(color, vec3(1.0));
	}

	{
		vec3 c = color;
		color = mix(color, curve(c), vec3(0.2));
	}

	return color;
}


/////////////////////////////////////////////////////////////////////////////////
// Tonemapping by John Hable
vec3 HableTonemap(in vec3 x)
{
	const float p = 3.0;
	
	x = x * coneOverlap;

	x *= 1.3;

	const float A = 0.15;
	const float B = 0.50;
	const float C = 0.10;
	const float D = 0.20;
	const float E = 0.00;
	const float F = 0.30;

	x = pow(x, vec3(p));

   	vec3 result = pow((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F), vec3(1.0 / p))-E/F;
   	result = saturate(result);

   	result = result * coneOverlapInverse;

   	return result;
}
/////////////////////////////////////////////////////////////////////////////////

vec3 UchimuraTonemap(in vec3 color) {
    const float maxDisplayBrightness = 1.2;  // max display brightness Default:1.2
    const float contrast             = 0.75;  // contrast Default:0.625
    const float linearStart          = 0.15;  // linear section start Default:0.1
    const float linearLength         = 0.02;  // linear section length Default:0.0
    const float black                = 1.4;  // black Default:1.33
    const float pedestal             = 0.0; // pedestal

    float l0 = ((maxDisplayBrightness - linearStart) * linearLength) / contrast;
    float L0 = linearStart - linearStart / contrast;
    float L1 = linearStart + oneMinus(linearStart) / contrast;
    float S0 = linearStart + l0;
    float S1 = linearStart + contrast * l0;
    float C2 = (contrast * maxDisplayBrightness) / (maxDisplayBrightness - S1);
    float CP = -C2 / maxDisplayBrightness;

    vec3 w0 = 1.0 - smoothstep(0.0, linearStart, color);
    vec3 w2 = step(linearStart + l0, color);
    vec3 w1 = 1.0 - w0 - w2;

	vec3 T = linearStart * pow(color / vec3(linearStart), vec3(black)) + vec3(pedestal);
    vec3 S = maxDisplayBrightness - (maxDisplayBrightness - S1) * expf(CP * (color - S0));
    vec3 L = linearStart + contrast * (color - linearStart);

	color *= coneOverlap;

    color = T * w0 + L * w1 + S * w2;

	color *= coneOverlapInverse;
    //color = saturate(color);

	return color;
}

/////////////////////////////////////////////////////////////////////////////////
//	ACES Fitting by Stephen Hill
vec3 RRTAndODTFit(in vec3 v)
{
    vec3 a = v * (v + 0.0245786f) - 0.000090537f;
    vec3 b = v * (v + 0.4329510f) + 0.238081f;
    return a / b;
}

vec3 ACESTonemap2(in vec3 color)
{
	//color *= 1.4;
	color *= coneOverlap;

	//color = color * ACESInputMat;

    // Apply RRT and ODT
    color = RRTAndODTFit(color);

	color *= coneOverlapInverse;

    // Clamp to [0, 1]
	//color = color * ACESOutputMat;
    color = saturate(color);

    return color;
}
/////////////////////////////////////////////////////////////////////////////////

vec3 LottesTonemap(in vec3 color)
{
	color *= 5.0;  // Default: 5.0

	// float peak = max(max(color.r, color.g), color.b);
	float peak = GetLuminance(color);
	vec3 ratio = color / peak;

	//Tonemap here
	const float contrast = 1.0; // Default: 1.1
	const float shoulder = 1.0;
	const float b = 1.0;	//Clipping point
	const float c = 3.0;	//Speed of compression. Default: 5.0

	peak = pow(peak, 1.6);

	float x = peak;
	float z = pow(x, contrast);
	peak = z / (pow(z, shoulder) * b + c);

	peak = pow(peak, 1.0 / 1.6);

	vec3 tonemapped = peak * ratio;

	float tonemappedMaximum = GetLuminance(tonemapped);
	vec3 crosstalk = vec3(5.0, 0.5, 5.0) * 2.0;
	float saturation = 0.9;  // Default: 1.1
	float crossSaturation = 1280.0;  // Default: 1114.0

	ratio = pow(ratio, vec3(saturation / crossSaturation));
	ratio = mix(ratio, vec3(1.0), pow(vec3(tonemappedMaximum), crosstalk));
	ratio = pow(ratio, vec3(crossSaturation));

	vec3 outputColor = peak * ratio;

	return outputColor;
}

vec3 ACESTonemap(in vec3 color)
{
	color *= 0.4;

	vec3 crosstalk = vec3(0.05, 0.2, 0.05) * 2.9;

	float avgColor = GetLuminance(color.rgb);
	const float p = 1.0;
	color = pow(color, vec3(p));
	color = (color * (2.51 * color + 0.03)) / (color * (2.43 * color + 0.59) + 0.14);
	color = pow(color, vec3(1.0 / p));

	float avgColorTonemapped = GetLuminance(color.rgb);

	color = saturate(color);
	color = pow(color, vec3(0.85));

	return color;
}


vec3 None(in vec3 color) {
	return color;
}
