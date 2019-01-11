using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
[ImageEffectAllowedInSceneView]
public class ImageEffects : MonoBehaviour {

    public Material std;
    [Range(0.1f,10f)]
    public float mipFactor = 1f;

    public Shader ssrShader;
    private Material mat;

    private Camera cam;
    private CommandBuffer cb;
    private RenderTextureDescriptor descriptor;
    private int g0ID;

    private void Start()
    {
        mat = new Material(ssrShader);
        cam = Camera.main;
        descriptor = new RenderTextureDescriptor(Screen.width, Screen.height, RenderTextureFormat.ARGB32);
        descriptor.autoGenerateMips = true;
        cb = new CommandBuffer();
        cb.name = "g0 copy";
        cam.AddCommandBuffer(CameraEvent.AfterGBuffer, cb);
        g0ID = Shader.PropertyToID("_Gbuffer0Mip");
    }

    [ImageEffectOpaque]
    private void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        if(mat == null)
        {
            Graphics.Blit(src, dst);
        }
        else
        {
            //cb.GetTemporaryRT(g0ID, descriptor);
            //cb.Blit(BuiltinRenderTextureType.GBuffer0, g0ID);
            mat.SetMatrix("_NormalMatrix", Camera.current.worldToCameraMatrix);
            mat.SetFloat("_mipFactor", mipFactor);
            Graphics.Blit(src, dst, mat, 0);
            //cb.ReleaseTemporaryRT(g0ID);
        }
    }

    void RaycastCornerBlit(RenderTexture source, RenderTexture dest, Material mat)
    {
        // Compute Frustum Corners
        float camFar = cam.farClipPlane;
        float camFov = cam.fieldOfView;
        float camAspect = cam.aspect;

        float fovWHalf = camFov * 0.5f;

        Vector3 toRight = cam.transform.right * Mathf.Tan(fovWHalf * Mathf.Deg2Rad) * camAspect;
        Vector3 toTop = cam.transform.up * Mathf.Tan(fovWHalf * Mathf.Deg2Rad);

        Vector3 topLeft = (cam.transform.forward - toRight + toTop);
        float camScale = topLeft.magnitude * camFar;

        topLeft.Normalize();
        topLeft *= camScale;

        Vector3 topRight = (cam.transform.forward + toRight + toTop);
        topRight.Normalize();
        topRight *= camScale;

        Vector3 bottomRight = (cam.transform.forward + toRight - toTop);
        bottomRight.Normalize();
        bottomRight *= camScale;

        Vector3 bottomLeft = (cam.transform.forward - toRight - toTop);
        bottomLeft.Normalize();
        bottomLeft *= camScale;

        // Custom Blit, encoding Frustum Corners as additional Texture Coordinates
        RenderTexture.active = dest;

        mat.SetTexture("_MainTex", source);

        GL.PushMatrix();
        GL.LoadOrtho();

        mat.SetPass(0);

        GL.Begin(GL.QUADS);

        GL.MultiTexCoord2(0, 0.0f, 0.0f);
        GL.MultiTexCoord(1, bottomLeft);
        GL.Vertex3(0.0f, 0.0f, 0.0f);

        GL.MultiTexCoord2(0, 1.0f, 0.0f);
        GL.MultiTexCoord(1, bottomRight);
        GL.Vertex3(1.0f, 0.0f, 0.0f);

        GL.MultiTexCoord2(0, 1.0f, 1.0f);
        GL.MultiTexCoord(1, topRight);
        GL.Vertex3(1.0f, 1.0f, 0.0f);

        GL.MultiTexCoord2(0, 0.0f, 1.0f);
        GL.MultiTexCoord(1, topLeft);
        GL.Vertex3(0.0f, 1.0f, 0.0f);

        GL.End();
        GL.PopMatrix();
    }
}
