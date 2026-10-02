{
  description = "Claude Desktop Linux packaging";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      claude-desktop = pkgs.callPackage ./package.nix { };
      claude-desktop-fhs = pkgs.callPackage ./fhs.nix {
        inherit claude-desktop;
      };
    in
    {
      packages.${system} = {
        default = claude-desktop-fhs;
        fhs = claude-desktop-fhs;
        claude-desktop = claude-desktop;
      };

      apps.${system} = {
        default = {
          type = "app";
          program = "${claude-desktop-fhs}/bin/claude-desktop";
          meta.description = "Claude Desktop for Linux (FHS Cowork-enabled)";
        };
        pure = {
          type = "app";
          program = "${claude-desktop}/bin/claude-desktop";
          meta.description = "Claude Desktop for Linux (Pure derivation)";
        };
      };

      overlays.default = final: prev: {
        claude-desktop = final.callPackage ./package.nix { };
        claude-desktop-fhs = final.callPackage ./fhs.nix {
          claude-desktop = final.claude-desktop;
        };
      };
    };
}
