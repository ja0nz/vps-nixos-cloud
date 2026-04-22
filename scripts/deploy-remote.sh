#!/usr/bin/env bash

# === 1. Input: Get and confirm target IP ===
while true; do
    # Only ask for IP if it's currently empty
    if [ -z "$REMOTE_IP4" ]; then
        read -p "🌐 Enter VPS Instance IPv4: " REMOTE_IP4
    fi

    echo "❓ Current Target IP: $REMOTE_IP4"
    read -p "   Confirm with 'y' OR enter a new IP to change it: " user_input

    # Case 1: User confirms with y/Y
    if [[ "$user_input" =~ ^[Yy]$ ]]; then
        break
    fi

    # Case 2: User entered something else (presumably a new IP)
    if [ -n "$user_input" ]; then
        REMOTE_IP4=$user_input
        echo "🔄 IP updated to $REMOTE_IP4. Checking again..."
    else
        # Case 3: User just hit enter without typing anything
        echo "⚠️  Please confirm with 'y' or provide a new address."
    fi
done

# === 2. Setup: Create temporary workspace ===
WS=$(mktemp -d)
trap 'rm -rf "$WS"' EXIT
KEY_PATH="$WS/id_ed25519"
EXTRA_FILES="$WS/extra"

# --- Extract host keys for nixos-anywhere ---
install -d -m755 "$EXTRA_FILES/persist/etc/ssh/mnt"
sops -d --extract '["ssh_host_ed25519_key"]' "$SECRETS" \
     > "$EXTRA_FILES/persist/etc/ssh/mnt/ssh_host_ed25519_key"
sops -d --extract '["ssh_host_ed25519_key_pub"]' "$SECRETS" \
     > "$EXTRA_FILES/persist/etc/ssh/mnt/ssh_host_ed25519_key.pub"
chmod 600 "$EXTRA_FILES/persist/etc/ssh/mnt/ssh_host_ed25519_key"

# --- Extract deployment key for SSH access ---
sops -d --extract '["id_ed25519"]' "$SECRETS" > "$KEY_PATH"
chmod 600 "$KEY_PATH"

# === 5. Probe: Determine if NixOS is already running ===
echo "🔍 Probing $REMOTE_IP4 for environment state..."

if ssh -i "$KEY_PATH" "$VIRT_USER@$REMOTE_IP4" "[ -e /run/current-system ]"; then
    # --- 6a. Update: Run nixos-rebuild switch (In-place) ---
    echo "✅ NixOS detected. Updating via nixos-rebuild..."

    # Set the SSH options for the duration of this command
    export NIX_SSHOPTS="-i $KEY_PATH"
    nixos-rebuild switch \
        --flake .#prod-remote \
        --target-host "$VIRT_USER@$REMOTE_IP4" \
        --build-host "$VIRT_USER@$REMOTE_IP4" \
        --sudo

else
    # --- 6b. Install: Run nixos-anywhere (Fresh VPS) ---
    echo "🐣 Fresh VPS detected. Initializing with nixos-anywhere..."
    nix run github:nix-community/nixos-anywhere -- \
        --flake .#prod-remote \
        --extra-files "$EXTRA_FILES" \
        --target-host "ubuntu@$REMOTE_IP4" \
        -i "$KEY_PATH" \
        --build-on remote
fi
