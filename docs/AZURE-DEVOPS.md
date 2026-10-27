# Building with Azure DevOps

How this port is built: not on a developer's PC but on a Microsoft-hosted Windows machine in Azure Pipelines, from
this GitHub repository. Nothing is installed locally; a run takes a commit of the repository, builds the Xbox
package and publishes it as an artifact to download. (To do the same steps on a Windows PC, see
[BUILDING-ON-WINDOWS.md](BUILDING-ON-WINDOWS.md).)

## One-time setup

1. **An Azure DevOps organization and project** at [dev.azure.com](https://dev.azure.com). A private project is
   fine for the game build.
2. **Hosted agents need a parallel-job allowance.** If a run fails at once with a message about hosted parallelism,
   the message links the form to request the free grant.
3. **Create the pipelines**, one per YAML file (the table below). For each: *Pipelines → New pipeline → GitHub*,
   choose this repository (the first time, approve the *Azure Pipelines* GitHub app for it: on GitHub, Settings →
   Applications → Azure Pipelines → Configure → Repository access), then **Existing Azure Pipelines YAML file**, pick
   the file in the *Path* list, and use the arrow next to *Run* to **Save** (not run). Rename it from its menu.

   The Path list shows every YAML file in the repository, and `/azure-pipelines.yml` among them is the probe, not
   the game. Choosing it by mistake builds three test apps (jobs `low`, `default` and `angle`).

## The pipelines

All three are manual (`trigger: none`): nothing runs on a push.

| Name to give it | YAML file | What it does |
|---|---|---|
| `clang` | `azure-pipelines-clang.yml` | **The game build.** Builds the Xbox package, and with *Target UWP* unticked the desktop Windows version instead. |
| `angle` | `azure-pipelines-angle.yml` | Builds [ANGLE](https://github.com/google/angle) (OpenGL ES on Direct3D 11) for UWP. Needed only to change the prebuilt copy in `overlay/third_party/angle-uwp/`. |
| `probe` | `azure-pipelines.yml` | Small test apps (`tools/uwp-probe`) that show what a UWP app may do on the console. Not part of the game. |

### `clang`

Parameter **Target UWP** (ticked by default). The job (`windows-2022`, 60 minutes at most) does, in order:

1. `git config --global core.autocrlf false`, so the checkout has no line-ending conversion (the patches must match
   byte for byte).
2. Checks out the repository with its submodules, recursively (the PC port, its `decomp/` and `sdk/`).
3. Runs `scripts/prepare.sh` with Git's own `bash`, `tar` and `patch` (Strawberry Perl taken off `PATH`): makes
   `build/pcport-uwp` from the submodule, `patches/sms-port/` and `overlay/`.
4. Runs `tools/ci/clang_survey.ps1 -Build build-clang -Uwp:<the parameter>` in `build/pcport-uwp`: configures with
   CMake, builds with Ninja and clang, packs and signs the `.msix`.
5. Publishes `build/pcport-uwp/build-clang-survey` as the artifact **`clang-survey`**, whatever the outcome.

Step 4 never fails the job, so a green run is not a good build: **open the artifact's `summary.md`** (it is also
attached to the run's summary page) for the count of failed build steps, and check that `bin/` has the package.

### `angle`

Parameters: the ANGLE commit (`angleRef`, pinned to the one that built completely), the minutes Ninja may run
(`ninjaMinutes`, default 35) and `useCache`. A hosted job in a **private** project stops at 60 minutes, which the
checkout and the build exceed: either make the project public (the limit is then 360 minutes and there are more
cores; set `ninjaMinutes` to about 300), or keep it private, tick `useCache` and run it again until `RESULT.txt` in
the artifact says `COMPLETE`. The artifact `angle-uwp` holds `bin/`, `lib/` and `include/`: copy them into
`overlay/third_party/angle-uwp/`, without `d3dcompiler_47.dll` (the package step takes that from the Windows SDK),
and save the change like any other (`scripts/save_patches.sh`).

### `probe`

Matrix of three jobs (`low`, `default`, `angle`); each publishes `uwp-probe-<name>` with a signed `.msix` to install
on the console. It needs no submodule and runs from `overlay/`.

## Running a build

1. *Pipelines → clang → Run pipeline*. Branch `main`, *Target UWP* ticked, *Run*.
2. Open the run. The summary shows the commit it built (the first 7 characters appear in the game's log: see
   below). When it finishes, open **Published** (or the *1 published* link) and download `clang-survey`.
3. Unzip it. For a UWP build `bin/` holds `sms-pc-port-uwp.msix`, `SmsDev.cer`, `Microsoft.VCLibs.x64.14.00.appx`,
   `sms.exe` and `sms.map`. A `bin/` with `SDL2.dll` and no `.msix` is the desktop build: the box was unticked.

## Installing on the console

The console must be in Developer Mode: see *Getting an Xbox into Dev Mode* in
[BUILDING-ON-WINDOWS.md](BUILDING-ON-WINDOWS.md#getting-an-xbox-into-dev-mode), or Microsoft's
[Xbox Developer Mode activation](https://learn.microsoft.com/en-us/windows/uwp/xbox-apps/devkit-activation).

1. Open the Device Portal ([how](https://learn.microsoft.com/en-us/windows/uwp/xbox-apps/device-portal-xbox)).
2. On its Home page, install the VCLibs `.appx` the first time, then the `.msix`. A later build installs **over**
   the app: do not uninstall first, as that deletes `LocalState` (the disc image, the saves, the kept settings).
3. The first time only, put the disc image in `LocalState` (Device Portal, *File explorer*: User Folders →
   LocalAppData → the app's folder → `LocalState`) as `game.iso`.

The package version is `1.0.<day of the year>.<minute of the day>`; it starts again low on 1 January, when the
console refuses an update to a lower number (see [BUILDING-ON-WINDOWS.md](BUILDING-ON-WINDOWS.md)).

## After a run on the console

- `LocalState\sms.log` is the record. Save it (Device Portal, File explorer) and keep one per run, named in order.
  Its `[port] version: ... (abc1234)` line is the commit the build came from: a log and a `sms.map` go together only
  when this matches the commit of the pipeline run the map came from.
- An address in the log, `sms.exe+0x444d61`, is an offset in `sms.exe`. With that build's `sms.map`:
  `python3 scripts/symbolize.py path/to/sms.map 0x444d61` names the function.
- `LocalState\sms-port\` has the memory card (`card-a`), `savestates`, `hud.txt` and `menu-settings.txt` (the pause
  menu's kept settings; delete it to go back to the defaults). `LocalState\sms.out.log` is the game's stdout.
- `LocalState\env.txt` (`NAME=VALUE` per line) sets environment variables for the game at start, for trying things
  without a new build:

  | Line | Effect |
  |---|---|
  | `SMS_SKIP_INTRO=1` | go straight to the title screen |
  | `SMS_SKIP_MOVIES=1` | skip the movies |
  | `SMS_GX_GLCHECK=1` | check every OpenGL call for errors and log them with a stack (slow) |
  | `SMS_GX_GL_THREAD=0` | run OpenGL calls on the game's own thread, not the renderer's |
  | `SMS_GX_SHADER_WARMUP=off` | no shader compile ahead of use |

  `args.txt` in the same folder takes one command-line argument per line.

## Our loop

1. Change the code in the workspace and save it as patches (`scripts/dev_workspace.sh`, `scripts/save_patches.sh`;
   the README's *Changing the code*).
2. Commit and push to `main`.
3. Run `clang` on `main` and check that the run built your commit.
4. Download, install, test on the console.
5. Send back the `sms.log` and the run's `sms.map`; read addresses with `scripts/symbolize.py`.

## When it goes wrong

| What you see | Why |
|---|---|
| Jobs named `low`, `default`, `angle` | the pipeline uses `azure-pipelines.yml` (the probe); recreate it from `azure-pipelines-clang.yml` |
| `bin/` has `SDL2.dll`, no `.msix` | *Target UWP* was not ticked |
| Run is green but there is no `sms.exe` | read `summary.md` and `build-sms.log`: the build step does not fail the job |
| `Prepare the sms-pc-port tree` fails | `patch` or `tar` failed: the step's log names the patch; check the submodules were fetched |
| The log's commit is not the map's | the map is from another run: take it from the run whose commit the log shows |
| Fails at once about parallelism | request the free hosted parallelism grant (the message links the form) |
| Update refused on the console | the new package's version is not higher: see the version note above |
