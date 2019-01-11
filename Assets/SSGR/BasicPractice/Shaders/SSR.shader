Shader "Hidden/SSR"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			#include "UnityDeferredLibrary.cginc"
			#include "mz_ssr.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;				
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 rayDirVS : TEXCOORD1;
				float4 vertex : SV_POSITION;
				float test : TEXCOORD2;
			};

			#define MAX_TRACE_DIS 50
			#define MAX_IT_COUNT 60
			#define STEP_SIZE 0.1
			#define EPSION 0.1
			sampler2D _CameraGBufferTexture0;// Diffuse RGB, Occlusion A
			sampler2D _CameraGBufferTexture1;// Specular RGB, Smoothness A
			sampler2D _CameraGBufferTexture2;// Normal RGB

			float4x4 _NormalMatrix;

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				//depth is 1
				o.rayDirVS = mul(unity_CameraInvProjection, float4((float2(v.uv.x, v.uv.y) - 0.5) * 2, 1, 1));
				return o;
			}
			
			sampler2D _MainTex;
			sampler2D _Gbuffer0Mip;
			float _mipFactor;

			float2 PosToUV(float3 vpos)
			{
				float4 proj_pos = mul(unity_CameraProjection, float4(vpos ,1));
    			float3 screenPos = proj_pos.xyz/proj_pos.w;	
    			return float2(screenPos.x,screenPos.y) * 0.5 + 0.5;
			}

			float compareWithDepthAndNormal(float3 vpos, float3 normal, out bool inside, out float normalDiff)
			{					
				float2 uv = PosToUV(vpos);
    			float depth = tex2D (_CameraDepthTexture, uv);
    			float3 p_normal = tex2D (_CameraGBufferTexture2, uv).xyz * 2.0 - 1.0;
    			depth = LinearEyeDepth (depth);// * _ProjectionParams.z; 
    			inside = (uv.x >= 0 && uv.y <= 1 && uv.y >=0 && uv.y <= 1 && abs(vpos.z) < _ProjectionParams.z);
    			normalDiff = dot(normal, p_normal);			
    			return depth + vpos.z;
			}

			bool traceScreenSpaceRay(float3 csOrig, float3 csDir, float jitter, out float2 hitPixel, out float3 hitPoint)
			{
				//clip to near plane
				float rayLength = ((csOrig.z + csDir.z * cb_maxDistance) < _ProjectionParams.y) ?
				(_ProjectionParams.y - csOrig.z) / csDir.z : cb_maxDistance;
				float3 csEndPoint = csOrig + csDir * rayLength;

				//project into homogeneous clip space
				float4 H0 = mul(unity_CameraProjection, float4(csOrig, 1.0));
				H0.xy *= cb_depthBufferSize;
				float4 H1 = mul(unity_CameraProjection, float4(csEndPoint, 1.0));				
				H1.xy *= cb_depthBufferSize;

				float k0 = 1.0/H0.w;
				float k1 = 1.0/H1.w;

				//interpolated homogeneous version of cam space points
				float3 Q0 = csOrig * k0;
				float3 Q1 = csEndPoint * k1;

				//screen space endpoints
				float2 p0 = H0.xy * k0;
				float2 p1 = H1.xy * k1;

				//make sure the line at least cover one pixel
				p1 += (distanceSquared(p0, p1) < 0.0001f) ? float2(0.01f,0.01f) : 0.0f;
				float2 delta = p1 - p0;

				bool permute = false;
				if(abs(delta.x) < abs(delta.y))
				{
					//more vertical line
					permute = true;
					delta = delta.yx;
					p0 = p0.yx;
					p1 = p1.yx;
				}

				float stepDir = sign(delta.x);
				float invdx = stepDir / delta.x;

				//track the derivatives of Q and K
				float3 dQ = (Q1 - Q0) * invdx;
				float dk = (k1 - k0) * invdx;
				float2 dp = float2(stepDir, delta.y * invdx);

				//scale derivatives by the desired pixel stride and then offset the starting value by the jitter fraction
				float strideScale = 1.0 - min(1.0, csOrig.z * cb_strideZCutoff);
				float stride = 1.0 + strideScale * cb_stride;
				dp *= stride;
				dQ *= stride;
				dk *= stride;

				p0 += dp * jitter;
				Q0 += dQ * jitter;
				k0 += dk * jitter;

				//slide p from p0 to p1, q from q0 to q1, k from k0 to k1
				float4 pqk = float4(p0, Q0.z, k0);
				float4 dpqk = float4(dp, dQ.z, dk);
				float3 Q = Q0;

				//adjust end condition for iteration direction
				float end = p1.x * stepDir;

				float stepCount = 0.0;
				float prevZMaxEstimate = csOrig.z;
				float rayZMin = prevZMaxEstimate;
				float rayZMax = prevZMaxEstimate;
				float sceneZMax = rayZMax + 100.0;
				for (;((pqk.x * stepDir) <= end) && (stepCount < cb_maxSteps) && (!intersectsDepthBuffer(sceneZMax, rayZMin, rayZMax)) && (sceneZMax != 0.0); ++stepCount)
				{
					rayZMin = prevZMaxEstimate;
					rayZMax = (dpqk.z * 0.5 + pqk.z) / (dpqk.w * 0.5 + pqk.w);
					prevZMaxEstimate = rayZMax;
					if(rayZMin > rayZMax)
					{
						swap(rayZMin, rayZMax);
					}

					hitPixel = permute ? pqk.yx : pqk.xy;
					float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, hitPixel);
    				depth = Linear01Depth (depth);
					sceneZMax = depth;

					pqk += dpqk;
				}

				Q.xy += dQ * stepCount;
				hitPoint = Q * (1.0/pqk.w);
				return intersectsDepthBuffer(sceneZMax, rayZMin, rayZMax);
			}


			bool rayTrace(float3 o, float3 r, float3 n, out float3 hitp, out float len)
			{
				float3 start = o;
				float3 end = o;
				for (int i = 2; i <= MAX_IT_COUNT + 2; ++i)
				{
					float3 end = o + r * STEP_SIZE * i;
					bool isInside = true;
					float normalDiff = 0;
					float diff = compareWithDepthAndNormal(end, n, isInside, normalDiff);
					if(isInside)
					{
						if(abs(diff) < EPSION && normalDiff < 0.5)
						{
							hitp = end;
							len = length(end - start);
							return true;
						}

						if(length(end - start) > MAX_TRACE_DIS)
						{
							return false;
						}
					}
					else
					{
						return false;
					}
				}
				return false;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				fixed4 col = tex2D(_MainTex, i.uv);
				
				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
    			depth = Linear01Depth (depth);
    			float3 view_pos = i.rayDirVS.xyz/i.rayDirVS.w * depth;  			   				
    			float3 normal = tex2D (_CameraGBufferTexture2, i.uv).xyz * 2.0 - 1.0;
    			//normal = normalize(mul(float4(normal, 0), UNITY_MATRIX_V));    			
    			normal = mul((float3x3)_NormalMatrix, normal);
    			float3 reflectedRay = normalize(reflect(view_pos, normal));

    			//return fixed4(normalize(reflectedRay), 1);

    			float3 hitp = 0;
    			float length = 0;
    			if(rayTrace(view_pos, reflectedRay, normal, hitp, length))
    			{
    				float2 tuv = PosToUV(hitp);	

    				float3 hitCol = tex2Dlod(_CameraGBufferTexture0, half4(tuv,0, length / _mipFactor));
    				float4 hitSpecA = tex2D (_CameraGBufferTexture1, tuv);

    				//col = fixed4(hitp,1);
    				col += fixed4(hitCol, 1);
    				//col += fixed4((hitCol + hitSpecA.rgb), 1);
    			}
    			float4 test = mul(unity_CameraProjection, float4(view_pos, 1.0));
    			return col;
    			//return (-view_pos/test.w).z;
    			//return tex2D(_MainTex, float2(screenPos.x,screenPos.y) * 0.5 + 0.5);

    			//float3 wpos = mul(_CamToWorld, view_pos);
			}
			ENDCG
		}
	}
}
