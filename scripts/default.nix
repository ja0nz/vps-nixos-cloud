{
  pkgs,
}:
let
  sopsExe = pkgs.lib.getExe pkgs.sops;
  cloudflaredExe = pkgs.lib.getExe pkgs.cloudflared;
  ncExe = pkgs.lib.getExe' pkgs.netcat-openbsd "nc";
  inherit (pkgs) bash;
  mkScript =
    name: description: text:
    let
      pkg = pkgs.writeShellScriptBin name ''
        #!${bash}/bin/bash
        set -euo pipefail
        ${text}
      '';
    in
    pkg // { meta.description = description; };

  extractKey = ''
    KEY_PATH=$(mktemp)
    trap 'rm -f "$KEY_PATH"' EXIT
    chmod 600 "$KEY_PATH"
    ${sopsExe} -d --extract '["id_ed25519"]' "$SECRETS" > "$KEY_PATH"
  '';
in
{
  deploy-vm = mkScript "deploy-vm" "Deploy/Update a local development VM" (
    builtins.readFile ./deploy-vm.sh
  );
  deploy-remote = mkScript "deploy-remote" "Deploy/Update to production VPS → prompt or $REMOTE_IP4" (
    builtins.readFile ./deploy-remote.sh
  );

  ssh-local = mkScript "ssh-local" "SSH into local VM on port $DEV_SSH_PORT" ''
    : "''${DEV_SSH_PORT:?Need to set DEV_SSH_PORT}"
    : "''${SECRETS:?Need to set SECRETS}"
    : "''${VIRT_USER:?Need to set VIRT_USER}"

    echo "Waiting for local VM to accept connections..."
    until ${ncExe} -z localhost "$DEV_SSH_PORT"; do sleep 1; done

    ${extractKey}

    ssh \
      -o IdentitiesOnly=yes \
      -o UserKnownHostsFile=/dev/null \
      -o StrictHostKeyChecking=no \
      -p "$DEV_SSH_PORT" \
      -i "$KEY_PATH" \
      "$VIRT_USER@localhost"
  '';

  ssh-remote = mkScript "ssh-remote" "SSH into remote VPS → prompt or $REMOTE_IP4" ''
    : "''${SECRETS:?Need to set SECRETS}"
    : "''${VIRT_USER:?Need to set VIRT_USER}"

    while true; do
      if [ -z "''${REMOTE_IP4:-}" ]; then
        read -rp "🌐 Enter VPS Instance IPv4: " REMOTE_IP4
      fi
      read -rp "❓ Target IP is $REMOTE_IP4. Is this correct? (y/n): " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        break
      else
        unset REMOTE_IP4
        echo "🔄 Let's try that again..."
      fi
    done

    echo "Waiting for remote VM to accept connections..."
    until ${ncExe} -z "$REMOTE_IP4" 22; do sleep 1; done

    ${extractKey}

    ssh \
      -o IdentitiesOnly=yes \
      -i "$KEY_PATH" \
      "$VIRT_USER@$REMOTE_IP4"
  '';

  cf-add-dns = mkScript "cf-add-dns" "Add a Cloudflare DNS record → $CF_TUNNEL" ''
    : "''${CF_TUNNEL:?Need to set CF_TUNNEL}"
    : "''${DOMAIN:?Need to set DOMAIN}"

    read -rp "Enter subdomain to create (e.g., 'pangolin'): " SUB
    if [ -z "$SUB" ]; then
      echo "❌ Subdomain cannot be empty."
      exit 1
    fi

    FULL_HOST="$SUB.$DOMAIN"
    echo "→ Adding DNS record for $FULL_HOST"

    if ${cloudflaredExe} tunnel route dns "$CF_TUNNEL" "$FULL_HOST"; then
      echo "✅ DNS record created: $FULL_HOST"
    else
      echo "⚠️  DNS record may already exist for $FULL_HOST"
    fi
  '';
}
