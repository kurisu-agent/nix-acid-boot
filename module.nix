# NixOS module for the acid-nix plymouth theme.
{
  config,
  lib,
  options,
  pkgs,
  ...
}:

let
  cfg = config.acidBoot;

  # nixpkgs #573038 (2026-10) dropped the scripted initrd: systemd is the
  # only stage 1 and `boot.initrd.systemd.enable` is a removed option that
  # throws when read. Older pins (clan-alpha) still have the real option.
  systemdInitrd =
    (options.boot.initrd.systemd.enable.visible or true) == false
    || config.boot.initrd.systemd.enable;

  acid = import ./theme.nix {
    inherit pkgs;
    inherit (cfg)
      palette
      paletteOverrides
      logo
      logoSvg
      logoFile
      promptText
      promptFontName
      logFontName
      ;
    uiScale = cfg.scale;
    inherit (cfg)
      columns
      textWidth
      showLog
      animations
      buildTag
      buttons
      buttonLabels
      entryStyle
      decodeGlyphs
      privacyDefault
      privacyToggle
      ;
    lockoutSchedule = cfg.lockout.schedule;
    lockoutText = cfg.lockout.text;
  };

  actionButtons = cfg.buttons;

  # What each passphrase-screen button does once the theme drops its
  # /run/acid-boot/<name>.request. The request is removed first so a
  # failed action can't retrigger the path unit in a loop.
  actionCommands = sd: {
    poweroff = [ "${sd}/bin/systemctl --no-block poweroff" ];
    # menu-force: systemd-boot shows its menu with no timeout, once.
    bootmenu = [
      "${sd}/bin/bootctl set-timeout-oneshot menu-force"
      "${sd}/bin/systemctl --no-block reboot"
    ];
    firmware = [
      "${sd}/bin/bootctl reboot-to-firmware true"
      "${sd}/bin/systemctl --no-block reboot"
    ];
  };

  actionUnits = sd: {
    paths = lib.listToAttrs (
      map (name: {
        name = "acid-boot-${name}";
        value = {
          wantedBy = [ "sysinit.target" ];
          unitConfig.DefaultDependencies = false;
          pathConfig.PathExists = "/run/acid-boot/${name}.request";
        };
      }) actionButtons
    );
    services = lib.listToAttrs (
      map (name: {
        name = "acid-boot-${name}";
        value = {
          unitConfig.DefaultDependencies = false;
          serviceConfig = {
            Type = "oneshot";
            ExecStartPre = "${pkgs.coreutils}/bin/rm -f /run/acid-boot/${name}.request";
            ExecStart = (actionCommands sd).${name};
          };
        };
      }) actionButtons
    );
  };
