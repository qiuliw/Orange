{ pkgs, inputs, ... }:
{
  overlays = [ inputs.nixgl.overlays.default ];

  packages = [
    pkgs.go
    pkgs.nixgl.auto.nixGLDefault
    pkgs.keybinder3
    pkgs.libayatana-appindicator
  ];

  android = {
    enable = true;
    flutter.enable = true;
    platforms.version = [ "31" "33" "34" "35" ];
    cmake.version = [ "3.22.1" ];
    ndk.enable = true;
  };
}
