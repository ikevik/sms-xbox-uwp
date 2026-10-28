# Multiplayer on the console

The PC port's multiplayer ([ext/multiplayer](https://github.com/chasem-dev/sms-pc-port/blob/main/ext/multiplayer/README.md))
is built into this port. It is peer to peer over UDP: one game **hosts** (port 24002 unless another is chosen), up to
seven others **join** it by address, everyone plays the host's level on the host's save. The launcher this port is
getting will have Host and Join screens; until then it is started from `env.txt`.

**Status: not yet tried on a console.** The package declares the network capabilities from the build that added them
(without them the console blocks all networking), and the rest is the PC port's own code, which already runs in this
build. The first test is what this page describes.

## What you need

- The package from a build that has the capabilities (`internetClient`, `internetClientServer` and
  `privateNetworkClientServer` in `AppxManifest.xml`): install it over the old one as usual.
- A second game running a **compatible build**. By default both games must be the same build, which is the commit
  in the `[port] version: ... (abc1234)` line of `sms.log`:
  - another console with the same package, or
  - a Windows PC with the pipeline's **desktop** build from the same commit (run the `clang` pipeline once with
    *Target UWP* unticked: `bin/` then has `sms.exe` and `SDL2.dll`; start it with `sms.exe path\to\GMSE01.iso`
    and the variables below set in the environment).
  - A game of another build is refused unless the host sets `SMS_MULTIPLAYER_VERSIONS=drift`, and even then the
    multiplayer protocol must be the same. The refusal names what it needs.
- The two on the same network. Over the internet the host forwards UDP 24002 on their router.

## Hosting (on the console)

`LocalState\env.txt`:

```
SMS_MULTIPLAYER=host
SMS_MULTIPLAYER_NAME=Console
```

Start the app. `sms.log` lists the addresses the console has, one per line:

```
[uwp] network address: 192.168.1.50
```

Give the other player the IPv4 address (and the port, if you set `SMS_MULTIPLAYER_PORT`). To accept a game of
another build, add `SMS_MULTIPLAYER_VERSIONS=drift`.

## Joining (on the console)

```
SMS_MULTIPLAYER=join
SMS_MULTIPLAYER_ADDRESS=192.168.1.50
SMS_MULTIPLAYER_NAME=Console
SMS_SAVE_DIR={LocalState}/sms-port/card-guest
```

`{LocalState}` is the app's `LocalState` folder. The last line gives the joining game a memory card of its own: what
it plays is the host's save, and the guest card keeps the host's game away from your own saves. (Leave it out and the
joining game uses the normal card.) A joining player goes straight into the host's level.

Remember to put the file back (or empty it) afterwards: the game starts in multiplayer every time while it says so.

## Other variables

`SMS_MULTIPLAYER_MAX_PLAYERS`, `SMS_MULTIPLAYER_TIMEOUT`, `SMS_MULTIPLAYER_STATUS`, `SMS_MULTIPLAYER_NAMES`,
`SMS_MULTIPLAYER_COLLISION` and the rest are in the PC port's multiplayer README, in the *Starting it* table. They
all go in `env.txt` the same way.

## If it does not work

- Nothing joins, no error: the package has no network capabilities (an older build), or a firewall (a PC's) or the
  router blocks UDP 24002.
- "Refused" with a version: the two builds differ; host with `SMS_MULTIPLAYER_VERSIONS=drift`, or use the same
  commit on both.
- Send `sms.log` from both sides: the `[multiplayer]` lines say what each game heard.
