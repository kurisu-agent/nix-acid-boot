# NixOS module for the acid-nix plymouth theme.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.acidBoot;

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
    inherit (cfg) showLog animations buildTag;
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

    scale = lib.mkOption {
      type = lib.types.float;
      default = 1.0;
      example = 1.25;
      description = ''
        Extra multiplier on text and spacing. The theme already scales
        with the panel (1080p is 1.0, so a 2880x1800 screen renders
        ~1.67x larger automatically); use this to taste on top of that.
        The logo is sized as a fraction of the screen and scales
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

  config = lib.mkIf cfg.enable {
    boot.plymouth = {
      enable = true;
      # The patch exists solely to feed the log tail. With the tail off
      # there's nothing to feed, so run stock plymouth and keep the
      # patched build off the boot path entirely — fewer moving parts,
      # and it makes `showLog = false` a genuine A/B against upstream.
      package = if cfg.showLog then acid.plymouth else pkgs.plymouth;
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
    # can fail. Diagnosed on a LUKS laptop whose GPU takes ~10s to hand
    # over a DRM device, which is what made the race visible.
    #
    # Fix: ship the agent from the initrd's own systemd, point the unit
    # at it, and stop the conditions from skipping/limiting the watcher.
    boot.initrd.systemd.storePaths = lib.mkIf config.boot.initrd.systemd.enable [
      "${config.boot.initrd.systemd.package}/bin/systemd-tty-ask-password-agent"
    ];

    boot.initrd.systemd.paths."systemd-ask-password-plymouth" =
      lib.mkIf config.boot.initrd.systemd.enable
        {
          overrideStrategy = "asDropin";
          wantedBy = [ "sysinit.target" ];
          unitConfig = {
            ConditionPathExists = "";
            TriggerLimitBurst = 0;
          };
        };

    boot.initrd.systemd.services."systemd-ask-password-plymouth" =
      lib.mkIf config.boot.initrd.systemd.enable
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
  };
}
