{ pkgs, lib, optionsDocs }:

with lib;

let

  jsonData = let
    trimAttrs = flip removeAttrs [ "name" "visible" "internal" ];
    attributify = opt: {
      inherit (opt) name;
      value = trimAttrs opt;
    };
  in listToAttrs (map attributify optionsDocs);

  jsonFile = { path ? "options.json" }:
    pkgs.writeTextFile {
      name = builtins.baseNameOf path;
      destination = "/${path}";
      text = builtins.unsafeDiscardStringContext (builtins.toJSON jsonData);
    };

in makeOverridable jsonFile { }
