{ pkgs, lib ? pkgs.lib }:

let

  inherit (lib) isAttrs optionalAttrs isDerivation mapAttrs;

  # Recursively replace each derivation in the given attribute set
  # with the same derivation but with the `outPath` attribute set to
  # the string `"\${pkgs.attribute.path}"`. This allows the
  # documentation to refer to derivations through their values without
  # establishing an actual dependency on the derivation output.
  #
  # This is not perfect, but it seems to cover a vast majority of use
  # cases.
  #
  # Caveat: even if the package is reached by a different means, the
  # path above will be shown and not e.g.
  # `${config.services.foo.package}`.
  scrubDerivations = prefixPath: attrs:
    let
      scrubDerivation = name: value:
        let pkgAttrName = prefixPath + "." + name;
        in if isAttrs value then
          scrubDerivations pkgAttrName value
          // optionalAttrs (isDerivation value) {
            outPath = "\${${pkgAttrName}}";
          }
        else
          value;
    in mapAttrs scrubDerivation attrs;

in {
  inherit scrubDerivations;

  buildModulesDocs = import ./lib/modules-doc.nix { inherit lib pkgs; };
  buildDocBookDocs = import ./lib/manual-docbook.nix { inherit lib pkgs; };
}
