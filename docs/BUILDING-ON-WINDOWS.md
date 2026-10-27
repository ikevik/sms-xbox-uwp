# Building on Windows (clang, UWP)

The Xbox package is built with LLVM clang targeting Windows (`x86_64-pc-windows-msvc`) against the Windows store
(UWP) libraries. The Azure pipeline ([AZURE-DEVOPS.md](AZURE-DEVOPS.md)) runs exactly the steps below, so a Windows
PC reproduces a pipeline build. A Mac or Linux machine cannot build it.

This page is written from the CI script, `tools/ci/clang_survey.ps1`, which is what the pipeline runs and what has
been tested. The author has not run the steps on a Windows PC of their own: if one of them fails there, the script
and `summary.md` (below) say where.

## What you need

- **Windows 10 or 11, x64.**
- **Visual Studio 2022** (Community is enough), with the workloads *Desktop development with C++* and *Universal
  Windows Platform development*. They bring the store libraries, the Windows SDK, and the packaging tools
  (`makeappx.exe`, `signtool.exe`) the script uses. The script finds Visual Studio with `vswhere` and sets up the
  environment itself (`vcvarsall.bat x64 uwp`), so a Developer Command Prompt is not needed.
- **LLVM clang** (the pipeline's is 19.1.5). The script uses `clang++` from `PATH`, else `%ProgramFiles%\LLVM\bin`,
  else the one bundled with Visual Studio (the component *C++ Clang tools for Windows*), else it installs LLVM with
  Chocolatey.
- **CMake**, **Ninja** (Visual Studio's bundled copies are found) and **Python 3**.
- **Git for Windows.** Its `bash`, `tar` and `patch` run `scripts/prepare.sh`, and its `patch` applies the decomp
  patches. Strawberry Perl's `patch.exe` asserts on them: take Strawberry Perl off `PATH` (the steps below do it for
  the session).
- Windows PowerShell 5.1 (the pipeline's). If scripts are blocked: `Set-ExecutionPolicy -Scope Process Bypass`.

## Steps

1. **No line-ending conversion, before you clone.** The patches must match the sources byte for byte.

   ```powershell
   git config --global core.autocrlf false
   git clone --recursive https://github.com/ikevik/sms-xbox-uwp.git
   cd sms-xbox-uwp
   ```

   `--recursive` brings the PC port and, inside it, the game's sources (`decomp/`) and the mod SDK (`sdk/`).

2. **Prepare the tree.** This copies the PC port to `build\pcport-uwp`, applies `patches/sms-port/` and copies
   `overlay/` over it:

   ```powershell
   $env:PATH = (($env:PATH -split ';') | Where-Object { $_ -and $_ -notmatch 'Strawberry' }) -join ';'
   $env:PATH = "$env:ProgramFiles\Git\usr\bin;$env:PATH"
   & "$env:ProgramFiles\Git\bin\bash.exe" scripts/prepare.sh
   ```

   It starts from nothing each time, `build-clang` inside it included. Do not run it again between rebuilds
   unless the patches or overlay changed.

3. **Build.** From the prepared tree:

   ```powershell
   cd build\pcport-uwp
   .\tools\ci\clang_survey.ps1 -Build build-clang -Uwp
   ```

   `-Uwp` builds the Xbox package. Without it the script builds the desktop Windows version (`sms.exe` and
   `SDL2.dll`, which it downloads), for a PC. The script stops after `-TimeoutMin` minutes (default 50) and always
   exits 0, so the logs are kept: **read `build-clang-survey\summary.md`** for the number of failed build steps and
   the error locations, and `configure.log`, `build-game.log` and `build-sms.log` for the detail. Running it again
   continues the Ninja build where it was.

4. **The result** is in `build-clang-survey\bin\`:

   | File | What it is |
   |---|---|
   | `sms-pc-port-uwp.msix` | the signed package to install on the Xbox |
   | `SmsDev.cer` | the certificate it is signed with |
   | `Microsoft.VCLibs.x64.14.00.appx` | the framework package it depends on |
   | `sms.exe`, `sms.map` | the executable, and its link map for reading addresses in a log (`scripts/symbolize.py`) |

   The package version is `1.0.<day of the year>.<minute of the day>`, so a later build installs over an earlier
   one and keeps its `LocalState` (the disc image, the saves). It starts again from a low number on 1 January: a
   build made then has a lower version than one installed before, and the console refuses to update it.

   Packaging makes a self-signed certificate, `CN=SmsDev`, in your user certificate store (`Cert:\CurrentUser\My`)
   and leaves it there; the pipeline's agent is thrown away, a PC is not. To remove the certificates:
   `Get-ChildItem Cert:\CurrentUser\My | Where-Object Subject -eq 'CN=SmsDev' | Remove-Item`.

## Installing it

Put the Xbox in Developer Mode first (below), then follow the README's *Installing*.

### Getting an Xbox into Dev Mode

Developer Mode runs your own apps on a retail Xbox One or Series X|S. In it the console cannot play retail games or
run retail apps; you switch back and forth. Microsoft's steps are on
**[Xbox Developer Mode activation](https://learn.microsoft.com/en-us/windows/uwp/xbox-apps/devkit-activation)**. In
short:

1. Install the **Xbox Dev Mode** app from the Microsoft Store on the console and start it: it shows an activation
   code.
2. Register an app developer account in **Partner Center** (the activation page links to it).
3. Sign in at `partner.microsoft.com/xboxconfig/devices`, enter the code and agree. An account has a limited number
   of activations.
4. In the Xbox Dev Mode app choose *Switch and restart*. Switching back is *Leave Dev Mode* in Dev Home.

The **Device Portal** (a web page served by the console, used to install the package and to read and write its
files) is described on [Device Portal for Xbox](https://learn.microsoft.com/en-us/windows/uwp/xbox-apps/device-portal-xbox).
To turn it on: in Dev Home, on the Home tab, under *Remote Access* choose *Remote Access Settings*, tick *Enable Xbox
Device Portal* and set a user name and password. The address to open from your PC's browser is then listed under
*Remote Access* on the Home tab; the browser warns about the certificate, which is expected.

## When it fails

- **`summary.md` names no errors but there is no `sms.exe`:** read the last lines of `build-sms.log`; a link error
  is there.
- **Patches fail to apply in `prepare.sh`:** line endings (`core.autocrlf` must be `false` when you clone) or
  Strawberry Perl's `patch.exe` first on `PATH`.
- **"Visual Studio not found":** the script needs the installer's `vswhere.exe` under `Program Files (x86)`.
- **No `.msix` in `bin\`:** `-Uwp` was left off, or packaging failed; the script prints `packaging failed` and why.
