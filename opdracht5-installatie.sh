#!/usr/bin/env bash
# opdracht5-installatie.sh
# Bootstrap-script voor opdracht 5 — groep 99
# Installeert: neofetch, fail2ban, ufw, docker, vaultwarden, portainer

set -euo pipefail

info()  { echo "[INFO]  $*"; }
err()   { echo "[FOUT]  $*" >&2; exit 1; }

if [[ "$(id -u)" -ne 0 ]]; then
    info "Script heeft root-rechten nodig. Herstarten met sudo..."
    exec sudo bash "$0" "$@"
fi

REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~${REAL_USER}")

if ! command -v apt-get &>/dev/null; then
    err "Dit script verwacht een Debian-variant (apt-get niet gevonden)."
fi

# :: Statisch IP ophalen
VM_IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')
[[ -z "${VM_IP}" ]] && VM_IP=$(hostname -I | awk '{print $1}')
[[ -z "${VM_IP}" ]] && err "Kan het IP-adres van de VM niet bepalen."
info "IP-adres van de VM: ${VM_IP}"

# :: Variabelen
VW_COMPOSE_DIR="/opt/vaultwarden"
VW_DATA_DIR="${REAL_HOME}/.files-vaultwarden/data"

PT_COMPOSE_DIR="/opt/portainer"
PT_DATA_DIR="${REAL_HOME}/.files-portainer"

SSL_DIR="/opt/ssl"
SSL_CERT="${SSL_DIR}/cert.pem"
SSL_KEY="${SSL_DIR}/key.pem"

PORTAINER_PORT="9000"

# :: 1. Systeem bijwerken + basispakketten
info "Systeem bijwerken..."
apt-get update -qq
apt-get upgrade -y -qq

info "Basispakketten installeren: neofetch, fail2ban, ufw, curl, ca-certificates, gnupg..."
apt-get install -y -qq \
    neofetch \
    fail2ban \
    ufw \
    curl \
    ca-certificates \
    gnupg \
    lsb-release

# :: 2. fail2ban
info "fail2ban configureren..."
if [[ ! -f /etc/fail2ban/jail.local ]]; then
    cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
EOF
fi
systemctl enable --now fail2ban
info "fail2ban actief."

# :: 3. UFW
info "UFW configureren..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    comment 'SSH'
ufw allow 80/tcp    comment 'HTTP'
ufw allow 443/tcp   comment 'HTTPS - Vaultwarden'
ufw allow "${PORTAINER_PORT}/tcp" comment 'Portainer'
ufw --force enable
info "UFW actief. Toegestane poorten: 22, 80, 443, ${PORTAINER_PORT}."

# :: 4. Docker
if command -v docker &>/dev/null; then
    info "Docker is al geinstalleerd, overslaan."
else
    info "Docker installeren via officieel repository..."

    install -m 0755 -d /etc/apt/keyrings

    DISTRO_ID=$(. /etc/os-release && echo "$ID")
    case "${DISTRO_ID}" in
        ubuntu)
            REPO_URL="https://download.docker.com/linux/ubuntu"
            ;;
        debian)
            REPO_URL="https://download.docker.com/linux/debian"
            ;;
        *)
            # val terug op debian als veilige gok
            REPO_URL="https://download.docker.com/linux/debian"
            ;;
    esac

    curl -fsSL "${REPO_URL}/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] ${REPO_URL} \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list

    apt-get update -qq
    apt-get install -y -qq \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    systemctl enable --now docker
    info "Docker geinstalleerd en actief."
fi

# Gebruiker toevoegen aan docker-groep (geen sudo nodig voor docker)
if ! id -nG "${REAL_USER}" | grep -qw docker; then
    usermod -aG docker "${REAL_USER}"
    info "Gebruiker '${REAL_USER}' toegevoegd aan de docker-groep (herlogin vereist)."
fi

# :: 5. Self-signed certificaat
info "Self-signed certificaat aanmaken..."
mkdir -p "${SSL_DIR}"

