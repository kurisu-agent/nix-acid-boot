# Shared builders for the acid-nix plymouth theme. Imported by both the
# NixOS module and the flake's packages output.
{
  pkgs,
  palette ? "acid-green",
  paletteOverrides ? { },
  logo ? "snowflake",
  logoSvg ? null,
  logoFile ? null,
  uiScale ? 1.0,
  columns ? 100,
  textWidth ? 0.48,
  showLog ? true,
  animations ? true,
  buildTag ? 0,
  promptText ? "Enter Password",
  promptFontName ? "JetBrains Mono",
  logFontName ? "JetBrains Mono",
  buttons ? [ ],
  buttonLabels ? { },
  entryStyle ? "bullets",
  decodeGlyphs ? null,
  privacyDefault ? null,
}:

let
  lib = pkgs.lib;
  palettes = import ./palettes.nix;
  colors = palettes.${palette} // paletteOverrides;

  # Plymouth's only scaler (ply_pixel_buffer_resize) is a bare bilinear
  # sample — no box filtering — so downscaling much past 2x drops source
  # pixels and visibly aliases the logo's diagonals. Ship a ladder of
  # pre-rendered sizes instead and let the theme pick the nearest one up,
  # keeping the runtime downscale under ~1.4x. Covers 768p (picks 256)
  # through 5K (picks 1024); anything larger upscales from 1024, which
  # bilinear handles cleanly.
  logoSizes = [
    256
    384
    512
    768
    1024
  ];

  # Glow radius has to track the render size or the bloom looks heavier
  # on small screens than large ones. 24px at 1024 is the reference;
  # every ladder rung divides exactly.
  blurFor = size: toString (size * 24 / 1024);

  # Build marker: `buildTag` little squares in the logo's top-left
  # corner, drawn into the image at build time. Deliberately graphical
  # rather than a text label — when you're bisecting a splash that may
  # not be rendering text at all, the version stamp has to survive that.
  markerFor =
    size:
    let
      sq = size * 46 / 1024;
      gap = size * 68 / 1024;
      off = size * 40 / 1024;
      box =
        i:
        let
          x = off + i * gap;
        in
        "-draw 'rectangle ${toString x},${toString off} ${toString (x + sq)},${toString (off + sq)}'";
    in
    if buildTag <= 0 then
      ""
    else
      "-fill '#ffffff' " + lib.concatMapStringsSep " " box (lib.range 0 (buildTag - 1));

  # Bundled artwork. The snowflake is duotone, so it recolors by hue
  # rotation and keeps both tones; the flower of life is white line art,
  # where a hue rotation does nothing at all (rotating the hue of white
  # leaves white), so it is masked and filled with the palette's tint
  # instead. A caller-supplied SVG is treated as line art for the same
  # reason — that is what a one-color vector almost always is.
  svgSources = {
    snowflake = {
      file = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
      duotone = true;
    };
    flower-of-life = {
      file = ./theme/flower-of-life.svg;
      duotone = false;
    };
  };

  svgSource =
    if logoSvg != null then
      {
        file = builtins.path {
          path = logoSvg;
          name = "acid-boot-custom-logo-svg";
        };
        duotone = false;
      }
    else
      svgSources.${logo};

  recolor =
    size:
    if svgSource.duotone then
      "magick base.png ${colors.logoFilter} duo.png"
    else
      ''
        magick base.png -alpha extract mask.png
        magick -size ${toString size}x${toString size} xc:'${colors.tint}' \
          mask.png -alpha off -compose CopyOpacity -composite duo.png
      '';

  renderGenerated = size: ''
    rsvg-convert -w ${toString size} -h ${toString size} \
      ${svgSource.file} -o base.png
    ${recolor size}
    magick duo.png \( +clone -blur 0x${blurFor size} \) -compose screen -composite \
      glow.png
    magick glow.png ${markerFor size} $out/logo-${toString size}.png
  '';

  # Name fragment for the derivation, resolved out here where `logo`
  # still means the argument rather than the `logo` attribute below.
  logoName = if logoSvg != null then "custom" else logo;

  # builtins.path (rather than bare interpolation) so the image is copied
  # into the store and visible to the sandboxed builder whether the
  # caller passed a path literal or a string.
  customLogo = builtins.path {
    path = logoFile;
    name = "acid-boot-custom-logo";
  };

  # A user-supplied image is used as-is: no palette recolor, no glow —
  # what they hand us is what boots. Only ever shrink it ('>'), so a
  # small source stays crisp rather than being blown up on disk.
  renderCustom = size: ''
    magick ${customLogo} \
      -resize '${toString size}x${toString size}>' -strip \
      ${markerFor size} $out/logo-${toString size}.png
  '';

  # Passphrase-screen buttons. Each name is also the action the theme
  # requests (Plymouth.RequestAction -> /run/acid-boot/<name>.request);
  # module.nix ships the units that carry them out. `privacy` is the
  # exception: a toggle the theme handles itself.
  defaultButtonLabels = {
    privacy = "Private";
    privacy-verify = "Verify";
    poweroff = "Power off";
    bootmenu = "Boot menu";
    firmware = "Firmware setup";
  };
  labels = defaultButtonLabels // buttonLabels;

  # Icons are white-stroke SVGs (after Feather's power/layers/cpu, MIT),
  # masked and filled like the line-art logos. Two looks per icon: plain
  # in the prompt color, and lit in the entry color with the logo's glow.
  # A small ladder for the same bilinear-scaler reason as the logo.
  iconSizes = [
    48
    96
    192
  ];

  # palettes.nix colors are plymouth "r, g, b" floats; imagemagick wants
  # rgb() percentages.
  magickColor =
    triplet:
    "rgb(${
      lib.concatMapStringsSep "," (
        v: "${toString (builtins.fromJSON (lib.trim v) * 100)}%"
      ) (lib.splitString "," triplet)
    })";

  renderIcon =
    name: size:
    let
      s = toString size;
      fill = color: ''
        magick -size ${s}x${s} xc:'${magickColor color}' \
          mask.png -alpha off -compose CopyOpacity -composite fill.png
      '';
    in
    ''
      rsvg-convert -w ${s} -h ${s} ${./theme/icons + "/${name}.svg"} -o base.png
      magick base.png -alpha extract mask.png
      ${fill colors.promptColor}
      cp fill.png $out/btn-${name}-plain-${s}.png
      ${fill colors.entryColor}
      magick fill.png \( +clone -blur 0x${toString (size * 6 / 192)} \) -compose screen -composite \
        $out/btn-${name}-lit-${s}.png
    '';

  # Glyphs the decode entry rains through and locks into: the film's code
  # (half-width katakana, digits, Z, a few symbols) plus a
  # ciphertext-looking latin alphabet for variety. Without a CJK prompt
  # font the kana are dropped. All half-width: one full-width glyph would
  # set the cell width and space the whole row out. Split on spaces, not
  # bytes, so multibyte glyphs stay whole; backslash is left out (the
  # script scanner would eat it).
  #
  # Weighted so the mix reads like the film's rain. No per-glyph
  # frequencies were ever published; faithful recreations draw uniformly
  # from the code font, whose set is mostly kana, so the rain is too.
  # These per-glyph weights give ~58% kana, ~15% digits, ~14% Matrix
  # symbols and ~13% latin.
  glyphGroups = [
    {
      weight = 6;
      cjk = true;
      glyphs = "ﾊ ﾐ ﾋ ｰ ｳ ｼ ﾅ ﾓ ﾆ ｻ ﾜ ﾂ ｵ ﾘ ｱ ﾎ ﾃ ﾏ ｹ ﾒ ｴ ｶ ｷ ﾑ ﾕ ﾗ ｾ ﾈ ｽ ﾀ ﾇ ﾍ ･";
    }
    {
      weight = 5;
      glyphs = "0 1 2 3 4 5 6 7 8 9";
    }
    {
      weight = 4;
      glyphs = "Z : . \" = * + - < > | ¦";
    }
    {
      weight = 1;
      glyphs = "A B C D E F G H J K L M N P Q R S T U V W X Y a b c d e f k m n q r t w x y # $ % & ? @";
    }
  ];
  weighted =
    w: gs:
    map (g: {
      inherit g w;
    }) gs;
  glyphs =
    if entryStyle == "bullets" then
      weighted 1 [ "*" ]
    else if decodeGlyphs != null then
      weighted 1 decodeGlyphs
    else
      lib.concatMap (grp: weighted grp.weight (lib.splitString " " grp.glyphs)) (
        lib.filter (grp: !(grp.cjk or false) || lib.hasInfix "CJK" promptFontName) glyphGroups
      );

  # The privacy toggle has two looks; its "verify" icon is rendered too.
  iconNames = lib.unique (buttons ++ lib.optional (lib.elem "privacy" buttons) "privacy-verify");
