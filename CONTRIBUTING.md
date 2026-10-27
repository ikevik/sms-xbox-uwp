# Contributing

Pull requests and bug reports are welcome.

## Rules for changes

- **The submodule is never edited.** A change to a file of sms-pc-port goes in a patch in `patches/sms-port/`;
  a new file goes in `overlay/`, at the path it has in the tree. `scripts/prepare.sh` builds `build/pcport-uwp`
  from them, and that is where the build and the CI scripts run.
- **Changes that are not about the console** (a fix in the PC port itself) belong upstream, in
  [chasem-dev/sms-pc-port](https://github.com/chasem-dev/sms-pc-port); a patch here should only carry what the
  UWP build needs.
- One topic per pull request, in plain words: what was wrong or missing, what changed, why it is correct, and
  what you tested (which console, which stage, the `sms.log` lines that show it).
- Nothing from the game: no disc files, extracted assets, art, music or links to them.
- Nothing personal: no `/Users/<name>` paths, real names, account IDs or device names in files, patches, logs or
  commit messages.
- AI assistance is welcome, as long as you say so (a `Co-Authored-By:` line in the commit is enough) and the
  result is tested like any other change.

## Testing

Builds run in CI and the result runs on a console: a change that touches graphics, threads, memory or audio is
not done until it has run on one. `LocalState\sms.log` is the record: the `[uwp]` heartbeat lines give the frame
rate and memory use every 5 seconds, `[audio]` and `[settings]` lines the output and the kept settings, and a
crash prints its address as `sms.exe+0x...`, which `sms.map` (in the build's artifact) names.

## Bugs

Open an issue with: the console, the build's version line from `sms.log`, where it happened and what you saw, and
`sms.log` attached (without anything personal in it).

## Licence

Contributions are under the repository's [MIT licence](LICENSE).
