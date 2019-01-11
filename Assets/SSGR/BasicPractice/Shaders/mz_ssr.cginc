#ifndef MZ_SSR_INCLUDED
#define MZ_SSR_INCLUDED

float2 cb_depthBufferSize;
float cb_zThickness;
float cb_stride;
float cb_maxSteps;
float cb_maxDistance;
float cb_strideZCutoff;
float cb_numMips;
float cb_fadeStart;
float cb_fadeEnd;
float cb_sslr_padding0;

float distanceSquared(float2 a, float2 b)
{
	a -= b;
	return dot(a,a);
}

bool intersectsDepthBuffer(float z, float minZ, float maxZ)
{
	float depthScale = min(1.0, z * cb_strideZCutoff);
	z += cb_zThickness + lerp(0.0, 2.0, depthScale);
	return (maxZ >= z) && (minZ - cb_zThickness <= z);
}

void swap(inout float a, inout float b)
{
	float t = a;
	a = b;
	b = t;
}


#endif
