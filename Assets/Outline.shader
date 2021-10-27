Shader "Hidden/Roystan/Outline Post Process"
{
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
			// Custom post processing effects are written in HLSL blocks,
			// with lots of macros to aid with platform differences.
			// https://github.com/Unity-Technologies/PostProcessing/wiki/Writing-Custom-Effects#shader
            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment Frag

			#include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"

			TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
			// _CameraNormalsTexture contains the view space normals transformed
			// to be in the 0...1 range.
			TEXTURE2D_SAMPLER2D(_CameraNormalsTexture, sampler_CameraNormalsTexture);
			TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);
        
			// Data pertaining to _MainTex's dimensions.
			// https://docs.unity3d.com/Manual/SL-PropertiesInPrograms.html
			float4 _MainTex_TexelSize;
			float _Scale;
			float _DepthThreshold;

			// Combines the top and bottom colors using normal blending.
			// https://en.wikipedia.org/wiki/Blend_modes#Normal_blend_mode
			// This performs the same operation as Blend SrcAlpha OneMinusSrcAlpha.
			float4 alphaBlend(float4 top, float4 bottom)
			{
				float3 color = (top.rgb * top.a) + (bottom.rgb * (1 - top.a));
				float alpha = top.a + bottom.a * (1 - top.a);

				return float4(color, alpha);
			}

			float4 Frag(VaryingsDefault i) : SV_Target
			{
				float halfScaleFloor = floor(_Scale * 0.5); //these two values alternatively increment by one as _Scale increases. By scaling our UVs this way, we are able to increment our edge
				float halfScaleCeil = ceil(_Scale * 0.5); //width exactly one pixel at a time—achieving a maximum possible granularity—while still keeping the coordinates centred around i.texcoord.

				float2 bottomLeftUV = i.texcoord - float2(_MainTex_TexelSize.x, _MainTex_TexelSize.y) * halfScaleFloor;
				float2 topRightUV = i.texcoord + float2(_MainTex_TexelSize.x, _MainTex_TexelSize.y) * halfScaleCeil;
				float2 bottomRightUV = i.texcoord + float2(_MainTex_TexelSize.x * halfScaleCeil, -_MainTex_TexelSize.y * halfScaleFloor);
				float2 topLeftUV = i.texcoord + float2(-_MainTex_TexelSize.x * halfScaleFloor, _MainTex_TexelSize.y * halfScaleCeil);

				float depth0 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, bottomLeftUV).r;
				float depth1 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, topRightUV).r;
				float depth2 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, bottomRightUV).r;
				float depth3 = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, topLeftUV).r;

				float depthFiniteDifference0 = depth1 - depth0; // début de the Roberts cross : une edge detection operator
				float depthFiniteDifference1 = depth3 - depth2; // on prend la différence des deux pixels diagonallement opposés et ... 
				float edgeDepth = sqrt(pow(depthFiniteDifference0, 2) + pow(depthFiniteDifference1, 2)) * 100; //on compute the sum of squares of the two values (et *100 pour rendre les différences de depth plus facilement visibles)

				float depthThreshold = _DepthThreshold * depth0; // vu que la depth n'est pas linear, il faut moduler le threshold en fonction de la depth existante pour que les trucs du fond aient des contours clean
				edgeDepth = edgeDepth > depthThreshold ? 1 : 0;
				return edgeDepth;

				float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord); //sample the image on screen 
				return color;
			}
			ENDHLSL
		}
    }
}