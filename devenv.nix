{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  # https://devenv.sh/basics/
  env.GREET = "devenv";

  overlays = [ inputs.nixgl.overlays.default ];

  # https://devenv.sh/packages/
  packages = [
    pkgs.git
    pkgs.flutter
    pkgs.nixgl.auto.nixGLDefault
    # Orange / Clash desktop deps
    pkgs.go
    pkgs.keybinder3
    pkgs.libayatana-appindicator
  ];

  # https://devenv.sh/scripts/
  scripts.hello.exec = ''
    echo hello from $GREET
  '';

  scripts.linux-run.exec = "nixGL flutter run -d linux";

  # https://devenv.sh/basics/
  enterShell = ''
    hello
    git --version
    echo "flutter: $(flutter --version 2>/dev/null | head -1)"
    echo "Linux desktop: linux-run   # or: nixGL flutter run -d linux"
  '';

  # https://devenv.sh/tests/
  enterTest = ''
    echo "Running tests"
    git --version | grep --color=auto "${pkgs.git.version}"
    flutter --version
    command -v nixGL
  '';

  # See full reference at https://devenv.sh/reference/options/
}
