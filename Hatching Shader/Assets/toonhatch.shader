Shader "Unlit/Toon Cell"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _HatchColor ("Hatch Color", color) = (0,0,0,1)
        
        [NoScaleOffset] _MainTex ("Texture", 2D) = "white" {}
        [HDR]
        _AmbientColor ("Ambient Color", Color) = (0.4,0.4,0.4,1)
        [HDR]
        _SpecularColor ("Specular Color", Color) = (1,1,1,1)
        _Glossiness ("Glossiness", float) = 32
        //[HDR]
        //_OutlineColor ("Outline Color", Color) = (0,0,0,1)
        //_OutlineAmount ("Outline Amount", Range(0,1)) = 0.5
        //_OutlineThreshold ("Outline Threshold", Range(0,1)) = 0.1

        _Hatch0("Hatch 0 (light)", 2D) = "white" {}
		_Hatch1("Hatch 1 (dark)", 2D) = "white" {}
        _HatchScale ("Hatch Scale" , Range(0,100)) = 20
        _HatchCutoff ("Hatch Cutoff", Range(-5,5)) = -0.05
        _Tune1 ("Tuning1", Range(0,10)) = 0
        _Tune2 ("Tuning2", Range(0,10)) = 1.57
        _Tune3 ("Tuning3", Range(0,10)) = 2.39
        _Tune4 ("Tuning4", Range(0,10)) = 2.4
        _Tune5 ("Tuning5", Range(0,10)) = 6.88
        _Tune6 ("Tuning6", Range(0,10)) = 4.93

    }
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque"
            "LightMode" = "ForwardBase"
            "PassFlags" = "OnlyDirectional"
        }
        Pass
        {
            

            CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			// For light direction
            #include "Lighting.cginc" 
			
            // Shadow stuff
            #pragma fullforwardshadows
            #pragma noforwardadd
            #pragma multi_compile_fwdbase
            #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
			#include "AutoLight.cginc"

            float4 _Color;
            float4 _AmbientColor;
            float4 _SpecularColor;
            float _Glossiness;
            float4 _OutlineColor;
            float _OutlineAmount;
            float _OutlineThreshold;


            //Hatching shading
            float _HatchScale;
            float _HatchCutoff;
            sampler2D _Hatch0;
			sampler2D _Hatch1;
            float4 _HatchColor;
            float _Tune1;
            float _Tune2;
            float _Tune3;
            float _Tune4;
            float _Tune5;
            float _Tune6;
            

            float3 Hatching (float2 uv, float lightIntensity)
            {
                float3 hatch0 = tex2D(_Hatch0, uv).rgb;
                float3 hatch1 = tex2D(_Hatch1, uv).rgb;
                
                //lightIntensity = clamp(0.1, 1, lightIntensity);
                float3 maxBrightness = max(0, lightIntensity - 1.0) + _HatchCutoff;
                //float3 maxBrightness = _HatchCutoff;

                float3 weights0 = lightIntensity * 6 + float3(-_Tune1, -_Tune2, -_Tune3);
                float3 weights1 = lightIntensity * 6 + float3(-_Tune4, -_Tune5, -_Tune6);

                // Subtracting so the sum of the weights does not exceed 1
                weights0.xy -= weights0.yz;
                weights0.z -= weights1.x;
                weights1.xy -= weights1.yz;

                hatch0 *= weights0;
                hatch1 *= weights1;

                float hatch = maxBrightness + hatch0.r + hatch0.g + hatch0.b + hatch1.r + hatch1.g + hatch1.b; 
                hatch = (hatch);
                return hatch;
            }

            struct meshData
            {
                float4 pos : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct Interpolators
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 normal : NORMAL; 
                float3 viewDir : TEXCOORD2;
                SHADOW_COORDS(1)
            };

            

            Interpolators vert (meshData v)
            {
                Interpolators o; 
				o.pos = UnityObjectToClipPos(v.pos);
                o.normal = UnityObjectToWorldNormal(v.normal);		
				o.viewDir = WorldSpaceViewDir(v.pos);
                o.uv = v.uv;
				TRANSFER_SHADOW(o)
                return o;
            }
 
            fixed4 frag (Interpolators i) : SV_Target
            {
                float shadow = SHADOW_ATTENUATION(i);
                float3 normal = normalize(i.normal);
                float3 viewDir = normalize(i.viewDir);
                float2 uv = i.uv;

                // Calculating diffuse (lambert) light
                float3 lightPos = _WorldSpaceLightPos0;
                float diffuse = dot(lightPos, normal);
                float lightIntensity = saturate(diffuse * shadow);
                lightIntensity = smoothstep(0, 1, lightIntensity);
                float4 lightColor = lightIntensity * _LightColor0;

                //Specular light Blinn-Phong 
                float3 halfVector = normalize(lightPos + viewDir);
                float specular = dot(normal, halfVector);
                float SpecLightIntensity = smoothstep(0, 0.01, diffuse * shadow); // Gives it the toon look
                float specularIntensity = pow(specular * SpecLightIntensity, _Glossiness * _Glossiness);
                float specularIntensitySmooth = smoothstep(0.005, 0.01, specularIntensity);
                float4 specularColor = specularIntensitySmooth * _SpecularColor;

                // Fresnel outline
                // float4 outlineDot = 1 - dot(viewDir, normal);
                // float outlineIntensity = outlineDot * pow(diffuse, _OutlineThreshold);
                // outlineIntensity = smoothstep(_OutlineAmount - 0.01, _OutlineAmount + 0.01, outlineIntensity);
                // float4 outlineColor = outlineIntensity * _OutlineColor * shadow;

                float4 hatch = saturate(float4(Hatching(uv * _HatchScale, lightIntensity), 1));
                float4 baseColor = _Color * (_AmbientColor + lightColor + specularColor);
                float4 finalColor = lerp(_HatchColor, baseColor, hatch);
                // float4 col = _Color * (_AmbientColor + lightColor + specularColor) * hatch;
                return finalColor;

            }
            ENDCG
        }
        
        UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
}
