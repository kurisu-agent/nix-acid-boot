# nix-acid-boot

An acid-green Nix snowflake [Plymouth](https://www.freedesktop.org/wiki/Software/Plymouth/)
boot splash for NixOS — with a **live tail of the boot log** rendered
right on the splash, during boot *and* shutdown.

![the acid-green splash: logo, live boot-log tail, passphrase prompt](assets/boot.gif)

<sub>Recorded on a VM. The log lines are synthetic so the demo is
reproducible; everything else — the fade, the severity colouring, the
passphrase dialog — is the real theme.</sub>

## What you get

- **Glowing acid-duotone Nix snowflake**, generated at build time from
  `nixos-icons`' SVG (no binary art in this repo). Fades in, holds,
  fades out after unlock; shakes on a wrong passphrase.
- **Live log tail** — the last 5 console lines under the logo, styled
  by severity (`[ OK ]` dark acid, failures red, warnings amber),
  older lines dimming. During shutdown the tail shows the stop
  sequence, so the unit a stop job is stuck on is visible instead of
  hidden behind a frozen splash.
- **LUKS passphrase dialog** with configurable label (default
  `Enter Password`), asterisk bullets, and a blinking cursor.
- **Your own image.** Point `acidBoot.logoFile` at any PNG and it
  replaces the snowflake — used as-is, fitted to the same layout slot
  with its aspect ratio preserved, so wordmarks and banners work as
  well as square logos. The build derives the whole size ladder from
  it, so it stays sharp on high-DPI panels too.
- **Five color palettes** — `acid-green`, `nix-blue`, `furry-pink`,
  `doom-red`, `cool-gray` — recoloring the logo and every text element
  together, and `acidBoot.paletteOverrides` takes your own RGB for any
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
- **Esc** still toggles plymouth's full details view at any time.
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
                                              # furry-pink, doom-red, cool-gray
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
| `acidBoot.palette` | `"acid-green"` | one of the five named palettes |
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
- **Early KMS can hang the boot before the passphrase prompt.** Adding a
  GPU driver to the initrd pulls firmware handshakes into stage 1 that
  normally happen much later. We hit `GSC proxy component not bound`
  with `xe` on Intel Lunar Lake; adding `mei mei_me mei_gsc_proxy`
  alongside it is the usual remedy for that one. Whatever your GPU:
  **use `nixos-rebuild boot`, not `switch`, for the first rebuild**, and
  know how to reach your boot menu (hold Space with systemd-boot) so the
  previous generation is one keypress away.

> [!WARNING]
> **Pre-flight your ESP before the first rebuild with this module.**
> These initrds are likely the biggest thing your ESP has ever had to
> swallow, and they will find latent problems that small initrds never
> touched. In particular, check that your FAT filesystem is not larger
> than its partition (it happens — hand-formatted or image-restored
> ESPs):
>
> ```
> df -B1 --output=size /boot | tail -1
> lsblk -bno SIZE "$(findmnt -no SOURCE /boot)"
> ```
>
> If `df` reports **more** than `lsblk`, every write past the partition
> edge will fail with `Input/output error` — and a reflexive
> `fsck.vfat -a` at that point will "repair" the geometry by truncating
> files, which can destroy **every existing boot entry** and leave the
> machine unbootable. (`fsck.vfat -n` names the problem outright:
> `Seek to <byte offset beyond the partition>: Invalid argument`.)
>
> This is not hypothetical — it cost us a laptop's entire boot
> partition, recovered only via an installer USB. If the sizes
> disagree: back up the ESP contents, recreate the filesystem
> (`mkfs.vfat` sizes it correctly), and reinstall the bootloader —
> *before* enabling this module.

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

The usual cause is that plymouth never got a graphical device. It waits
`DeviceTimeout` seconds (8 by default) for one, and if none appears it
falls back to its **text renderer** — in which a `script` theme like
this one can draw *nothing at all*, including the passphrase dialog. The
prompt is genuinely there and typing your passphrase blind still works;
it's simply invisible.

That happens when the GPU driver is slow to bring up KMS in stage 1, so:

- Give it longer: `boot.plymouth.extraConfig = "DeviceTimeout=20";`
- Be sparing with extra initrd modules. On one Lunar Lake laptop, adding
  `mei mei_me mei_gsc_proxy` alongside `xe` delayed DRM past the timeout
  and produced exactly this hang; `xe` on its own was fine.
- Or accept a text prompt at LUKS: drop the GPU module from
  `boot.initrd.kernelModules` and let the splash start in stage 2.

## Troubleshooting: `Failed to install bootloader`

Two distinct failures look similar when the fat initrds meet a small
ESP:

- **`OSError: [Errno 28] No space left on device`** — the ESP is full
  of old kernel+initrd pairs. Fix: `sudo nix-collect-garbage -d`, set
  `configurationLimit`, and re-run `nixos-rebuild boot`.
- **`could not sync /boot` + `OSError: [Errno 5] Input/output error`
  with free space left** — STOP. Do not reboot, and do **not** reach
  for `fsck.vfat -a` yet. First, image the ESP so every next step is
  reversible, then check whether the FAT is bigger than its partition
  (the pre-flight check above):

  ```
  sudo dd if=/dev/nvme0n1p1 of=/root/esp-backup.img bs=4M   # your ESP device
  df -B1 --output=size /boot | tail -1
  lsblk -bno SIZE "$(findmnt -no SOURCE /boot)"
  ```

  - **Sizes disagree (df > lsblk)**: the filesystem overhangs the
    partition. `fsck -a` here truncates files and can wipe every boot
    entry — this is the bricking path. Instead, recreate the ESP; all
    of its contents are regenerable from the Nix store:

    ```
    sudo umount /boot
    sudo mkfs.vfat -F32 /dev/nvme0n1p1
    sudo mount /boot
    sudo NIXOS_INSTALL_BOOTLOADER=1 nixos-rebuild boot --flake .#<host>
    ```

  - **Sizes agree**: plain dirty FAT; `fsck.vfat -a` then
    `nixos-rebuild boot` is fine (you have the image if it isn't).
  - `dmesg` showing NVMe/controller errors rather than `FAT-fs` errors
    is failing hardware — back up your data before anything else.

  If it's already too late and no generation boots: boot any NixOS
  installer USB, unlock your root, mount it at `/mnt` plus the
  (freshly `mkfs.vfat`-ed) ESP at `/mnt/boot`, and run
  `nixos-enter --root /mnt -c 'NIXOS_INSTALL_BOOTLOADER=1 /nix/var/nix/profiles/system/bin/switch-to-configuration boot'`.
  Ten minutes, no data loss.

## License

MIT for the theme, module and build machinery. The patch under
`patches/` modifies GPL-2.0-or-later plymouth sources and is offered
under plymouth's own license.
