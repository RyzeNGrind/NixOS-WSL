# How to change the username

If you want to change the default username to something other than `nixos`, use the `wsl.defaultUser` option.
When building your own tarball, this should be sufficient. A user with the name specified in that option will be created automatically.

Changing the username on an already installed system is possible as well.
Follow these instructions to make sure, the change gets applied correctly:

1. Change the `wsl.defaultUser` setting in your configuration to the desired username.
2. Apply the configuration:\
   `sudo nixos-rebuild boot`\
   Do not use `nixos-rebuild switch`! It may lead to the new user account being misconfigured.
3. Exit the WSL shell and stop your NixOS distro:\
   `wsl -t NixOS`.
4. Start a shell inside NixOS and immediately exit it to apply the new generation:\
   `wsl -d NixOS --user root exit`
5. Stop the distro again:\
   `wsl -t NixOS`
6. Open a WSL shell. Your new username should be applied now!

# How to configure NixOS-WSL with flakes

First add a `nixos-wsl` input, then add `nixos-wsl.nixosModules.default` to your nixos configuration.

Below is a minimal `flake.nix` for you to get started:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
  };

  outputs = { self, nixpkgs, nixos-wsl, ... }: {
    nixosConfigurations = {
      nixos = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixos-wsl.nixosModules.default
          {
            system.stateVersion = "24.05";
            wsl.enable = true;
          }
        ];
      };
    };
  };
}
```

# Setup VSCode Remote

The VSCode Remote server can not be run as-is on NixOS, because it downloads a nodejs binary that
requires `/lib64/ld-linux-x86-64.so.2` to be present, which isn't the case on NixOS.

There are two options to get the server to run.
Option 1 is more robust but might impact other programs. Option 2 is a little bit more brittle and sometimes breaks on updates but doesn't influence other programs.
Both options require `wget` to be installed:

```nix
environment.systemPackages = [
    pkgs.wget
];
```

## Option 1: Set up nix-ld

[nix-ld](https://github.com/Mic92/nix-ld) is a program that provides `/lib64/ld-linux-x86-64.so.2`,
allowing foreign binaries to run on NixOS.

Running the VSCode server on NixOS-WSL requires using nix-ld 2.0 which is as of writing only on NixOS unstable or [nix-ld-rs](https://github.com/nix-community/nix-ld-rs) on NixOS 24.05.

To set it up, add the following to your configuration:

```nix
programs.nix-ld = {
    enable = true;
    package = pkgs.nix-ld-rs; # only for NixOS 24.05
};
```

## Option 2: Patch the server

The other option is to replace the nodejs binary that ships with the vscode server with one from the nodejs nixpkgs package.
[This module will set up everything that is required to get it running](https://github.com/K900/vscode-remote-workaround/blob/main/vscode.nix).  
If you are [using flakes](./nix-flakes.md), you can add that repo as a flake input and include it from there.
Otherwise, copy the file to your configuration and add it to your imports.

Add the following to your configuration to enable the module:

```nix
vscode-remote-workaround.enable = true;
```

# Install MSIXBundle Certificate

To use the `.msixbundle` launcher some systems need to install the certificate
for it. The certificate is included in the launcher and can be accessed from
it's properties. The certificate needs to be installed in the `Trusted People`
certificate store on the local machine which requires administrator privileges.

## Step by step instructions

1. Open `.msixbundle` files __properties__
2. Select __Digital Signatures__ tab
3. Select signature named `nzbr`
4. Click __details__
5. Click __View Certificate__
6. Click __Install Certificate__
7. Select `Local Machine` and click __Next__
8. Select `Place all certificates in the following store` and click __Browse__
9. Select `Trusted People` from the list and click __OK__
10. Click __Next__ and then __Finish__

You should now be able to use the `.msixbundle` launcher.
