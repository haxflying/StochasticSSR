using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[System.Serializable]
public enum ResolutionMode
{
    halfRes = 2,
    fullRes = 1,
};

public class Stochastic : MonoBehaviour {
    [SerializeField]
    Shader StochasticShader;
    [SerializeField]
    ResolutionMode depthMode = ResolutionMode.halfRes;
    [SerializeField]
    ResolutionMode rayMode = ResolutionMode.halfRes;
    [SerializeField]
    int rayDistance = 70;


    private CommandBuffer cb_ssgr;
    private Camera cam;
    private Material renderMaterials;

    private Matrix4x4 projectionMatrix;
    private Matrix4x4 viewProjectionMatrix;
    private Matrix4x4 inverseViewProjectionMatrix;
    private Matrix4x4 worldToCameraMatrix;
    private Matrix4x4 cameraToWorldMatrix;
    private Matrix4x4 prevViewProjectionMatrix;

    

    private void Initialize()
    {
        cam = GetComponent<Camera>();
        cb_ssgr = new CommandBuffer();
        cb_ssgr.name = "SSGR";
        renderMaterials = new Material(StochasticShader);
        renderMaterials.hideFlags = HideFlags.HideAndDontSave;
        cam.AddCommandBuffer(CameraEvent.AfterForwardOpaque, cb_ssgr);
    }

    private void OnPreRender()
    {
        if (cb_ssgr == null)
            return;

        cb_ssgr.Clear();
        int width = cam.pixelWidth;
        int height = cam.pixelHeight;

        int rayWidth = width / (int)rayMode;
        int rayHeight = height / (int)rayMode;

        int rayCast = Shader.PropertyToID("_RayCast");
        int rayCastMask = Shader.PropertyToID("_RayCastMask");
        int depthBuffer = Shader.PropertyToID("_CameraDepthBuffer");

        cb_ssgr.GetTemporaryRT(rayCast, rayWidth, rayHeight, 0, FilterMode.Point, RenderTextureFormat.ARGBHalf);
        cb_ssgr.GetTemporaryRT(rayCastMask, rayWidth, rayHeight, 0, FilterMode.Point, RenderTextureFormat.RHalf);
        cb_ssgr.GetTemporaryRT(depthBuffer, width / (int)depthMode, width / (int)depthMode, 0, FilterMode.Bilinear, RenderTextureFormat.RGFloat);

        cb_ssgr.SetRenderTarget(depthBuffer);
        cb_ssgr.Blit(null, BuiltinRenderTextureType.CurrentActive, )
    }
}
