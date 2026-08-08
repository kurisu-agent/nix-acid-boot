{
  description = "Acid-green Nix snowflake Plymouth theme with a live boot-log tail";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});
    in
    {
      nixosModules.default = import ./module.nix;

      packages = forAllSystems (
        pkgs:
        let
          palettes = builtins.attrNames (import ./palettes.nix);
          variant = palette: import ./theme.nix { inherit pkgs palette; };
          acid = variant "acid-green";
        in
        {
          default = acid.theme;
          theme = acid.theme;
          logo = acid.logo;
          plymouth-patched = acid.plymouth;
        }
        // nixpkgs.lib.listToAttrs (
          map (p: {
            name = "theme-${p}";
            value = (variant p).theme;
          }) palettes
        )
      );
    };
}
