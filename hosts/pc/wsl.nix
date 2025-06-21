{ config, lib, pkgs, ... }:

{
  # Custom configurations specific to my NixOS-WSL setup
  wsl = {
    enable = true;
    defaultUser = "ryzengrind"; ##EDIT_ME##
    docker-desktop.enable = false;
    startMenuLaunchers = true;
    wslConf = {
      automount = {
        enabled = true;
        options = "metadata,umask=22,fmask=11,uid=1000,gid=100";
        root = "/mnt";
      };
      network = {
        generateHosts = true;
        generateResolvConf = true;
        hostname = "pc"; ##EDIT_ME##
      };
      interop = {
        appendWindowsPath = false;
      };
    };
    extraBin = with pkgs; [
      { src = "${coreutils}/bin/mkdir"; }
      { src = "${coreutils}/bin/cat"; }
      { src = "${coreutils}/bin/whoami"; }
      { src = "${coreutils}/bin/ls"; }
      { src = "${busybox}/bin/addgroup"; }
      { src = "${su}/bin/groupadd"; }
      { src = "${su}/bin/usermod"; }
      { src = "${shadow}/sbin/unix_chkpwd"; } #<-- CRUCIAL for PAM
      { src = "${systemd}/bin/systemctl"; }
      { src = "${systemd}/bin/loginctl"; } # Good to include for any linger checks
      { src = "${gnugrep}/bin/grep"; }

    ];
  };
  

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune.enable = true;
  };

  users.groups.docker.members = [
    config.wsl.defaultUser
  ];

  environment.systemPackages = with pkgs; [ ##EDIT_ME##
    curl
    git
    wget
    neofetch
    nvtopPackages.full
    _1password-gui-beta
    fish
    home-manager
    sd-switch
    dconf2nix
    tmux
    nixops_unstable_minimal
    nixops-dns
    nixVersions.stable  
    #nixVersions.minimal
    #nixVersions
    nix
    tzdata
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" "auto-allocate-uids" ];
  nix.settings.max-jobs = 1;
  boot.isContainer = true;
  
  users.users.ryzengrind = { ##EDIT_ME##
    isNormalUser = true;
    hashedPassword = "$6$VOP1Yx5OUXwpOFaG$tVWf3Ai0.kzXpblhnatoeHHZb1xGKUuSEEQO79y1efrSyXR0sGmvFjo7oHbZBuQgZ3NFZi0MahU5hbyzsIwqq."; ##EDIT_ME##
    linger = true;
    extraGroups = [ "wheel" "docker" ]; # Add necessary groups
  };
  
  users.users.root = { ##EDIT_ME##
    hashedPassword = "$6$VOP1Yx5OUXwpOFaG$tVWf3Ai0.kzXpblhnatoeHHZb1xGKUuSEEQO79y1efrSyXR0sGmvFjo7oHbZBuQgZ3NFZi0MahU5hbyzsIwqq."; ##EDIT_ME##
  };
  services.earlyoom = {
    enable = true;
    enableNotifications = false;
    enableDebugInfo = true;
  
    # Use the dedicated NixOS options instead of extraArgs for basic parameters
    freeMemThreshold = 10;          # Equivalent to -m 10
    freeMemKillThreshold = 5;       # Second threshold for SIGKILL
    freeSwapThreshold = 5;          # Equivalent to -s 5  
    freeSwapKillThreshold = 2;      # Second threshold for SIGKILL
    reportInterval = 3600;          # Equivalent to -r (in seconds)
  
    # Only use extraArgs for options not covered by dedicated NixOS options
    extraArgs = [
      # Add any additional earlyoom options here that don't have dedicated NixOS options
      # For example: "--prefer" or "--avoid" regexes
    ];
  };

  
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
      PubkeyAuthentication = true;
    };
    ports = [ 22 ];
  };

  # Open firewall for SSH
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };
  systemd.slices."nix-daemon".sliceConfig = {
    ManagedOOMMemoryPressure = "kill";
    ManagedOOMMemoryPressureLimit = "60%";
  };

  systemd.services.nix-daemon.serviceConfig = {
    Slice = "nix-daemon.slice";
    OOMScoreAdjust = 1000;
  };
  # FIX #2: Use extraInit for creating the symlink, as it's more reliable.
  environment.extraInit = ''
    mkdir -p /usr/bin
    ln -sf ${pkgs.systemd}/bin/systemctl /usr/bin/systemctl
    ln -sf ${pkgs.gnugrep}/bin/grep /usr/bin/grep
  '';  
  # Ensure proper user session handling
  services.logind.killUserProcesses = false;
  # Enable lingering for your user
  system.stateVersion = "24.11";
}

