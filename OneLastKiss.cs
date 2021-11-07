using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.HighDefinition;
using System;
using UnityEngine.Experimental.Rendering;

[Serializable, VolumeComponentMenu("Post-processing/Custom/OneLastKiss")]
public sealed class OneLastKiss : CustomPostProcessVolumeComponent, IPostProcessComponent
{
    [Tooltip("Controls the intensity of the effect.")]
    public ClampedFloatParameter intensity = new ClampedFloatParameter(0f, 0f, 1f);
    public ClampedIntParameter radius = new ClampedIntParameter(1, 0, 10);
    public ColorParameter colorA = new ColorParameter(Color.red);
    public ColorParameter colorB = new ColorParameter(Color.blue);
    public ClampedFloatParameter grandientRotate = new ClampedFloatParameter(45f, 0f, 360f);

    Material m_Material;
    MaterialPropertyBlock _prop;

    public bool IsActive() => m_Material != null && intensity.value > 0f;

    // Do not forget to add this post process in the Custom Post Process Orders list (Project Settings > Graphics > HDRP Settings).
    public override CustomPostProcessInjectionPoint injectionPoint => CustomPostProcessInjectionPoint.AfterPostProcess;

    const string kShaderName = "Hidden/Shader/OneLastKiss";

    public override void Setup()
    {
        if(Shader.Find(kShaderName) != null) {
            m_Material = new Material(Shader.Find(kShaderName));
            _prop = new MaterialPropertyBlock();
        } else
            Debug.LogError($"Unable to find shader '{kShaderName}'. Post Process Volume OneLastKiss is unable to load.");
    }

    RTHandle LineCaptureRT;

    public override void Render(CommandBuffer cmd, HDCamera camera, RTHandle source, RTHandle destination)
    {
        if (m_Material == null)
            return;

        if(LineCaptureRT != null) LineCaptureRT.Release();

        m_Material.SetFloat("_Intensity", intensity.value);
        m_Material.SetInt("_Radius", radius.value);
        m_Material.SetColor("_ColorA", colorA.value);
        m_Material.SetColor("_ColorB", colorB.value);
        m_Material.SetFloat("_GrandientRotate", grandientRotate.value);

        _prop.SetTexture("_SourceTexture", source);
        LineCaptureRT = RTHandles.Alloc(camera.actualWidth, camera.actualHeight, colorFormat: GraphicsFormat.R16G16B16A16_SFloat);
        HDUtils.DrawFullScreen(cmd, m_Material, LineCaptureRT, _prop, 0);

        _prop.SetTexture("_InputTexture", LineCaptureRT);
        HDUtils.DrawFullScreen(cmd, m_Material, destination, _prop, 1);
    }

    public override void Cleanup()
    {
        CoreUtils.Destroy(m_Material);
        RTHandles.Release(LineCaptureRT);
    }
}