in
{
  options.acidBoot = {
    enable = lib.mkEnableOption "nix snowflake plymouth theme with live log tail";

    palette = lib.mkOption {
      type = lib.types.enum (builtins.attrNames (import ./palettes.nix));
      default = "acid-green";
      description = "Color palette: logo recolor + all text elements.";
    };

    animations = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Fade the logo in and out, shake it on a wrong passphrase, and
        blink the entry cursor. With this off the logo is simply solid
        and no refresh callback is registered — a completely static
        splash, and the smallest possible surface if you're bisecting a
        boot problem.
      '';
    };

    buildTag = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 0;
      example = 3;
      description = ''
        Draw this many small white squares in the logo's top-left
        corner. Purely a "which build am I actually looking at?" marker
        for iterating on a machine you can only observe at boot — bump
        it every rebuild. Deliberately graphical, so it stays visible
        even if text rendering is the thing you're chasing. 0 disables.
      '';
    };

    showLog = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Render the live boot-log tail under the logo. With this off the
        splash is just the logo and the passphrase dialog, and the
        theme never registers the boot-output hook at all — useful if
        you want a quiet splash, or to rule the log tail out while
        debugging a boot that stalls at the passphrase prompt.
        {command}`Esc` still shows plymouth's full details view either
        way.
      '';
    };

    deviceScale = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = 1;
      example = null;
      description = ''
        Plymouth's HiDPI device scale. Left to itself plymouth copies
        Mutter's heuristic — above ~1.625x the "perfect" scale for the
        panel's DPI it picks 2, then draws the theme at *half*
        resolution and upscales it. On a 254 DPI laptop panel that means
        a 2880x1800 screen rendered at 1440x900, which looks soft next
        to the crisp Esc details view.
        This theme sizes everything from the screen dimensions already,
        so it wants the real resolution: the default of 1 pins native
        rendering. Set to `null` to leave plymouth's auto-detection
        alone, or to 2 to opt back into upscaling.
      '';
    };

    columns = lib.mkOption {
      type = lib.types.ints.positive;
      default = 100;
      example = 80;
      description = ''
        How many characters of the log font fit across the text area.
        Text is sized from this: the log font is scaled until this many
        columns span {option}`acidBoot.textWidth` of the narrowest
        display, and the prompt, entry and spacing follow in proportion.
        Fewer columns means bigger text. Log lines longer than this are
        truncated with an ellipsis.
      '';
    };

    textWidth = lib.mkOption {
      type = lib.types.float;
      default = 0.48;
      example = 0.6;
      description = ''
        Fraction of the narrowest display's width that the text area
        occupies, centered. With several displays plymouth draws one
        canvas the size of the largest and centers each display's view
        in it, so this is measured against the smallest so that a full
        line is visible on every display.
      '';
    };

    scale = lib.mkOption {
      type = lib.types.float;
      default = 1.0;
      example = 1.25;
      description = ''
        Extra multiplier on text and spacing on top of the width fit.
        Above 1.0 fewer than {option}`acidBoot.columns` characters fit
        a line. The logo is sized as a fraction of the screen and scales
        regardless of this setting.
      '';
    };

    logo = lib.mkOption {
      type = lib.types.enum [
        "snowflake"
        "flower-of-life"
      ];
      default = "snowflake";
      description = ''
        Which bundled artwork to draw, recolored to the palette. The
        snowflake is duotone and keeps both of its tones; the flower of
        life is line art and is filled with the palette's tint.
      '';
    };

    logoSvg = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression ''./my-mark.svg'';
      description = ''
        Your own SVG as the base artwork, recolored to the palette
        exactly like the bundled line art (masked and filled with its
        tint), and rendered fresh at every ladder size so it stays sharp
        at any resolution. Overrides {option}`acidBoot.logo`. Use
        {option}`acidBoot.logoFile` instead when you want an image used
        verbatim, colors and all.
      '';
    };

    logoFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression ''./my-logo.png'';
      description = ''
        Use this image instead of the generated Nix snowflake. Taken
        as-is — no palette recolor, no glow — and fitted into the same
        layout slot (26% of the smaller screen dimension), preserving
        its aspect ratio, so it needn't be square. Supply it at least
        1024px on its long edge for crisp results on high-DPI panels;
        the build derives the smaller ladder sizes from it. The palette
        still colors the text elements.
      '';
    };

    paletteOverrides = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        promptColor = "0.90, 0.50, 0.10";
        logoFilter = "-modulate 100,150,80";
      };
      description = ''
        Custom values merged over the named {option}`acidBoot.palette`.
        Keys as in palettes.nix: `logoFilter` (imagemagick args applied to
        the stock blue snowflake) and `promptColor`, `entryColor`,
        `logDefaultColor`, `logOkColor`, `logFailColor`, `logWarnColor`,
        `msgColor` as `"r, g, b"` floats in 0-1. Override one key or all
        of them.
      '';
    };

    promptText = lib.mkOption {
      type = lib.types.str;
      default = "Enter Password";
      example = "パスワードを入力";
      description = ''
        Label shown above the passphrase entry. The theme deliberately
        ignores the prompt systemd-cryptsetup passes in (it names the
        disk device).
      '';
    };

    promptFontName = lib.mkOption {
      type = lib.types.str;
      default = "JetBrains Mono";
      description = ''
        Fontconfig family used for the prompt and the entry bullets.
        Must be resolvable from one of {option}`acidBoot.fontFiles`
        — non-latin prompts need a font that covers them (e.g. Noto Sans
        CJK JP).
      '';
    };

    logFontName = lib.mkOption {
      type = lib.types.str;
      default = "JetBrains Mono";
      description = "Fontconfig family used for the boot-log tail.";
    };

    fontFiles = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ "${pkgs.jetbrains-mono}/share/fonts/truetype/JetBrainsMono-Regular.ttf" ];
      example = lib.literalExpression ''
        [
          "''${pkgs.jetbrains-mono}/share/fonts/truetype/JetBrainsMono-Regular.ttf"
          "''${pkgs.noto-fonts-cjk-sans}/share/fonts/opentype/noto-cjk/NotoSansCJK-VF.otf.ttc"
        ]
      '';
      description = ''
        Font files copied into the initrd for plymouth's private
        fontconfig. Together they must cover both font families above.
        Mind your ESP: large fonts (CJK ≈ +32M) grow every generation's
        initrd.
      '';
    };

    buttons = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "poweroff"
          "bootmenu"
          "firmware"
        ]
      );
      default = lib.optionals systemdInitrd [
        "poweroff"
        "bootmenu"
        "firmware"
      ];
      defaultText = lib.literalExpression ''
        lib.optionals systemdInitrd [ "poweroff" "bootmenu" "firmware" ]
      '';
      example = [ ];
      description = ''
        Action buttons under the passphrase entry, in this order; `[ ]`
        turns them off. On by default wherever the initrd runs systemd. Down
        moves focus to them, Left/Right walk them, Up returns to the
        entry, Enter activates; typing any character goes back to the
        entry. `poweroff` powers off; `bootmenu` reboots into the
        systemd-boot menu (shown once, no timeout) for picking an older
        generation; `firmware` reboots into the UEFI setup screen. Needs
        systemd in the initrd.
      '';
    };

    privacyDefault = lib.mkOption {
      type = lib.types.enum [
        "private"
        "verify"
      ];
      default = "verify";
      description = ''
        How the entry starts out on every boot. `verify` shows one glyph
        per character, the classic row. `private` hides even the
        passphrase length: once anything is typed the row is a fixed
        width, and each keystroke re-rolls a few of its glyphs.
      '';
    };

    privacyToggle = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Let Tab flip between private and verify for the rest of the boot.
        Toggling clears the entry and focuses it. The default mode shows
        no indicator; the other one shows its eye left of the entry (a
        struck-through eye for private, an open eye for verify).
      '';
    };

    lockout = {
      schedule = lib.mkOption {
        type = lib.types.listOf lib.types.ints.unsigned;
        default = [ ];
        example = [
          0
          0
          0
          30
          60
          120
          300
        ];
        description = ''
          Seconds to wait after each failed passphrase, in order; the last
          entry repeats. While a wait runs, a countdown replaces the entry
          and typing is ignored (the action buttons still work). Empty
          disables it. Needs {option}`acidBoot.animations`.

          systemd-cryptsetup gives up after its `tries=` (default 3) and
          drops to emergency mode, so raise that past the free attempts,
          e.g. `boot.initrd.luks.devices.<name>.crypttabExtraOpts =
          [ "tries=10" ]`. This is a pause on the splash, not a security
          boundary: the LUKS KDF is what makes guessing expensive.
        '';
      };

      text = lib.mkOption {
        type = lib.types.str;
        default = "Retry in";
        example = "再試行まで";
        description = ''
          Label before the countdown. Must be drawable by
          {option}`acidBoot.promptFontName`; no double quotes.
        '';
      };
    };

    buttonLabels = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        poweroff = "電源オフ";
        bootmenu = "ブートメニュー";
        firmware = "UEFI設定";
      };
      description = ''
        Labels shown under the focused button, merged over the English
        defaults. Must be drawable by {option}`acidBoot.promptFontName`
        and contain no double quotes.
      '';
    };

    entryStyle = lib.mkOption {
      type = lib.types.enum [
        "bullets"
        "decode"
      ];
      default = "decode";
      example = "bullets";
      description = ''
        How typed characters appear. `bullets` is a row of asterisks;
        `decode` rains each new character through random glyphs before
        it locks onto one, Matrix-style, and glitches deleted ones out.
        The glyphs are random per keystroke and per boot, never derived
        from what is typed; at most they reveal the passphrase's length,
        and not even that in private mode
        ({option}`acidBoot.privacyDefault`).
        Without {option}`acidBoot.animations` it shows the locked glyph
        straight away.
      '';
    };

    decodeGlyphs = lib.mkOption {
      type = lib.types.nullOr (lib.types.listOf lib.types.str);
      default = null;
      example = [
        "0"
        "1"
      ];
      description = ''
        Glyph set for `entryStyle = "decode"`, one string per glyph,
        picked uniformly. `null` mixes Matrix-style half-width katakana
        with digits, symbols and a ciphertext-looking latin alphabet,
        weighted to read like the film's rain (mostly kana), when
        {option}`acidBoot.promptFontName` is a CJK font, else uses just
        the non-kana glyphs. Glyphs must be drawable by that font; no
        backslashes.
      '';
    };

    retainSplash = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Quit plymouth with `--retain-splash` (GDM's trick): the last
        frame stays on the framebuffer instead of dropping to the text
        VT for the moment it takes the display manager to start. Safe
        with any DM that takes over DRM; disable for a console-only
        system.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
  {
    boot.plymouth = {
      enable = true;
      # The patches exist to feed the log tail and to give the passphrase
      # screen its keys and actions. With neither in use there's nothing
      # for them to do, so run stock plymouth and keep the patched build
      # off the boot path entirely — fewer moving parts, and it makes
      # `showLog = false` a genuine A/B against upstream.
      package =
        if cfg.showLog || cfg.buttons != [ ] || cfg.entryStyle != "bullets" || cfg.privacyToggle then
          acid.plymouth
        else
          pkgs.plymouth;
      theme = lib.mkDefault "acid-nix";
      themePackages = [ acid.theme ];
      font = lib.mkDefault (lib.head cfg.fontFiles);
      extraConfig = lib.mkIf (cfg.deviceScale != null) "DeviceScale=${toString cfg.deviceScale}";
    };

    # The stock module ships exactly boot.plymouth.font into the initrd's
    # plymouth fontconfig; the theme may need more than one file.
    boot.initrd.systemd.contents."/etc/plymouth/fonts".source = lib.mkForce (
      pkgs.runCommand "plymouth-initrd-fonts" { } ''
        mkdir -p $out
        ${lib.concatMapStringsSep "\n" (f: "cp ${lib.escapeShellArg f} $out/") cfg.fontFiles}
      ''
    );

    # Make the passphrase prompt actually reach the splash.
    #
    # Plymouth ships systemd-ask-password-plymouth.{path,service} itself,
    # and hardcodes the service's ExecStart to the systemd *plymouth* was
    # built against. That is a different store path from the initrd's
    # systemd and is not present in the initrd, so the agent dies with
    # 203/EXEC, the path unit retriggers until it hits systemd's trigger
    # limit, and nothing ever forwards the request. Plymouth still owns
    # the keyboard, so the boot looks hung at
    # "Starting Cryptography Setup for ..." with no prompt and no
    # response to typing.
    #
    # It normally hides because the units are gated on
    # ConditionPathExists=/run/plymouth/pid and get skipped before they
    # can fail; a GPU that is slow to hand over a DRM device makes the
    # race visible.
    #
    # Fix: ship the agent from the initrd's own systemd, point the unit
    # at it, and stop the conditions from skipping/limiting the watcher.
    boot.initrd.systemd.storePaths = lib.mkIf systemdInitrd [
      "${config.boot.initrd.systemd.package}/bin/systemd-tty-ask-password-agent"
    ];

    boot.initrd.systemd.paths."systemd-ask-password-plymouth" =
      lib.mkIf systemdInitrd
        {
          overrideStrategy = "asDropin";
          wantedBy = [ "sysinit.target" ];
          unitConfig = {
            ConditionPathExists = "";
            TriggerLimitBurst = 0;
          };
        };

    boot.initrd.systemd.services."systemd-ask-password-plymouth" =
      lib.mkIf systemdInitrd
        {
          overrideStrategy = "asDropin";
          unitConfig.ConditionPathExists = "";
          serviceConfig.ExecStart = [
            ""
            "${config.boot.initrd.systemd.package}/bin/systemd-tty-ask-password-agent --watch --plymouth"
          ];
        };

    # "-" prefix: during a `nixos-rebuild switch` on a running system the
    # unit re-fires with no plymouthd to talk to; that must not fail the
    # activation.
    systemd.services.plymouth-quit.serviceConfig.ExecStart = lib.mkIf cfg.retainSplash [
      ""
      "-${config.boot.plymouth.package}/bin/plymouth quit --retain-splash"
    ];
  }

  # Button actions. Mainly for the initrd's LUKS prompt; stage 2 gets the
  # same units so a later prompt (or the shutdown splash) isn't left with
  # dead buttons.
  (lib.mkIf (actionButtons != [ ]) {
    assertions = [
      {
        assertion = systemdInitrd;
        message = "acidBoot.buttons needs boot.initrd.systemd.enable.";
      }
    ];

    boot.initrd.systemd = actionUnits config.boot.initrd.systemd.package // {
      storePaths = [
        "${config.boot.initrd.systemd.package}/bin/bootctl"
        "${pkgs.coreutils}/bin/rm"
      ];
    };

    systemd = actionUnits config.systemd.package;
  })
]);
}
