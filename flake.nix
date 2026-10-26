# Разметить диск: sudo nix run github:nix-community/disko -- --flake .#archive --argstr device /dev/loop1 --mode format
# Активировать flake: ARCHIVE_MOUNT_POINT=/mnt/archive ARCHIVE_DEVICE=/dev/loop0p1 nix develop --command zsh

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

        subvols="@ingress @archive @live @snapshots"
        uid="$(id -u)"
        gid="$(id -g)"

        for subvol in $subvols; do
          mount_point="''$ARCHIVE_MOUNT_POINT/$subvol"
          if findmnt -rn -M "$mount_point" >/dev/null 2>&1; then
            echo "$subvol уже смонтировано в $mount_point" >&2
            continue
          fi

          sudo mkdir -p "$mount_point"
          sudo mount -t btrfs -o subvol="$subvol" "''$ARCHIVE_DEVICE" "$mount_point"
          sudo chown "$uid:$gid" "$mount_point"
          echo "Смонтировано ''$ARCHIVE_DEVICE ($subvol) в $mount_point (uid=$uid)"
        done
      '';
    };

    umountArchive = pkgs.writeShellApplication {
      name = "umount-archive";
      runtimeInputs = with pkgs; [ util-linux coreutils ];
      text = ''
        : "''${ARCHIVE_MOUNT_POINT:?ARCHIVE_MOUNT_POINT не задан}"

        subvols="@ingress @archive @live @snapshots"

        for subvol in $subvols; do
          mount_point="''$ARCHIVE_MOUNT_POINT/$subvol"
          if findmnt -rn -M "$mount_point" >/dev/null 2>&1; then
            sudo umount "$mount_point"
            echo "Размонтировано $mount_point"
          fi
        done
      '';
    };

    syncthingArchive = pkgs.writeShellApplication {
      name = "syncthing-archive";
      runtimeInputs = with pkgs; [ syncthing coreutils ];
      text = ''
        : "''${ARCHIVE_MOUNT_POINT:?ARCHIVE_MOUNT_POINT не задан}"
        base="$ARCHIVE_MOUNT_POINT/@live/syncthing"
        mkdir -p "$base/config" "$base/data"
        exec syncthing \
          --config "$base/config" \
          --data   "$base/data" \
          --no-browser "$@"
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
      syncthing-archive = syncthingArchive;
      default        = mountArchive;
    };

    # ── devShell ────────────────────────────────────────────────────────
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        opencode
        isync
        syncthing
        btrfs-progs
        util-linux
        my-vscode
        mountArchive
        umountArchive
        syncthingArchive
      ];
    };
  };
}