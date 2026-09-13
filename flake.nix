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
    in
    {
      packages.${system} = {
        default = claude-desktop;
        claude-desktop = claude-desktop;
      };

      apps.${system}.default = {
        type = "app";
        program = "${claude-desktop}/bin/claude-desktop";
        meta.description = "Claude Desktop for Linux";
      };
    };
}
