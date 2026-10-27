# Super Mario Sunshine for the Xbox (UWP, Dev Mode)

A UWP build of [chasem-dev/sms-pc-port](https://github.com/chasem-dev/sms-pc-port), the native PC port of Super
Mario Sunshine (GMSE01, NTSC-U), for an Xbox Series X or S in Dev Mode. No game data, art or music is included:
the port reads everything from **your own disc image**.

The PC port is a git submodule here and is never edited. What this port changes in it is a few patches, and what
it adds is a folder of files copied over a copy of it, the same layout as the 3DS port.

## Status: early

Verified on a Series X:

- The game runs from the intro to the title screen and into a stage, with graphics, the controller (and rumble)
  and sound output opened. Menus run at 60 frames a second; the first stage tried ran at about 40.
- The graphics layer is OpenGL ES 3.0 through [ANGLE](https://github.com/google/angle) on Direct3D 11: the PC
  port's OpenGL renderer, its shaders translated to GLES 3.0.
- The pause menu's graphics settings (internal resolution, MSAA, ...) work. Resolution 4x with 8x MSAA takes the
  app over the 1 GB memory limit the console reports; stay at 2x, or 3x without MSAA.

Added last and not yet confirmed on a console: saving to the memory card, and the pause menu's changes being kept
between launches (both under `LocalState\sms-port`). Delfino Plaza has not been tried.

Known gaps from OpenGL ES: no logic ops, 1-pixel lines and points, no sampler LOD bias, the occlusion count is
yes/no. See [overlay/docs/UWP-GRAPHICS.md](overlay/docs/UWP-GRAPHICS.md).

## Installing

You need an Xbox in Dev Mode, with the Device Portal on, and your own Super Mario Sunshine disc image: USA
(GMSE01), a plain `.iso` (a `.gcm` or `.ciso` works too).

1. Run the **clang** pipeline (`azure-pipelines-clang.yml`) with *Target UWP* ticked, and download the
   `clang-survey` artifact. Its `bin/` holds `sms-pc-port-uwp.msix`, the certificate it is signed with
   (`SmsDev.cer`), the VCLibs framework package it depends on, `sms.exe` and `sms.map`.
2. In the Device Portal, install the VCLibs package, then the `.msix`. A later build installs over the app and
   keeps `LocalState`.
3. Put the disc image in the app's `LocalState` folder (Device Portal, file explorer) as `game.iso`.
4. Start the app. `LocalState\sms.log` says what happened.

Optional files in `LocalState`: `env.txt` (one `NAME=VALUE` per line, set as environment variables for the game;
`SMS_SKIP_INTRO=1` goes straight to the title) and `args.txt` (one command-line argument per line).

Saves, save states and the menu's kept settings are in `LocalState\sms-port\`. Back that folder up before
uninstalling the app; delete `menu-settings.txt` to go back to the default settings.

## Building

Builds run on Azure Pipelines (`windows-2022`, clang targeting Windows with the store libraries); this machine
cannot build them. The steps:

```
git clone --recursive <this repository>
scripts/prepare.sh        # build/pcport-uwp: the submodule, patches/sms-port/ applied, overlay/ copied over it
```

then, on Windows with Visual Studio's UWP tools, LLVM clang, CMake and Ninja, in `build/pcport-uwp`:
`tools/ci/clang_survey.ps1 -Uwp`. The pipeline does exactly this.

| Path | What it is |
|---|---|
| `ext/sms-pc-port/` | the PC port (submodule, with its own `decomp/` and `sdk/`), pinned |
| `patches/sms-port/` | this port's edits to files of the PC port, as patches applied in name order |
| `overlay/` | files this port adds, at the paths they have in the tree: `src/uwp/` (the WinRT entry, controller, XAudio2), `src/win_posix/` (the POSIX shim for the msvc target), `platform/gx/src/gx_uwp_egl.*` (ANGLE), `third_party/angle-uwp/` (prebuilt ANGLE), `tools/ci/`, `tools/uwp/` (the manifest), `tools/uwp-probe/`, `decomp-patches/` |
| `scripts/` | `prepare.sh`; and, while the work is still done in the fork, `regenerate_patches.sh` and `verify_against_fork.sh` |
| `azure-pipelines*.yml` | the clang build, the ANGLE build and the UWP probe |

While the work is still done in the fork ([ikevik/sms-pc-port](https://github.com/ikevik/sms-pc-port), branch
`uwp-xbox`), `scripts/regenerate_patches.sh` rebuilds `patches/sms-port/` and `overlay/` from it, and
`scripts/verify_against_fork.sh` checks that the prepared tree is byte for byte the fork's.

The version line in `sms.log` (`[port] version: ... (abc1234)`) shows this repository's commit.

## AI disclosure

This port was made with heavy AI assistance.

- **Written with AI:** nearly all of its code, scripts, patches and documentation were written by Claude,
  Anthropic's model, working through Claude Code: the UWP shell, the ANGLE graphics layer and its shader
  translation, the controller and XAudio2 layers, the msvc/UWP build, the patches to sms-pc-port, and this
  README. Commits carry a `Co-Authored-By: Claude` line.
- **Directed and tested by a person:** the project's author (ikevik) decided what to build, and ran every build
  on a Series X, reporting what it did and sending the logs back.

The game's own code is the decompilation and the PC port in the credits below. Expect mistakes; please report
problems in the issue tracker.

## Credits

| Project | What the port takes from it |
|---|---|
| [chasem-dev/sms-pc-port](https://github.com/chasem-dev/sms-pc-port) | The native PC port this one is built on (`ext/sms-pc-port/`, MIT): everything that plays the game. |
| [chasem-dev/sms-english](https://github.com/chasem-dev/sms-english) | The decompilation the game code is built from (CC0), through the PC port's `decomp/`. |
| [doldecomp/sms](https://github.com/doldecomp/sms) | The Super Mario Sunshine decompilation sms-english forked from (CC0). |
| [ANGLE](https://github.com/google/angle) | OpenGL ES over Direct3D 11 (BSD licence), prebuilt in `overlay/third_party/angle-uwp/`. |
| Microsoft | XAudio2, Windows.Gaming.Input and C++/WinRT, from the Windows SDK. |
| [ikevik/sms-3ds](https://github.com/ikevik/sms-3ds) | The layout of this repository (a submodule, patches, scripts that patch a copy). |

## Licence

The port's own files are under the [MIT licence](LICENSE), the same as sms-pc-port. ANGLE is under its own
licence (see `overlay/third_party/angle-uwp/`). The game is not included and is Nintendo's.
