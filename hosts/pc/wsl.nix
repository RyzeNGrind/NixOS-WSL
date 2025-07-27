{ config, lib, pkgs, ... }:

{
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    # Add required runtime libraries here, example:
    stdenv.cc.cc
    glib
    zlib
    mesa.drivers
    libdrm
    xorg.libxcb
    xorg.libX11
    libGL
    vulkan-loader
    vulkan-validation-layers
    libva
    libvdpau-va-gl
    glibc
    gcc-unwrapped.lib
  ];

  # Remove Mesa overlay for now - let's use standard Mesa and configure DZN through environment
  # nixpkgs.overlays = [
  #   (final: prev: {
  #     mesa = prev.mesa.override {
  #       galliumDrivers = [ "d3d12" "softpipe" "llvmpipe" "zink" "svga" ];
  #       vulkanDrivers = [ "microsoft-experimental" ];
  #     };
  #   })
  # ];

  wsl = {
    enable = true;
    defaultUser = "ryzengrind"; ##EDIT_ME##
    docker-desktop.enable = true;
    startMenuLaunchers = true;
    useWindowsDriver = true;
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
        appendWindowsPath = true;
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
    rootless = {
      enable = true;
      setSocketVariable = true;
      daemon.settings = {
        features.cdi = true;
        cdi-spec-dirs = ["/home/${config.users.users.ryzengrind.name}/.cdi" "/etc/cdi"];
      };
    };
    daemon.settings = {
      features.cdi = true;
      cdi-spec-dirs = ["/etc/cdi"];
    };
  };

  hardware = {
    # Use hardware.graphics for NixOS 24.11+
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        mesa.drivers
        vulkan-loader
        vulkan-validation-layers
        vulkan-extension-layer
        libva
        libvdpau-va-gl
        vaapiVdpau
      ];
      extraPackages32 = with pkgs.pkgsi686Linux; [
        mesa.drivers
        vulkan-loader
      ];
    };
    nvidia = {
      modesetting.enable = true;
      nvidiaSettings = false;
      open = false;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      # REQUIRED: Enable nvidia driver for nvidia-container-toolkit
      # See: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/1.16.2/install-guide.html#prerequisites
      # This is required for nvidia-container-toolkit to work.
      # If you do not want to use X11, you can still set videoDrivers to [ "nvidia" ].
      # If you are using WSL2 and want to use D3D12, you can disable X11 but still need the driver for toolkit.
      # If you want to use datacenter drivers, set datacenter.enable = true instead.
    };
    nvidia-container-toolkit = {
      enable = true;
      mount-nvidia-executables = false;
    };
  };
  # FIXED: Enable NVIDIA video drivers - required for nvidia-container-toolkit
  # Even in WSL2, the nvidia-container-toolkit requires this to be set
  services.xserver.videoDrivers = lib.mkForce [ "nvidia" ];

  users.groups.docker.members = [
    config.wsl.defaultUser
  ];

  environment.systemPackages = with pkgs; [ ##EDIT_ME##
    curl
    git
    wget
    neofetch
    nvtopPackages.full
    nvidia-docker
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
    # Graphics and GPU tools
    glxinfo
    vulkan-tools
    mesa-demos
    pciutils
    lshw
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

  environment.extraInit = ''
    mkdir -p /usr/bin
    ln -sf ${pkgs.systemd}/bin/systemctl /usr/bin/systemctl
    ln -sf ${pkgs.gnugrep}/bin/grep /usr/bin/grep
  '';

  # FIXED: Correct environment variables for WSL2 Vulkan DZN support
  environment.sessionVariables = {
    # NVIDIA-specific paths for WSL2 - combine with nix-ld path
    NIX_LD_LIBRARY_PATH = lib.mkForce "/usr/lib/wsl/lib:/run/current-system/sw/share/nix-ld/lib";
    LD_LIBRARY_PATH = "/usr/lib/wsl/lib:/run/opengl-driver/lib:/run/opengl-driver-32/lib";
    MESA_D3D12_DEFAULT_ADAPTER_NAME = "NVIDIA";
    MESA_LOADER_DRIVER_OVERRIDE = "d3d12";
    # FIXED: Use correct Vulkan ICD environment variable
    VK_ICD_FILENAMES = "/usr/share/vulkan/icd.d/dzn_icd.x86_64.json:/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json";
  };

  # System-level environment variables that persist across sessions
  environment.variables = {
    MESA_D3D12_DEFAULT_ADAPTER_NAME = "NVIDIA";
    GALLIUM_DRIVER = "d3d12";
    # See https://github.com/NixOS/nixpkgs/issues/52639 for XDG_DATA_DIRS Vulkan fix
    XDG_DATA_DIRS = lib.mkForce "/run/opengl-driver/share:$XDG_DATA_DIRS";
  };

  # CDI generation service - runs on boot to generate NVIDIA CDI specs
  systemd.services.nvidia-cdi-generate = {
    description = "Generate NVIDIA CDI specifications for containers";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "nvidia-cdi-setup" ''
        set -eu

        # Ensure CDI directories exist
        mkdir -p /etc/cdi
        mkdir -p /home/${config.wsl.defaultUser}/.cdi

        # Generate system-wide CDI spec
        if ! test -f /etc/cdi/nvidia.yaml; then
          echo "Generating system-wide NVIDIA CDI spec..."
          ${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk cdi generate --output="/etc/cdi/nvidia.yaml" || echo "Failed to generate system CDI spec"
        fi

        # Generate user CDI spec with proper ownership
        if ! test -f /home/${config.wsl.defaultUser}/.cdi/nvidia.yaml; then
          echo "Generating user NVIDIA CDI spec..."
          ${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk cdi generate --output="/home/${config.wsl.defaultUser}/.cdi/nvidia.yaml" || echo "Failed to generate user CDI spec"
          chown -R ${config.wsl.defaultUser}:users /home/${config.wsl.defaultUser}/.cdi/ || true
        fi

        echo "NVIDIA CDI setup completed"
      '';
    };
  };

  # User service for CDI generation (runs as user, not root)
  systemd.user.services.nvidia-cdi-user = {
    description = "Generate user NVIDIA CDI specifications";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "nvidia-cdi-user-setup" ''
        set -eu

        # Ensure user CDI directory exists
        mkdir -p "$HOME/.cdi"

        # Generate user CDI spec
        if ! test -f "$HOME/.cdi/nvidia.yaml"; then
          echo "Generating user NVIDIA CDI spec..."
          ${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk cdi generate --output="$HOME/.cdi/nvidia.yaml" || echo "Failed to generate user CDI spec"
        fi

        echo "User NVIDIA CDI setup completed"
      '';
    };
  };

  # Ensure proper user session handling
  services.logind.killUserProcesses = false;
  # Enable lingering for your user
  system.stateVersion = "24.11";

  # UPDATED: WSL2 Vulkan DZN setup using standard Mesa
  systemd.services.wsl-vulkan-setup = {
    description = "Setup WSL2 Vulkan DZN support";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "wsl-vulkan-setup" ''
        set -eu
        
        echo "Setting up WSL2 Vulkan support..."
        
        mkdir -p /usr/share/vulkan/icd.d
        
        # Check if DZN driver exists in standard Mesa
        if [[ -f ${pkgs.mesa.drivers}/lib/libvulkan_dzn.so ]]; then
          echo "Found DZN driver, creating ICD file..."
          cat > /usr/share/vulkan/icd.d/dzn_icd.x86_64.json << 'EOF'
{
    "file_format_version" : "1.0.0",
    "ICD": {
        "library_path": "${pkgs.mesa.drivers}/lib/libvulkan_dzn.so",
        "api_version" : "1.3.0"
    }
}
EOF
        else
          echo "DZN driver not found in standard Mesa, skipping Vulkan setup..."
        fi
        
        mkdir -p /usr/lib/wsl/lib
        ln -sf ${pkgs.mesa.drivers}/lib/dri/* /usr/lib/wsl/lib/ || true
        
        if [[ -f ${pkgs.mesa.drivers}/lib/libvulkan_dzn.so ]]; then
          ln -sf ${pkgs.mesa.drivers}/lib/libvulkan_dzn.so /usr/lib/wsl/lib/ || true
        fi
        
        echo "WSL2 Vulkan setup completed"
      '';
    };
  };
}
