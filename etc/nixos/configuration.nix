{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  networking = {
    hostName = "nixos";
    networkmanager.enable = true;
    firewall.allowedUDPPorts = [ 19132 ];
  };

  time.timeZone = "America/New_York";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  environment = {
    sessionVariables.GTK_THEME = "Adwaita:dark";

    systemPackages = with pkgs; [
      # Development toolchains and libraries
      clang
      gcc
      git
      github-cli
      gnumake
      go
      nodejs_22
      openssl
      pkg-config
      python3
      ruby
      rustup
      sqlite
      vlang

      # Command-line and system tools
      fastfetch
      jq
      lsof
      wakatime-cli
      wget
      wl-clipboard
      ripgrep

      # Containers
      docker
      docker-compose
      lazydocker

      # Desktop applications
      libreoffice
      mcpelauncher-client
      mcpelauncher-ui-qt
      zed-editor
      zoom-us

      # Communication
      discord
      geary

      # AI development tools
      claude-code
      codex
    ];
  };

  services = {
    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
    nats.enable = true;
    printing.enable = true;

    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };

    pulseaudio.enable = false;

    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
    };
  };

  security.rtkit.enable = true;

  users.users.danick = {
    isNormalUser = true;
    description = "Danick Lachapelle";
    extraGroups = [
      "docker"
      "networkmanager"
      "wheel"
    ];
  };

  programs = {
    firefox.enable = true;
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc
        zlib
        openssl
        glibc
      ];
    };
  };

  virtualisation = {
    docker.enable = true;
    waydroid = {
      enable = true;
      package = pkgs.waydroid-nftables;
    };
  };

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  nixpkgs.config.allowUnfree = true;

  # Keep this at the release used for the original NixOS installation.
  system.stateVersion = "26.05";
}
