# Разметка диска
sudo nix run github:nix-community/disko -- --flake .#archive --arg device '"/dev/sdX"'