# nix-acid-boot

An acid-green (and other colors) Nix snowflake
[Plymouth](https://www.freedesktop.org/wiki/Software/Plymouth/) boot
splash for NixOS — with a **live tail of the boot log** rendered right
on the splash, during boot *and* shutdown.

![the acid-green splash: logo, live boot-log tail, passphrase prompt](assets/boot.gif)

![both artworks in all six palettes](assets/palettes.png)

<sub>Two bundled artworks — the Nix snowflake and a flower of life —
in `acid-green`, `golden-yellow`, `nix-blue`, `furry-pink`, `doom-red`
and `cool-gray`. Bring your own SVG and it's colored the same way.</sub>

## What you get

- **Glowing artwork generated at build time** from a vector source, so
  the repo carries no raster art. Fades in, holds, fades out after
  unlock; shakes on a wrong passphrase.
- **Live log tail** — the last 5 console lines under the logo, styled
  by severity (`[ OK ]` dark acid, failures red, warnings amber),
  older lines dimming. During shutdown the tail shows the stop
  sequence, so the unit a stop job is stuck on is visible instead of
  hidden behind a frozen splash.
- **LUKS passphrase dialog** with configurable label (default
  `Enter Password`), asterisk bullets, and a blinking cursor.
- **Two bundled artworks** — the Nix snowflake and a flower of life —
  selected with `acidBoot.logo`, or bring your own SVG with
  `acidBoot.logoSvg` and it is recolored to the palette and re-rendered
  crisply at every size.
- **Or your own image, verbatim.** Point `acidBoot.logoFile` at any PNG
  and it replaces the artwork — used as-is, fitted to the same layout slot
  with its aspect ratio preserved, so wordmarks and banners work as
  well as square logos. The build derives the whole size ladder from
  it, so it stays sharp on high-DPI panels too.
- **Six color palettes** — `acid-green`, `golden-yellow`, `nix-blue`,
  `furry-pink`, `doom-red`, `cool-gray` — recoloring the artwork and
  every text element together, and `acidBoot.paletteOverrides` takes your own RGB for any
  individual element (or the logo's recolor filter).
- **Turn bits off.** `showLog = false` for a quiet logo-and-prompt
  splash, `animations = false` for a completely static one, `scale` to
  size the text to taste.
- **Sharp on high-DPI panels.** Plymouth's only scaler is a bare
  bilinear sample, so a single large logo visibly aliases once it's
  scaled down more than ~2x. The build ships a ladder of pre-rendered
  sizes (256–1024, glow radius scaled to match) and the theme picks the
  nearest one above the target, keeping the runtime downscale under
  ~1.4x on everything from 768p to 5K.
- **Esc** still toggles plymouth's full details view at any time, and
  `plymouth.enable=0` appended to the kernel command line (hold `Space`
  at startup, press `e` on the boot entry) disables the splash for that
  one boot — the escape hatch if a splash change ever misbehaves.
- Clean handoff: quits with `--retain-splash` so there's no text-VT
  flash while your display manager starts.

## The plymouth patch

Stock plymouth routes console boot output only to its built-in console
viewer — script themes never see it. `patches/plymouth-script-boot-output.patch`
(written against plymouth 26.134.222) adds a
`Plymouth.SetBootOutputFunction(fn)` hook: complete lines, ANSI-stripped,
each tagged with the line's dominant SGR foreground color so themes can
style by severity. The module builds plymouth with this patch via
`boot.plymouth.package`; expect at most trivial fuzz on version bumps.

## The passphrase prompt

Plymouth ships `systemd-ask-password-plymouth.{path,service}` itself and
hardcodes the service's `ExecStart` to the systemd *plymouth* was built
against — a different store path from the systemd in your initrd, and
one the initrd has no reason to contain. So the only process that can
carry a passphrase request to the splash dies with `203/EXEC`, the path
unit retriggers until it hits systemd's trigger limit, and the boot sits
at `Starting Cryptography Setup for ...` with no prompt. Plymouth still
owns the keyboard, so typing blind doesn't help either.

It normally stays invisible: both units are gated on
`ConditionPathExists=/run/plymouth/pid` and get skipped before they can
fail, so whether you ever get a prompt comes down to whether plymouthd
wrote that file before the units were evaluated — i.e. how quickly your
GPU hands over a DRM device.

This module ships the agent from the initrd's own systemd, repoints the
unit at it, and clears the conditions and the trigger limit, so LUKS
prompting works regardless of that race. If nixpkgs fixes it upstream,
the override becomes a harmless no-op.

## Usage

```nix
# flake.nix
{
  inputs.acid-boot = {
    url = "github:kurisu-agent/nix-acid-boot";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

```nix
# configuration.nix (import inputs.acid-boot.nixosModules.default)
{
  acidBoot = {
    enable = true;
    palette = "nix-blue";                     # or acid-green (default),
                                              # golden-yellow, furry-pink, doom-red, cool-gray
    logo = "flower-of-life";                  # or snowflake (default)
    paletteOverrides = {
      promptColor = "0.90, 0.50, 0.10";       # any element, your RGB
    };
  };
}
```

### Options

| Option | Default | Notes |
|---|---|---|
| `acidBoot.enable` | `false` | |
| `acidBoot.palette` | `"acid-green"` | one of the six named palettes |
| `acidBoot.logo` | `"snowflake"` | bundled artwork: `snowflake` or `flower-of-life` |
| `acidBoot.logoSvg` | `null` | your own SVG, recolored to the palette and re-rendered at every size |
| `acidBoot.paletteOverrides` | `{ }` | per-color RGB / logo-filter overrides, merged over the palette |
| `acidBoot.logoFile` | `null` | your own image instead of the snowflake; used as-is, fitted to the layout slot, aspect preserved |
| `acidBoot.showLog` | `true` | live boot-log tail; `false` also drops the patched plymouth entirely |
| `acidBoot.animations` | `true` | fade in/out, shake on a wrong passphrase, blinking cursor |
| `acidBoot.scale` | `1.0` | extra multiplier on text/spacing (the theme already tracks panel height) |
| `acidBoot.buildTag` | `0` | draw N small squares on the logo — a "which build booted?" marker while iterating |
| `acidBoot.promptText` | `"Enter Password"` | e.g. `"パスワードを入力"` |
| `acidBoot.promptFontName` | `"JetBrains Mono"` | fontconfig family for prompt + bullets |
| `acidBoot.logFontName` | `"JetBrains Mono"` | fontconfig family for the log tail |
| `acidBoot.fontFiles` | JetBrains Mono ttf | files shipped into the initrd; must cover the families above |
| `acidBoot.retainSplash` | `true` | `plymouth quit --retain-splash` handoff |

Non-latin prompt? Set all three font options, e.g.:

```nix
acidBoot = {
  enable = true;
  promptText = "パスワードを入力";
  promptFontName = "Noto Sans CJK JP";
  fontFiles = [
    "${pkgs.jetbrains-mono}/share/fonts/truetype/JetBrainsMono-Regular.ttf"
    "${pkgs.noto-fonts-cjk-sans}/share/fonts/opentype/noto-cjk/NotoSansCJK-VF.otf.ttc"
  ];
};
```

## Things worth knowing

- **Plymouth needs a real DRM driver in the initrd** to paint the
  LUKS-prompt phase — it refuses simpledrm. Put your GPU module in
  `boot.initrd.kernelModules` (`amdgpu`, `i915`, `xe`, …); without it
  you get a text prompt and the splash only from stage 2.
- **Keep your kernel params honest**: the module adds `splash` (via the
  stock plymouth module) but deliberately works fine without `quiet` —
  Esc shows everything.
- **ESP budget**: every generation's initrd carries the theme's fonts.
  The default JetBrains Mono adds ~2M; a CJK font adds ~32M — with a GPU
  driver in the initrd, expect ~100M+ per kernel+initrd pair. Eight
  retained generations of that outgrow a 512M ESP, so set
  `boot.loader.systemd-boot.configurationLimit` (4 is plenty) before
  your first rebuild, not after.
- **Rotated monitors**: `video=<connector>:panel_orientation=…` on the
  kernel command line rotates the splash per output.
- **Use `nixos-rebuild boot`, not `switch`, for the first rebuild**, so
  the previous generation stays the default and is one keypress away
  (hold `Space` with systemd-boot). Anything that changes what happens
  in stage 1 deserves that safety net.

## Troubleshooting: boot hangs before the passphrase prompt

If the boot stops at `Starting Cryptography Setup for cryptroot...` with
no passphrase prompt, **the first thing to reach for is**: hold `Space`
at startup for the systemd-boot menu, press `e` on the entry, append

```
plymouth.enable=0
```

and boot. That disables the splash for one boot only and gives you a
plain text prompt. It both rescues the machine and tells you the fault
is in plymouth rather than in your disk, kernel or initrd — worth
keeping in your head as the standard first move.

The module already fixes the most likely cause — see "the passphrase
prompt" above — but if you hit it anyway, the usual remaining suspects
are:

- **Plymouth never got a graphical device.** It waits `DeviceTimeout`
  seconds (8 by default) for one, and if none appears it falls back to
  its *text renderer*, in which a `script` theme like this one can draw
  nothing at all — including the dialog. Give it longer with
  `boot.plymouth.extraConfig = "DeviceTimeout=20";`, or drop the GPU
  module from `boot.initrd.kernelModules` and accept a text prompt at
  LUKS with the splash starting in stage 2.
- **A slow GPU handshake in stage 1.** Adding a driver to the initrd
  pulls firmware negotiation earlier than it normally happens; be
  sparing with extra modules and check whether the driver alone works
  before adding companions.

Whatever the cause: **use `nixos-rebuild boot`, not `switch`, for the
first rebuild**, so the previous generation stays the default and is one
keypress away.

## Troubleshooting: `Failed to install bootloader`

`OSError: [Errno 28] No space left on device` means the ESP is full of
old kernel+initrd pairs — these are big (see the ESP note above). Fix
with `sudo nix-collect-garbage -d`, set
`boot.loader.systemd-boot.configurationLimit`, and re-run
`nixos-rebuild boot`.

## License

MIT for the theme, module and build machinery. The patch under
`patches/` modifies GPL-2.0-or-later plymouth sources and is offered
under plymouth's own license.
