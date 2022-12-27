{ pkgs, lib }:

{
  # The name identifying the manual on disk. The output packages will,
  # e.g., install documentation to `share/doc/<name>`.
  pathName

  # The name of the project being documented. Default is to use `pathName`.
, projectName ? pathName

  # List of modules documentation as produced by `buildModulesDocs`.
, modulesDocs ? [ ]

  # Directory of DocBook documents. This directory is expected to
  # contain the files
  #
  # - `manual.xml` containing a `book` element, and
  #
  # - `man-pages.xml` containing a `reference` element.
, documentsDirectory

  # The DocBook document type. Must be one of "article", "manpage", or
  # "book".
, documentType ? "article"

  # DocBook table of content configuration. This should be a string
  # containing a `toc` element.
, chunkToc

  # DocBook theme. One of the following:
  # [ "agate" "github-dark" "mono-blue" "night-owl" ]
, theme ? "github-dark"
}:

with lib;

let

  inherit (pkgs) docbook5;
  # See https://github.com/NixOS/nixpkgs/pull/166509
  docbook-xsl-ns = pkgs.docbook-xsl-ns.override { withManOptDedupPatch = true; };

  docBookFromAsciiDocDirectory = pkgs.runCommand "converted-asciidoc"
    {
      nativeBuildInputs = [ (getBin pkgs.asciidoc) (getBin pkgs.libxslt) ];
    } ''
    function convert() {
      mkdir -p $(dirname $2)
      asciidoc -s -d ${documentType} -b docbook --out-file - "$1" \
        | xsltproc -o "$2" ${docbook5}/share/xml/docbook-5.0/tools/db4-upgrade.xsl -
    }

    mkdir $out
    cd "${documentsDirectory}"

    for file in *.adoc **/*.adoc ; do
      echo Converting $file to DocBook ...
      convert "$file" "$out/''${file%.adoc}.xml"
    done
  '';

  combinedDirectory = pkgs.buildEnv {
    name = "nmd-documents";
    paths = [ documentsDirectory docBookFromAsciiDocDirectory ]
      ++ map (v: v.docBook) modulesDocs;
  };

  manualXml = "${combinedDirectory}/manual.xml";
  manPagesXml = "${combinedDirectory}/man-pages.xml";

  runXmlCommand = name: attrs: command:
    pkgs.runCommand name
      (attrs // {
        nativeBuildInputs = [
          (pkgs.path + /pkgs/build-support/setup-hooks/compress-man-pages.sh)
          (getBin pkgs.libxml2)
          (getBin pkgs.libxslt)
        ];
      })
      command;

  manualCombined = runXmlCommand "manual-combined" { } ''
    mkdir $out

    xmllint --xinclude \
      --output $out/manual-combined.xml ${manualXml}
    xmllint --xinclude --noxincludenode \
      --output $out/man-pages-combined.xml ${manPagesXml}

    # outputs the context of an xmllint error output
    # LEN lines around the failing line are printed
    function context {
      # length of context
      local LEN=6
      # lines to print before error line
      local BEFORE=4

      # xmllint output lines are:
      # file.xml:1234: there was an error on line 1234
      while IFS=':' read -r file line rest; do
        echo
        if [[ -n "$rest" ]]; then
          echo "$file:$line:$rest"
          local FROM=$(($line>$BEFORE ? $line - $BEFORE : 1))
          # number lines & filter context
          nl --body-numbering=a "$file" | sed -n "$FROM,+$LEN p"
        else
          if [[ -n "$line" ]]; then
            echo "$file:$line"
          else
            echo "$file"
          fi
        fi
      done
    }

    function lintrng {
      xmllint --debug --noout --nonet \
        --relaxng ${docbook5}/xml/rng/docbook/docbook.rng \
        "$1" \
        2>&1 | context 1>&2
        # ^ redirect assumes xmllint doesn’t print to stdout
    }

    lintrng $out/manual-combined.xml
    lintrng $out/man-pages-combined.xml
  '';

  toc = builtins.toFile "toc.xml" chunkToc;

  manualXsltprocOptions = toString [
    "--param section.autolabel 1"
    "--param section.label.includes.component.label 1"
    "--stringparam html.stylesheet 'style.css overrides.css ${theme}.css'"
    "--stringparam html.script 'highlight.pack.js highlight.load.js'"
    "--param xref.with.number.and.title 1"
    "--param toc.section.depth 3"
    "--stringparam admon.style ''"
    "--stringparam callout.graphics.extension .svg"
    "--stringparam current.docid manual"
    "--param use.id.as.filename 1"
    "--stringparam generate.toc 'book toc appendix toc'"
    "--stringparam chunk.toc ${toc}"
    "--param highlight.source 1"
  ];

  # The XSL template to use. This is an extension of the standard
  # chunktoc.xsl template but with minor enhancements for highlight.js
  # support.
  docbookXsl = pkgs.substituteAll {
    src = ../lib/nmd-chunktoc.xsl;
    docbook_xsl_ns = docbook-xsl-ns;
  };

  olinkDb = runXmlCommand "manual-olinkdb" { } ''
    mkdir $out

    xsltproc \
      ${manualXsltprocOptions} \
      --stringparam collect.xref.targets only \
      --stringparam targets.filename "$out/manual.db" \
      --nonet \
      ${docbookXsl} \
      ${manualCombined}/manual-combined.xml

    cat > "$out/olinkdb.xml" <<EOF
    <?xml version="1.0" encoding="utf-8"?>
    <!DOCTYPE targetset SYSTEM
      "file://${docbook-xsl-ns}/xml/xsl/docbook/common/targetdatabase.dtd" [
      <!ENTITY manualtargets SYSTEM "file://$out/manual.db">
    ]>
    <targetset>
      <targetsetinfo>
        Allows for cross-referencing olinks between the man pages
        and manual.
      </targetsetinfo>

      <document targetdoc="manual">&manualtargets;</document>
    </targetset>
    EOF
  '';

  html = runXmlCommand "html-manual" { allowedReferences = [ "out" ]; } ''
    # Generate the HTML manual.
    dst=$out/share/doc/${pathName}
    mkdir -p $dst
    xsltproc \
      ${manualXsltprocOptions} \
      --stringparam target.database.document "${olinkDb}/olinkdb.xml" \
      --nonet --output $dst/ \
      ${docbookXsl} \
      ${manualCombined}/manual-combined.xml

    mkdir -p $dst/images/callouts
    cp ${docbook-xsl-ns}/xml/xsl/docbook/images/callouts/*.svg $dst/images/callouts/

    cp ${../static/style.css} $dst/style.css
    cp ${../static/overrides.css} $dst/overrides.css
    cp ${../static/highlightjs/highlight.pack.js} $dst/highlight.pack.js
    cp ${../static/highlightjs/highlight.load.js} $dst/highlight.load.js
    cp ${../static/highlightjs/style/${theme}.css} $dst/${theme}.css
  '';

  htmlOpenTool = { name ? "${pathName}-help" }:
    let
      helpScript = pkgs.writeShellScriptBin name ''
        set -euo pipefail

        if [[ ! -v BROWSER || -z $BROWSER ]]; then
          for candidate in xdg-open open w3m; do
            BROWSER="$(type -P $candidate || true)"
            if [[ -x $BROWSER ]]; then
              break;
            fi
          done
        fi

        if [[ ! -v BROWSER || -z $BROWSER ]]; then
          echo "$0: unable to start a web browser; please set \$BROWSER"
          exit 1
        else
          exec "$BROWSER" "${html}/share/doc/${pathName}/index.html"
        fi
      '';

      desktopItem = pkgs.makeDesktopItem {
        name = "${pathName}-manual";
        desktopName = "${projectName} Manual";
        genericName = "View ${projectName} documentation in a web browser";
        icon = "nix-snowflake";
        exec = "${helpScript}/bin/${name}";
        categories = [ "System" ];
      };
    in
    pkgs.symlinkJoin {
      inherit name;
      paths = [ helpScript desktopItem ];
    };

  manPages = runXmlCommand "man-pages" { allowedReferences = [ "out" ]; } ''
    # Generate manpages.
    mkdir -p $out/share/man
    xsltproc --nonet \
      --param man.output.in.separate.dir 1 \
      --param man.output.base.dir "'$out/share/man/'" \
      --param man.endnotes.are.numbered 0 \
      --param man.break.after.slash 1 \
      --stringparam target.database.document "${olinkDb}/olinkdb.xml" \
      ${docbook-xsl-ns}/xml/xsl/docbook/manpages/docbook.xsl \
      ${manualCombined}/man-pages-combined.xml

    compressManPages $out
  '';

in
{
  inherit manualCombined olinkDb;
  inherit html manPages;
  htmlOpenTool = makeOverridable htmlOpenTool { };
}
