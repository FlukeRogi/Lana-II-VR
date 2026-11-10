using BepInEx;
using BepInEx.Logging;
using BepInEx.Unity.IL2CPP;
using HarmonyLib;

namespace LanaVR2
{
    internal static class Shaders
    {
        /// <summary>Unity 6's Shader.Find passes its name through a span that Il2CppInterop can't restore, so it throws
        /// MissingMethodException. The loaded shaders are searched by name instead.</summary>
        public static UnityEngine.Shader Find(string name)
        {
            try { var s = UnityEngine.Shader.Find(name); if (s != null) return s; }
            catch (System.MissingMethodException) { }
            foreach (var s in UnityEngine.Resources.FindObjectsOfTypeAll<UnityEngine.Shader>()) if (s.name == name) return s;
            return null;
        }
    }

    internal static class Images
    {
        /// <summary>Unity 6's ImageConversion.EncodeToPNG fails in the interop layer ("Instances of abstract classes cannot
        /// be created"), so the mod writes its own PNG from the texture's pixels: RGBA, no filtering, zlib from .NET.</summary>
        public static byte[] Png(UnityEngine.Texture2D tex)
        {
            int w = tex.width, h = tex.height;
            var px = Pixels(tex);
            var raw = new byte[h * (w * 4 + 1)];
            for (int y = 0; y < h; y++)
            {
                int row = y * (w * 4 + 1), src = (h - 1 - y) * w;   // Unity's rows run bottom-up, PNG's top-down.
                for (int x = 0; x < w; x++)
                {
                    var c = px[src + x]; int o = row + 1 + x * 4;
                    raw[o] = c.r; raw[o + 1] = c.g; raw[o + 2] = c.b; raw[o + 3] = c.a;
                }
            }
            byte[] packed;
            using (var ms = new System.IO.MemoryStream())
            {
                using (var z = new System.IO.Compression.ZLibStream(ms, System.IO.Compression.CompressionLevel.Fastest, true)) z.Write(raw, 0, raw.Length);
                packed = ms.ToArray();
            }
            using var o2 = new System.IO.MemoryStream();
            o2.Write(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A });
            var ihdr = new byte[13];
            BE(ihdr, 0, w); BE(ihdr, 4, h); ihdr[8] = 8; ihdr[9] = 6;
            Chunk(o2, "IHDR", ihdr); Chunk(o2, "IDAT", packed); Chunk(o2, "IEND", new byte[0]);
            return o2.ToArray();
        }

        static UnityEngine.Color32[] Pixels(UnityEngine.Texture2D tex)
        {
            try { return tex.GetPixels32(); }
            catch (System.Exception)
            {
                // The same interop problem can affect array results, so fall back to reading pixel by pixel.
                int w = tex.width, h = tex.height; var px = new UnityEngine.Color32[w * h];
                for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) px[y * w + x] = tex.GetPixel(x, y);
                return px;
            }
        }

        static void BE(byte[] b, int o, int v) { b[o] = (byte)(v >> 24); b[o + 1] = (byte)(v >> 16); b[o + 2] = (byte)(v >> 8); b[o + 3] = (byte)v; }

        static void Chunk(System.IO.Stream s, string type, byte[] data)
        {
            var len = new byte[4]; BE(len, 0, data.Length); s.Write(len);
            var t = System.Text.Encoding.ASCII.GetBytes(type); s.Write(t); s.Write(data);
            uint crc = 0xFFFFFFFF;
            foreach (var b in t) crc = Crc(crc, b);
            foreach (var b in data) crc = Crc(crc, b);
            var c = new byte[4]; BE(c, 0, (int)(crc ^ 0xFFFFFFFF)); s.Write(c);
        }

        static uint[] _table;
        static uint Crc(uint crc, byte b)
        {
            if (_table == null)
            {
                _table = new uint[256];
                for (uint n = 0; n < 256; n++) { uint c = n; for (int k = 0; k < 8; k++) c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1; _table[n] = c; }
            }
            return _table[(crc ^ b) & 0xFF] ^ (crc >> 8);
        }

        static readonly string[] TextureNames = { "_MainTex", "_BaseMap", "_BaseColorMap", "_Albedo", "_AlbedoMap", "_ColorMap", "_Diffuse", "_Texture", "_Tex" };

        /// <summary>A material's colour texture. Some Lana II shaders keep it under a property other than _MainTex,
        /// so mainTexture reads null on them.</summary>
        public static UnityEngine.Texture ColourTexture(UnityEngine.Material m)
        {
            if (m == null) return null;
            if (m.mainTexture != null) return m.mainTexture;
            foreach (var n in TextureNames) if (m.HasProperty(n)) { var t = m.GetTexture(n); if (t != null) return t; }
            try { foreach (var n in m.GetTexturePropertyNames()) { var t = m.GetTexture(n); if (t != null) return t; } }
            catch (System.Exception) { }
            return null;
        }
    }

    [BepInPlugin("com.lanavr.planetoflana2", "LanaVR2", Version)]
    public class Plugin : BasePlugin
    {
        public const string Version = "0.3.0";
        internal static ManualLogSource L;

        public override void Load()
        {
            L = Log;
            Cfg.Bind(Config);
            Log.LogInfo("LanaVR2 loading");
            AddComponent<XrRig>();
            AddComponent<VrMenu>();
            var harmony = new Harmony("com.lanavr.planetoflana2");
            harmony.PatchAll(typeof(VrMenu.BackPatch));
            harmony.PatchAll(typeof(VrMenu.SetValuePatch));
            harmony.PatchAll(typeof(VrMenu.RefreshPatch));
            harmony.PatchAll(typeof(VrMenu.ToggleNextPatch));
            harmony.PatchAll(typeof(VrMenu.TogglePrevPatch));
            harmony.PatchAll(typeof(VrMenu.ToggleFlipPatch));
            harmony.PatchAll(typeof(VrMenu.ToggleRefreshPatch));
            if (!Cfg.LabCommands.Value) Log.LogInfo("Saves and Steam achievements work as normal");
            else
            {
                Log.LogWarning("Developer test mode is on: saves and Steam achievements are blocked");
                harmony.PatchAll(typeof(Lab.BlockSaves));
                harmony.PatchAll(typeof(Lab.BlockAwards));
                AddComponent<Lab>();
            }
        }
    }
}
