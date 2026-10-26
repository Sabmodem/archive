{
  description = "Archive: disko + devShell с mbsync/syncthing/vscode";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };

    my-vscode = pkgs.vscode-with-extensions.override {
      vscodeExtensions = with pkgs.vscode-extensions; [
        ms-azuretools.vscode-containers
        jnoortheen.nix-ide
      ];
    };
    # ── утилиты монтирования ─────────────────────────────────────────────
    mountArchive = pkgs.writeShellApplication {
      name = "mount-archive";
      runtimeInputs = with pkgs; [ btrfs-progs util-linux coreutils ];
      text = ''
        : "''${ARCHIVE_DEVICE:?ARCHIVE_DEVICE не задан}"
        : "''${ARCHIVE_MOUNT_POINT:?ARCHIVE_MOUNT_POINT не задан}"

        if findmnt -rn -M "$ARCHIVE_MOUNT_POINT" >/dev/null 2>&1; then
          echo "Уже смонтировано в $ARCHIVE_MOUNT_POINT" >&2
          exit 0
        fi

        sudo mkdir -p "$ARCHIVE_MOUNT_POINT"
        sudo mount -t btrfs -o subvol=@archive "$ARCHIVE_DEVICE" "$ARCHIVE_MOUNT_POINT"
        echo "Смонтировано $ARCHIVE_DEVICE (@archive) в $ARCHIVE_MOUNT_POINT"
      '';
    };

    umountArchive = pkgs.writeShellApplication {
      name = "umount-archive";
      runtimeInputs = with pkgs; [ util-linux coreutils ];
      text = ''
        : "''${ARCHIVE_MOUNT_POINT:?ARCHIVE_MOUNT_POINT не задан}"

        if ! findmnt -rn -M "$ARCHIVE_MOUNT_POINT" >/dev/null 2>&1; then
          echo "Ничего не смонтировано в $ARCHIVE_MOUNT_POINT" >&2
          exit 0
        fi

        sudo umount "$ARCHIVE_MOUNT_POINT"
        echo "Размонтировано $ARCHIVE_MOUNT_POINT"
      '';
    };
  in {
    # ── disko ───────────────────────────────────────────────────────────
    # Остаётся функцией с параметром device.
    # --argstr device /dev/loop1 → сюда прилетит строка.
    diskoConfigurations.archive = { device, ... }: {
      disko.devices.disk.archive = {
        type = "disk";
        inherit device;
        content = {
          type = "gpt";
          partitions.data = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" "-L" "archive" ];
              subvolumes = {
                "@ingress"      = { };
                "@archive" = { };
                "@live"     = { };
                "@snapshots" = { };
              };
            };
          };
        };
      };
    };

    packages.${system} = {
      mount-archive  = mountArchive;
      umount-archive = umountArchive;
      default        = mountArchive;
    };

    # ── devShell ────────────────────────────────────────────────────────
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        isync
        syncthing
        btrfs-progs
        util-linux
        my-vscode
        mountArchive
        umountArchive
      ];
    };
  };
}