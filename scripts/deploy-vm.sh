#!/usr/bin/env bash

# === Check if the VM is already running by probing the SSH port ===
if ! nc -z localhost "$DEV_SSH_PORT" 2>/dev/null; then
    echo "🌐 SSH port $DEV_SSH_PORT is closed. Starting a new VM..."

    SSH_KEY_DIR="$FLAKE_ROOT/.dev-host-key"
    SSH_HOST_KEY="$SSH_KEY_DIR/ssh_host_ed25519_key"

    # Create directory if it doesn't exist
    mkdir -p "$SSH_KEY_DIR"

    # Extract Private Key
    sops -d --extract '["ssh_host_ed25519_key"]' "$SECRETS" | \
        tee "$SSH_HOST_KEY" > /dev/null
    chmod 600 "$SSH_HOST_KEY"

    nix run .#dev-local
else
    echo "✅ VM is already running on port $DEV_SSH_PORT. Switching configuration..."

    # --- Original switch-vm logic ---
    # Build the VM configuration on the host
    echo "🔨 Building VM configuration..."
    TARGET_PATH=$(nix build --no-substitute .#nixosConfigurations.dev-local.config.system.build.toplevel --print-out-paths)

    if [ -z "$TARGET_PATH" ]; then
        echo "❌ Build failed"
        exit 1
    fi

    echo "🚀 Switching running VM to: $TARGET_PATH"

    # Extracting the remote SSH key with sops
    KEY_PATH=$(mktemp)
    trap 'rm -f "$KEY_PATH"' EXIT
    chmod 600 "$KEY_PATH"
    sops -d --extract '["id_ed25519"]' "$SECRETS" > "$KEY_PATH"

    export NIX_SSHOPTS="-o IdentitiesOnly=yes -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $DEV_SSH_PORT -i $KEY_PATH"
    # Find the HM generation path referenced by the service and copy its closure
    HM_GEN_PATH=$(grep -oP '/nix/store/\S+-home-manager-generation' \
        "$TARGET_PATH/etc/systemd/system/home-manager-containers.service" | head -1)
    if [ -z "$HM_GEN_PATH" ]; then
        echo "⚠️  No HM generation found in service file, skipping copy"
    else
        echo "📦 Copying HM generation to remote: $HM_GEN_PATH"
        nix copy --no-substitute --to "ssh://$VIRT_USER@localhost" "$HM_GEN_PATH"
    fi

    # Run the switch command inside the VM via SSH
    ssh $NIX_SSHOPTS $VIRT_USER@localhost "sudo $TARGET_PATH/bin/switch-to-configuration switch"
fi
