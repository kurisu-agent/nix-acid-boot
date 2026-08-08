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
  showLog ? true,
  animations ? true,
  buildTag ? 0,
  promptText ? "Enter Password",
  promptFontName ? "JetBrains Mono",
  logFontName ? "JetBrains Mono",
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
in
rec {
  # Plymouth's script plugin feeds console boot output only to its
  # built-in Esc console viewer; this patch also forwards complete,
  # ANSI-stripped lines (tagged with the line's dominant SGR color) to
  # script land via a new Plymouth.SetBootOutputFunction hook, which the
  # theme uses for its live log tail — during boot AND shutdown, where
  # stop-job culprits show up in it.
  plymouth = pkgs.plymouth.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./patches/plymouth-script-boot-output.patch ];
  });

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
    }
    // builtins.removeAttrs colors [ "logoFilter" "tint" ]
  );

  theme = pkgs.runCommand "plymouth-theme-acid-nix-${palette}" { } ''
    d=$out/share/plymouth/themes/acid-nix
    mkdir -p $d
    cp ${logos}/logo-*.png $d/
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
