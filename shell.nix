{ system, nixpkgs }:
let
  pkgs = import nixpkgs { inherit system; };
in
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [ tree nvi alejandra pre-commit statix deadnix git gh];
}
