# Android CLI helpers — run `just` to list
default:
    @just --list

android-info:
    android info

android-sdk:
    android sdk list

# Emulator profiles / AVDs
emu-profiles:
    android emulator create --list-profiles

emu-list:
    android emulator list

# Create AVD (profile: medium_phone, medium_tablet, …)
emu-create profile="medium_phone":
    android emulator create {{profile}}

# Start / stop / remove (default: medium_phone)
emu-start name="medium_phone":
    android emulator start {{name}}

emu-start-headless name="medium_phone":
    android emulator start {{name}} --headless

emu-stop name="medium_phone":
    android emulator stop {{name}}

emu-remove name="medium_phone":
    android emulator remove {{name}}
