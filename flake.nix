{
  description = "nmd: NixOS Module Documentation";

  outputs = _: {
    overlays.default = f: p: {
      nmd = p.callPackage ./builders.nix { };
    };
  };
}
