# Lana-II-VR: developer notes

Plays Planet of Lana II: Children of the Leaf on a floating virtual screen in VR, with a full render per eye and window-style head tracking. Works through OpenXR on SteamVR and Virtual Desktop VDXR. Player documentation is in [README.md](README.md) and [install/README.txt](install/README.txt).

The code started as a copy of [Planet of Lana VR](https://github.com/FlukeRogi/LanaVR), the mod for the first game, so most of its design notes apply here too. In the code the mod is called LanaVR2: plugin id `com.lanavr.planetoflana2`, `LanaVR2.dll` and `LanaVR2Native.dll`.

## How it works

The game is 64-bit IL2CPP on **Unity 6** (6000.0.61), D3D11 by default, built-in render pipeline with Post Processing v2, in **linear** colour space. The mod runs on BepInEx 6 (bleeding edge build 791).

- **[src/XrRig.cs](src/XrRig.cs)** renders each eye. The virtual screen is a rectangle in tracking space, mapped to the plane in the game world at Lana's depth. Each eye gets a view offset and an off-axis frustum through that rectangle.
- **[native/LanaVR2Native.cpp](native/LanaVR2Native.cpp)** owns the OpenXR session and submits one world-locked quad layer per eye.
- **[native/Skybox.cpp](native/Skybox.cpp)** draws the sky, the lake and its reflections as a projection layer behind the screen. [src/Skybox.cs](src/Skybox.cs) watches the loaded `Chapter NN ... Backdrop` scene and picks a sky from `skybox/skyboxes.txt`.
- **[src/Scenery.cs](src/Scenery.cs)** builds the pier, boats and poles from the game's own meshes at run time. It loads `Chapter 03 Scene 10` (the stilt village) additively from the main menu, switches it off before any `Start`, and copies the textured `Tai_` props.
- **[src/VrMenu.cs](src/VrMenu.cs)** clones the game's Settings Audio view for the VR page.

## Lana II and Unity 6 differences

- **Interop gaps:** some Unity 6 engine calls fail under Il2CppInterop because they pass strings or arrays through spans it can't restore:
  - `Shader.Find`: use `Shaders.Find`, which falls back to scanning loaded shaders.
  - `SceneManager.LoadSceneAsync(name)` and `Application.CanStreamedLevelBeLoaded`: load by build index (`Scenery.BuildIndex`).
  - `ImageConversion.EncodeToPNG`: use `Images.Png`.
- **Folded methods:** IL2CPP merges identical method bodies. `WindowsStandalonePlatform.Award` shares its native code with hundreds of unrelated methods, and patching it crashed the game. Lab mode logs each target's native address and only patches code that isn't shared.
- **Saves:** there's no single `Platform` class. Lab mode blocks `SteamPlatform.Save/Award` and `WindowsStandalonePlatform.Save`.
- **Renamed classes:** `VolumeLight` became `PoL.Rendering.VolumetricLight`. `ShaderVariables.Update` and `VolumetricLight.LateUpdate` are called per eye.
- **Menu names:** texts are named after their localisation keys (`Localized - Settings_Audio`), so the VR page finds its title and labels by structure.
- **Scenery art:** the village's `Std_Pg_` kit, which the first game's scenery used, is untextured in Lana II. Its painted buildings are statically batched. The deck's top is a rim 7 cm above its planks (`DeckRaise`). Poles are stood upright from the longest copy in the level, because the village uses them at every angle and scale.
- **Intro video:** Chapter 1 opens with a pre-rendered video, about 3.5 minutes long. Holding B skips it. Lab jumps and the game's `Skip` event are ignored while it plays.

## Skies

`skybox/skyboxes.txt` maps each backdrop to a sky from the purchased Fantasy Skybox pack, which stays out of the repository. `tools\pack_skies.ps1` packs the listed images into `skybox\*.lvsky`, encrypted with AES-256-CBC. The key is in `native\SkyKey.h`, which the script creates the first time and which stays out of the repository. A build without it still works with plain PNG and JPG skies, but can't read the included ones. `Tint: * / PP Inside`, `PP Wemari Cave` and `PP Tunnel Sequence` dim the sky to 40% indoors and in caves.

## Build

Needs Visual Studio C++ build tools, CMake and the .NET 8 SDK, with the game installed and BepInEx run once to generate `BepInEx\interop`. The OpenXR loader NuGet package is unpacked in `tools\openxr`, and the BepInEx zip in `tools\dl\bepinex`.

```bash
cmake -S native -B native/build -G "Visual Studio 17 2022" -A x64
```

```bash
cmake --build native/build --config Release
```

```bash
dotnet build LanaVR2.csproj -c Release
```

The C# build deploys to the game folder. Pass `-p:NoDeploy=true` to build without deploying. `tools\make_package.ps1` makes the release zip in `dist`.

## Test

```bash
powershell -ExecutionPolicy Bypass -File tests/run_tests.ps1 -Slot 2
```

This drives the real game with a mock OpenXR runtime ([native/mock/MockRuntime.cpp](native/mock/MockRuntime.cpp)) and a virtual gamepad, from save slot 2 only. The test command channel exists only when `Debug.LabCommands = true` in the mod's config, which also blocks every save write and achievement. Set it back to false afterwards.

Useful Lab tools for the scenery:
- `propload <level>`, then `propnames <regex>`: lists a level's copyable props, with size and texture.
- `propgallery <name>|<regex>`: photographs each prop in its own tile.
- `scenerylist`: prints the built props' bounds.
- `deckprobe x z halfWidth`: measures the plank height.
