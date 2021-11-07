Shader "Hidden/Shader/OneLastKiss"
{
    HLSLINCLUDE

    #pragma target 4.5
    #pragma only_renderers d3d11 playstation xboxone xboxseries vulkan metal switch

    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/PostProcessing/Shaders/FXAA.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/PostProcessing/Shaders/RTUpscale.hlsl"

    struct Attributes
    {
        uint vertexID : SV_VertexID;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings
    {
        float4 positionCS : SV_POSITION;
        float2 texcoord   : TEXCOORD0;
        UNITY_VERTEX_OUTPUT_STEREO
    };

    Varyings Vert(Attributes input)
    {
        Varyings output;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
        output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID);
        output.texcoord = GetFullScreenTriangleTexCoord(input.vertexID);
        return output;
    }

    // List of properties to control your post process effect
    float _Intensity;
    TEXTURE2D_X(_SourceTexture);
    TEXTURE2D(_InputTexture);
    int _Radius;
    float4 _ColorA;
    float4 _ColorB;
    float _GrandientRotate;

    float GetNearbyMax(uint2 uv,int radius) {
    	float maxValue = Luminance(LOAD_TEXTURE2D_X(_SourceTexture, uv));
    	for (int x = -radius; x < radius; x++)
    	{
    		for (int y = -radius; y < radius; y++)
    		{
    			int2 pixelOffset = int2(x, y);
    			maxValue = max(maxValue, Luminance(LOAD_TEXTURE2D_X(_SourceTexture, uv + pixelOffset)));
    		}
    	}
    	return maxValue;
    }

    float4 LineCapturePass(Varyings input) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

		uint2 positionSS = uint2(input.positionCS.xy);
		float col = Luminance(LOAD_TEXTURE2D_X(_SourceTexture, positionSS));
		float maxValue = GetNearbyMax(positionSS,_Radius);
		col /= maxValue;

        return float4(col.xxx, 1);
    }

    float2 Unity_Rotate_Degrees_float(float2 UV, float2 Center, float Rotation)
    {
    	Rotation = Rotation * (3.1415926f / 180.0f);
    	UV -= Center;
    	float s = sin(Rotation);
    	float c = cos(Rotation);
    	float2x2 rMatrix = float2x2(c, -s, s, c);
    	rMatrix *= 0.5;
    	rMatrix += 0.5;
    	rMatrix = rMatrix * 2 - 1;
    	UV.xy = mul(UV.xy, rMatrix);
    	UV += Center;
    	return UV;
    }

    float4 ColoringLinePass(Varyings input) : SV_Target
    {
    	UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    	float2 uv = input.texcoord.xy;

	float Grandient = Unity_Rotate_Degrees_float(uv, float2(0.5,0.5), _GrandientRotate).x;
	Grandient = distance(Grandient, 0.5);

	float3 GrandientColor = lerp(_ColorA,_ColorB, Grandient);

	uint2 positionSS = uint2(input.positionCS.xy);
	float3 col = LOAD_TEXTURE2D(_InputTexture, positionSS).rgb;

	float3 output = GrandientColor * (1 - col);

	float3 source = LOAD_TEXTURE2D_X(_SourceTexture, positionSS).rgb;

	return float4(lerp(source, output, _Intensity), 1);
    }

    ENDHLSL

    SubShader
    {
        Name "OneLastKiss"

        ZWrite Off
        ZTest Always
        Blend Off
        Cull Off
	Pass
	{
	    HLSLPROGRAM
	    #pragma vertex Vert
	    #pragma fragment LineCapturePass
	    ENDHLSL
	} 
	Pass
	{
	    HLSLPROGRAM
	    #pragma vertex Vert
	    #pragma fragment ColoringLinePass
	    ENDHLSL
	}
    }
    Fallback Off
}
