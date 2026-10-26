sudo nix run github:nix-community/disko -- --flake .#archive --argstr device /dev/loop1 --mode format

ARCHIVE_MOUNT_POINT=/mnt/archive ARCHIVE_DEVICE=/dev/loop0p1 nix develop --command zsh