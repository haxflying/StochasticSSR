Shader "Unlit/uvTest"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			#define vec2 float2
			#define mix lerp
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			vec2 hash( vec2 x )  // replace this by something better
			{
			    const vec2 k = vec2( 0.3183099, 0.3678794 );
			    x = x*k + k.yx;
			    return -1.0 + 2.0*frac( 16.0 * k*frac( x.x*x.y*(x.x+x.y)));
			}

			float noise( in vec2 p )
			{
			    vec2 i = floor( p );
			    vec2 f = frac( p );
				
				vec2 u = f * f * f * (6 * f * f - 15 * f + 10);

			    return mix( mix( dot( hash( i + vec2(0.0,0.0) ), f - vec2(0.0,0.0) ), 
			                     dot( hash( i + vec2(1.0,0.0) ), f - vec2(1.0,0.0) ), u.x),
			                mix( dot( hash( i + vec2(0.0,1.0) ), f - vec2(0.0,1.0) ), 
			                     dot( hash( i + vec2(1.0,1.0) ), f - vec2(1.0,1.0) ), u.x), u.y);
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				float2 center = 0.5;				
				float u = length(i.uv - center + 0.5 * noise(i.uv * 3))/ 0.71 - _Time.y;
				float v = dot(normalize(i.uv - center), float2(1, 0)) * 2;

				float2 uv = float2(u, v);
				fixed4 col = tex2D(_MainTex, uv);
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
