# Android CLI helpers adapted from qiuliw/flutter_app.
default:
    @just --list

android-info:
    android info

android-sdk:
    android sdk list

emu-profiles:
    android emulator create --list-profiles

emu-list:
    android emulator list

emu-create profile="medium_phone":
    android emulator create {{profile}}

emu-start name="medium_phone":
    android emulator start {{name}}

emu-start-headless name="medium_phone":
    android emulator start {{name}} --headless

emu-stop name="medium_phone":
    android emulator stop {{name}}

emu-remove name="medium_phone":
    android emulator remove {{name}}
