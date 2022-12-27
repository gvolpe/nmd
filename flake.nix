{
  description = "nmd: NixOS Module Documentation";

  inputs.nixpkgs.url = github:nixos/nixpkgs/nixpkgs-unstable;

  outputs = { self, nixpkgs }:
    {
      overlays.default = f: p: {
        nmd = p.callPackage ./builders.nix { };
      };
    };
}
