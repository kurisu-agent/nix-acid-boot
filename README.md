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
  `Enter Password`), Matrix-style decode entry, power/boot-menu/UEFI
  buttons, and a blinking cursor.
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
- **Text sized by width, not DPI.** The log font is scaled until
  `acidBoot.columns` characters (default 100) span `acidBoot.textWidth`
  of the narrowest display, and everything else follows in proportion —
  so a full log line is always visible, on a portrait 4K panel as much
  as on a 1080p laptop, and on every monitor of a multi-head boot
  (plymouth draws one canvas the size of the largest display and centers
  the others in it).
- **Turn bits off.** `showLog = false` for a quiet logo-and-prompt
  splash, `animations = false` for a completely static one, `scale` to
  nudge the text size on top of the width fit.
- **Sharp on high-DPI panels**, which takes defeating two separate
  things. Plymouth copies Mutter's HiDPI heuristic and, past ~1.625x the
  ideal scale for the panel, draws the theme at *half* resolution and
  upscales the result — so `acidBoot.deviceScale` pins native rendering
  by default. And its only scaler is a bare bilinear sample, so a single
  large logo visibly aliases once it's scaled down more than ~2x — so
  the build ships a ladder of pre-rendered sizes (256–1024, glow radius
  scaled to match) and the theme picks the nearest one above the target,
  keeping the runtime downscale under ~1.4x from 768p to 5K.
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

A second patch, `patches/plymouth-acid-input-actions.patch`, serves the
passphrase screen extras below:

- arrow keys reach the theme as `\e[A`..`\e[D` (plymouth's evdev input
  otherwise drops keys that produce no text; the passphrase buffer
  already ignores escape sequences, so they can never end up in it);
- the theme's `validate_input` verdict is honoured even when plymouth's
  console viewer is unavailable, so a key the theme swallows stays
  swallowed;
- `Plymouth.RequestAction(name)` drops `/run/acid-boot/<name>.request`
  for a systemd `.path` unit to act on (names limited to `[a-z0-9-]`);
- `Plymouth.ClearEntry(n)` erases the passphrase with `n` backspaces
  through plymouth's normal handlers, deferred a tick so the theme
  isn't re-entered mid-callback.

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

## Passphrase screen extras

Buttons and the decode entry are on by default; `buttons = [ ]` and
`entryStyle = "bullets"` give back the plain screen.

- **Buttons** (`acidBoot.buttons`, all three by default when the initrd
  runs systemd): a row of icons under the entry.
  `↓` moves to them, `←`/`→` walk them, `↑` returns, `Enter`
  activates, and typing any character jumps back to the entry with it
  kept. `poweroff` powers off, `bootmenu` reboots into the
  systemd-boot menu (once, no timeout) to pick an older generation,
  `firmware` reboots into UEFI setup. The theme only drops a request
  file; the module ships the initrd (and stage 2) units that act on it.
  The cursor blinks only while the entry has focus.
- **Decode entry** (`acidBoot.entryStyle`, `"decode"` by default): each character
  rains through Matrix-style glyphs — mostly half-width kana, plus
  digits, symbols and a ciphertext-looking latin alphabet — then locks
  onto one with a white flash; backspace glitches it out. Glyphs are
  random (seeded per boot), never derived from what you type.
- **Privacy toggle** (`Tab`, on by default via `acidBoot.privacyToggle`):
  flips between *verify* (one glyph per character, the default per
  `acidBoot.privacyDefault`) and *private*, which hides even the length —
  the row is a fixed 12 glyphs once anything is typed and each key
  re-rolls a few of them. Toggling clears the entry and returns focus to
  it; the choice lasts for that boot only. The default mode shows no
  indicator; the other shows its eye left of the entry (struck-through
  for private, open for verify).
- **Caps Lock** shows a warning under the entry.
- **Lockout** (`acidBoot.lockout.schedule`): after failed passphrases the
  entry is replaced by a countdown before the next try (e.g. three free
  attempts, then 30 s, 1 min, 2 min, 5 min). Raise systemd-cryptsetup's
  `tries=` past the free attempts or it gives up first. A pause on the
  splash, not a security boundary.

```nix
acidBoot = {
  buttons = [ "poweroff" "firmware" ];  # order/subset; [ ] for none
  buttonLabels = {
    poweroff = "電源オフ";
    bootmenu = "ブートメニュー";
    firmware = "UEFI設定";
  };
};
```

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
| `acidBoot.showLog` | `true` | live boot-log tail; `false` also drops the patched plymouth entirely, unless the passphrase extras below need it |
| `acidBoot.animations` | `true` | fade in/out, shake on a wrong passphrase, blinking cursor |
| `acidBoot.columns` | `100` | characters of the log font that span the text area; text size is solved from this |
| `acidBoot.textWidth` | `0.48` | width of the text area as a fraction of the narrowest display |
| `acidBoot.scale` | `1.0` | extra multiplier on text/spacing on top of the width fit |
| `acidBoot.deviceScale` | `1` | pins native rendering; plymouth otherwise halves the resolution on HiDPI panels and upscales. `null` restores its auto-detection |
| `acidBoot.buildTag` | `0` | draw N small squares on the logo — a "which build booted?" marker while iterating |
| `acidBoot.promptText` | `"Enter Password"` | e.g. `"パスワードを入力"` |
| `acidBoot.promptFontName` | `"JetBrains Mono"` | fontconfig family for prompt + bullets |
| `acidBoot.logFontName` | `"JetBrains Mono"` | fontconfig family for the log tail |
| `acidBoot.fontFiles` | JetBrains Mono ttf | files shipped into the initrd; must cover the families above |
| `acidBoot.retainSplash` | `true` | `plymouth quit --retain-splash` handoff |
| `acidBoot.buttons` | all three with systemd initrd, else `[ ]` | any of `poweroff`, `bootmenu`, `firmware`, in display order; needs systemd in the initrd |
| `acidBoot.buttonLabels` | `{ }` | label per button, merged over English defaults |
| `acidBoot.entryStyle` | `"decode"` | Matrix-style entry; `"bullets"` for plain asterisks |
| `acidBoot.decodeGlyphs` | `null` | custom glyph list for `decode` (uniform picks); `null` is the weighted kana/cipher mix |
| `acidBoot.privacyDefault` | `"verify"` | starting mode each boot: `"verify"` (one glyph per character) or `"private"` (length hidden) |
| `acidBoot.privacyToggle` | `true` | `Tab` flips the mode for that boot; the non-default mode shows its eye |
| `acidBoot.lockout.schedule` | `[ ]` | seconds to wait after each failed passphrase, last repeating; countdown replaces the entry. Raise systemd-cryptsetup `tries=` past the free attempts |
| `acidBoot.lockout.text` | `"Retry in"` | label before the countdown |

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
