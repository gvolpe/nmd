{ pkgs, lib

# ID of the `variablelist` DocBook element holding the documented
# options.
, id

# Prefix to add to specific option entries. For an option `foo.bar`
# the XML identifier is `<optionIdPrefix>-foo.bar`.
#
# Example:
#    optionIdPrefix = "myopt";
, optionIdPrefix ? "opt"

  # A function taking the relative module path to an URL where the
  # module can be viewed.
  #
  # Example:
  #     mkModuleUrl = path: "https://myproject.foo/${path}"
, mkModuleUrl

# The "typical" channel name for this module set. This will be used
# to present a friendly path to the module defining an option.
#
# Example:
#     channelName = "myproject"
, channelName

, optionsDocs }:

with lib;

let

  optionsXml = pkgs.writeText "nmd-options.xml" (builtins.toXML optionsDocs);

  optionsDocBook = pkgs.runCommand "options-db.xml" {
    nativeBuildInputs = [ (getBin pkgs.libxslt) ];
  } ''
    mkdir $out
    xsltproc \
      --stringparam elementId '${id}' \
      --stringparam optionIdPrefix '${optionIdPrefix}' \
      -o $out/nmd-result/${id}.xml \
      ${./options-to-docbook.xsl} ${optionsXml}
  '';

in optionsDocBook
