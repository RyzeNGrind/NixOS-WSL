# Recovery Shell

A recovery shell can be started with

```powershell
wsl -d NixOS --system --user root -- /mnt/wslg/distro/bin/nixos-wsl-recovery
```

This will load the WSL "system" distribution, activate your configuration,
then chroot into your NixOS system, similar to what `nixos-enter` would do
on a normal NixOS install.

You can choose an older generation to load with

```powershell
wsl -d NixOS --system --user root -- /mnt/wslg/distro/bin/nixos-wsl-recovery --system /nix/var/nix/profiles/system-42-link
```

(note that the path is relative to the new root)

# Troubleshooting

## General Tips

- Try fully restarting WSL by running `wsl --shutdown`. This will close all your terminal windows. Then just restart wsl in your terminal. \
  Please keep in mind that this will also end any process you might have running in other WSL distros.
  If that is currently not an option, you may try `wsl -t nixos`, which will just stop the `nixos` distro.
  (You may need to change that if you imported the distro under some other name). However, some issues will only be resolved after a _full_ restart of WSL.
- Make sure that you are using the [Microsoft Store version](https://www.microsoft.com/store/productId/9P9TQF7MRM4R) of WSL
- Update WSL2 to the latest version
  - To update, run: `wsl --update`
  - To check which version you currently have installed, run `wsl --version`
    - The latest version can be found on the [Microsoft/WSL](https://github.com/microsoft/WSL/releases/latest) repo
    - If this command does not work, you are probably not using the Microsoft Store version of WSL!

# Building your own system tarball

This requires access to a system that already has Nix installed. Please refer to the [Nix installation guide](https://nixos.org/guides/install-nix.html) if that\'s not the case.

If you have a flakes-enabled Nix, you can use the following command to
build your own tarball instead of relying on a prebuilt one:

```sh
sudo nix run github:nix-community/NixOS-WSL#nixosConfigurations.default.config.system.build.tarballBuilder
```

Or, if you want to build with local changes, run inside your checkout:

```sh
sudo nix run .#nixosConfigurations.your-hostname.config.system.build.tarballBuilder
```

Without a flakes-enabled Nix, you can build a tarball using:

```sh
nix-build -A nixosConfigurations.default.config.system.build.tarballBuilder && sudo ./result/bin/nixos-wsl-tarball-builder

```

The resulting tarball can then be found under `nixos.wsl`.

# Design

Getting NixOS to run under WSL requires some workarounds:

- instead of directly loading systemd, we use a small shim that runs the NixOS activation scripts first
- some additional binaries required by WSL's internal tooling are symlinked to FHS paths on activation

Running on older WSL versions also requires a workaround to spawn systemd by hijacking the root shell and
spawning a container with systemd inside. This method of running things is deprecated and will be removed
with the 24.11 release.

# Installation

## System requirements

NixOS-WSL is tested with the Windows Store version of WSL 2, which is now available on all supported Windows releases (both 10 and 11).
Support for older "inbox" versions is best-effort.

## Install NixOS-WSL

First, download `nixos.wsl` from [the latest release](https://github.com/nix-community/NixOS-WSL/releases/latest).[^wsl-file]

If you have WSL version 2.4.4 or later installed, you can open (double-click) the .wsl file to install it.
It is also possible to perform the installation from a PowerShell:

```powershell
wsl --install --from-file nixos.wsl
```

`nixos.wsl` must be the path to the file you just downloaded if you're running the command in another directory.

You can use the `--name` and `--location` flags to change the name the distro is registered under (default: `NixOS`) and the location of the disk image (default: `%localappdata%\wsl\{some random GUID}`). For a full list of options, refer to `wsl --help`

To open a shell in your NixOS environment, run `wsl -d NixOS`, select NixOS from the profile dropdown in Windows Terminal or run it from your Start Menu. (Adjust the name accordingly if you changed it)

### Older WSL versions

If you have a WSL version older than 2.4.4, you can install NixOS-WSL like this:

Open up a PowerShell and run:

```powershell
wsl --import NixOS $env:USERPROFILE\NixOS nixos.wsl --version 2
```

Or for Command Prompt:

```cmd
wsl --import NixOS %USERPROFILE%\NixOS nixos.wsl --version 2
```

This sets up a new WSL distribution `NixOS` that is installed in a directory called `NixOS` inside your user directory.
`nixos.wsl` is the path to the file you downloaded earlier.
You can adjust the installation path and distribution name to your liking.

To get a shell in your NixOS environment, use:

```powershell
wsl -d NixOS
```

If you chose a different name for your distro during import, adjust this command accordingly.

## Post-Install

After the initial installation, you need to update your channels once, to be able to use `nixos-rebuild`:

```sh
sudo nix-channel --update
```

If you want to make NixOS your default distribution, you can do so with

```powershell
wsl -s NixOS
```

[^wsl-file]: That file is called `nixos-wsl.tar.gz` in releases prior to 2411.*