if [[ ! -f "${SSL_CERT}" || ! -f "${SSL_KEY}" ]]; then
    openssl req -x509 -nodes -days 3650 \
        -newkey rsa:2048 \
        -keyout "${SSL_KEY}" \
        -out "${SSL_CERT}" \
        -subj "/C=BE/ST=Vlaanderen/L=Gent/O=Groep99/CN=vaultwarden.opdracht5.local" \
        -addext "subjectAltName=DNS:vaultwarden.opdracht5.local,DNS:portainer.opdracht5.local,IP:${VM_IP}"
    chmod 644 "${SSL_CERT}"
    chmod 600 "${SSL_KEY}"
    info "Certificaat aangemaakt in ${SSL_DIR}."
else
    info "Certificaat bestaat al, overslaan."
fi

# :: 6. Vaultwarden (HTTPS :443 via ROCKET_TLS)
info "Vaultwarden instellen..."
mkdir -p "${VW_COMPOSE_DIR}" "${VW_DATA_DIR}"
chown "${REAL_USER}:${REAL_USER}" "${VW_DATA_DIR}"

cat > "${VW_COMPOSE_DIR}/docker-compose.yml" <<EOF
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    environment:
      ROCKET_TLS: "{certs=/ssl/cert.pem,key=/ssl/key.pem}"
      ROCKET_PORT: "443"
    volumes:
      - ${VW_DATA_DIR}:/data
      - ${SSL_DIR}:/ssl:ro
    ports:
      - "443:443"
EOF

info "Vaultwarden-container starten..."
docker compose -f "${VW_COMPOSE_DIR}/docker-compose.yml" up -d
info "Vaultwarden draait op https://vaultwarden.opdracht5.local (poort 443)."

# :: 7. Portainer (HTTP :${PORTAINER_PORT})
info "Portainer instellen..."
mkdir -p "${PT_COMPOSE_DIR}" "${PT_DATA_DIR}"
chown "${REAL_USER}:${REAL_USER}" "${PT_DATA_DIR}"

cat > "${PT_COMPOSE_DIR}/docker-compose.yml" <<EOF
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ${PT_DATA_DIR}:/data
    ports:
      - "${PORTAINER_PORT}:9000"
EOF

info "Portainer-container starten..."
docker compose -f "${PT_COMPOSE_DIR}/docker-compose.yml" up -d
info "Portainer draait op http://portainer.opdracht5.local:${PORTAINER_PORT}."

# :: 8. /etc/hosts
info "/etc/hosts bijwerken..."
for HOSTNAME in vaultwarden.opdracht5.local portainer.opdracht5.local; do
    if ! grep -q "${HOSTNAME}" /etc/hosts; then
        echo "${VM_IP} ${HOSTNAME}" >> /etc/hosts
        info "  ${HOSTNAME} -> ${VM_IP} toegevoegd."
    else
        info "  ${HOSTNAME} staat al in /etc/hosts, overslaan."
    fi
done

# :: 9. Samenvatting
echo ""
echo "==========================================="
echo " Installatie voltooid"
echo "==========================================="
echo ""
echo " IP-adres:    ${VM_IP}"
echo ""
echo " Vaultwarden: https://vaultwarden.opdracht5.local"
echo " Portainer:   http://portainer.opdracht5.local:${PORTAINER_PORT}"
echo ""
echo " Firewall:    22 (SSH), 80 (HTTP), 443 (HTTPS), ${PORTAINER_PORT} (Portainer)"
echo " fail2ban:    actief (SSH)"
echo " Certificaat: ${SSL_CERT}"
echo ""
echo " Data:"
echo "   Vaultwarden: ${VW_DATA_DIR}"
echo "   Portainer:   ${PT_DATA_DIR}"
echo ""
echo " Vergeet niet:"
echo "   - Herlogin of 'newgrp docker' voor docker zonder sudo"
echo "   - Voeg op je client toe aan /etc/hosts (of DNS):"
echo "     ${VM_IP} vaultwarden.opdracht5.local portainer.opdracht5.local"
echo ""
echo "==========================================="
