sudo nix run github:nix-community/disko -- --flake .#archive --argstr device /dev/loop0 --mode format

ARCHIVE_MOUNT_POINT=/mnt/archive ARCHIVE_DEVICE=/dev/loop0p1 nix develop --command zsh

dd if=/dev/urandom of=./mock.img bs=1G count=1
sudo losetup -fP ./mock.img
losetup -a