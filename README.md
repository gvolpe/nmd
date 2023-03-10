# nmd

Fork of [rycee/nmd](https://gitlab.com/rycee/nmd/) with theming options and flakes support.

## Usage

Add flake input.

```nix
{
  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixpkgs-unstable;
    nmd.url = github:gvolpe/nmd;
  };
}
```

Add overlay.

```nix
{
  pkgs = import nixpkgs {
    inherit system;
    overlays = [ inputs.nmd.overlays.default ];
  };
}
```

Use the functions provided in the `pkgs.nmd` set, e.g.

```nix
{
  docs = pkgs.nmd.buildDocBookDocs {
    pathName = "super-cool-flake";
    projectName = "My super cool project";
    modulesDocs = [ modulesDocs ];
    documentsDirectory = ./.;
    documentType = "book";
    theme = "night-owl";
  };
}
```

Rendered example: [gvolpe.com/neovim-flake](https://gvolpe.com/neovim-flake/).