in
rec {
  # Plymouth's script plugin feeds console boot output only to its
  # built-in Esc console viewer; this patch also forwards complete,
  # ANSI-stripped lines (tagged with the line's dominant SGR color) to
  # script land via a new Plymouth.SetBootOutputFunction hook, which the
  # theme uses for its live log tail — during boot AND shutdown, where
  # stop-job culprits show up in it.
  #
  # The second patch serves the passphrase screen: arrow keys reach the
  # theme (evdev input otherwise drops keys without UTF-8), the script's
  # validate_input verdict is honoured even without the console viewer,
  # Plymouth.RequestAction(name) lets the theme ask systemd to act, and
  # Plymouth.ClearEntry(n) erases the passphrase with n backspaces.
  plymouth = pkgs.plymouth.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/plymouth-script-boot-output.patch
      ./patches/plymouth-acid-input-actions.patch
    ];
  });

  icons =
    pkgs.runCommand "acid-nix-icons-${palette}"
      {
        nativeBuildInputs = with pkgs; [
          librsvg
          imagemagick
        ];
      }
      ''
        mkdir -p $out
        ${lib.concatMapStringsSep "\n" (
          name: lib.concatMapStringsSep "\n" (renderIcon name) iconSizes
        ) iconNames}
      '';

  # Ladder of logo renders. The generated snowflake comes from
  # nixos-icons' SVG at build time (no binary art in this repo),
  # recolored per palette and glow-composited at each size.
  logos =
    pkgs.runCommand "acid-nix-logos-${palette}-${logoName}"
      {
        nativeBuildInputs = with pkgs; [
          librsvg
          imagemagick
        ];
      }
      ''
        mkdir -p $out
        ${lib.concatMapStringsSep "\n" (if logoFile != null then renderCustom else renderGenerated)
          logoSizes
        }
      '';

  # Largest rung, handy for previews / README art.
  logo = pkgs.runCommand "acid-nix-logo-${palette}.png" { } ''
    cp ${logos}/logo-${toString (lib.last logoSizes)}.png $out
  '';

  script = pkgs.replaceVars ./theme/acid-nix.script (
    {
      inherit promptText promptFontName logFontName;
      uiScale = toString uiScale;
      columns = toString columns;
      textWidth = toString textWidth;
      logEnabled = if showLog then "1" else "0";
      animEnabled = if animations then "1" else "0";

      # Ladder lookup, generated so nix stays the single source of truth
      # for the size list. Plain if/else chain: no number->string
      # coercion, no arrays to keep in sync with the build.
      logoPicker = lib.concatStringsSep "\n  " (
        (map (size: ''
          if (logo.box <= ${toString size}) logo.file = "logo-${toString size}.png"; else''
        ) (lib.init logoSizes))
        ++ [ ''logo.file = "logo-${toString (lib.last logoSizes)}.png";'' ]
      );

      iconPicker = lib.concatStringsSep "\n  " (
        (map (size: ''
          if (icon.box <= ${toString size}) icon.rung = "${toString size}"; else'') (lib.init iconSizes))
        ++ [ ''icon.rung = "${toString (lib.last iconSizes)}";'' ]
      );

      buttonSetup = lib.concatStringsSep "\n" (
        [ "btn.count = ${toString (lib.length buttons)};" ]
        ++ lib.imap0 (i: name: ''
          btn.name[${toString i}] = "${name}";
          btn.label[${toString i}] = "${labels.${name}}";'') buttons
        ++ [ ''btn.label_verify = "${labels.privacy-verify}";'' ]
      );

      privacyVerify =
        let
          mode =
            if privacyDefault != null then
              privacyDefault
            else if lib.elem "privacy" buttons then
              "private"
            else
              "verify";
        in
        if mode == "verify" then "1" else "0";

      decodeEnabled = if entryStyle == "decode" then "1" else "0";
      # Weights become a pick table of glyph indices: rand_glyph() then
      # stays a single lookup per frame however the weights are set.
      glyphSetup = lib.concatStringsSep "\n" (
        [ "glyphs.count = ${toString (lib.length glyphs)};" ]
        ++ lib.imap0 (
          i: spec: ''glyphs.set[${toString i}] = "${lib.replaceStrings [ "\"" ] [ "\\\"" ] spec.g}";''
        ) glyphs
        ++ (
          let
            picks = lib.concatLists (lib.imap0 (i: spec: lib.replicate spec.w i) glyphs);
          in
          [ "glyphs.picks = ${toString (lib.length picks)};" ]
          ++ lib.imap0 (k: i: "glyphs.pick[${toString k}] = ${toString i};") picks
        )
      );

      # The script scanner knows \n, \e, \0 and \" but not \t; splice a
      # literal tab in instead.
      tabChar = "\t";
    }
    // builtins.removeAttrs colors [ "logoFilter" "tint" ]
  );

  theme = pkgs.runCommand "plymouth-theme-acid-nix-${palette}" { } ''
    d=$out/share/plymouth/themes/acid-nix
    mkdir -p $d
    cp ${logos}/logo-*.png $d/
    cp -r ${icons}/. $d/
    cp ${script} $d/acid-nix.script
    cat > $d/acid-nix.plymouth <<EOF
    [Plymouth Theme]
    Name=Acid Nix (${palette})
    Description=Glowing nix snowflake with a live boot-log tail
    ModuleName=script

    [script]
    ImageDir=$d
    ScriptFile=$d/acid-nix.script
    EOF
  '';
}
