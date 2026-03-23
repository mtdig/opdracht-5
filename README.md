# Opdracht 5

## Introduction

Omwille van de verscheidenheid aan besturingssystemen en hypervisors, die trouwens al deels geconfigureerd zijn, kozen we voor een bootstrap script dat wordt uitgevoerd binnenin de vm.  

## NOTE

Alvorens dit uit te voeren, nemen we beter eerst een snapshot.


## BASIS 

### Assumptions

- Een gekend statisch ip
- debian variant: debian, ubuntu, ..
- account heeft sudo privileges

### Wat wordt geïnstalleerd

- [x] neofetch
- [x] fail2ban (SSH jail, bantime 1h)
- [x] ufw (poorten: 22, 80, 443, 9000)
- [x] docker (officieel repository + compose plugin)
- [x] vaultwarden (docker compose, HTTPS :443 via ROCKET_TLS)
- [x] portainer (docker compose, HTTP :9000)
- [x] self-signed certificaat (/opt/ssl/)

- [x] beide containers starten automatisch op met het systeem (`restart: unless-stopped`)

### Installatie

- log aan op je VM met SSH
- zorg dat curl is geinstalleerd op het systeem
```bash
sudo apt update && sudo apt install curl -y
```
- installeer de stack met dit commando (sudo-wachtwoord wordt gevraagd)
```bash
curl -fsSL https://raw.githubusercontent.com/mtdig/opdracht-5/main/opdracht5-installatie.sh | bash
```

### Post-Installatie

Voeg toe aan `/etc/hosts` op je **client** (niet de VM):
```
<ip> vaultwarden.opdracht5.local portainer.opdracht5.local
```

Open in de browser:
- Vaultwarden: `https://vaultwarden.opdracht5.local` (self-signed cert accepteren)
- Portainer: `http://portainer.opdracht5.local:9000`

Installeer de Bitwarden client of browser-extensie en verbind met je Vaultwarden-URL.

### Paden

| Wat | Pad |
|-----|-----|
| Vaultwarden compose | `/opt/vaultwarden/docker-compose.yml` |
| Portainer compose | `/opt/portainer/docker-compose.yml` |
| Vaultwarden data | `~/.files-vaultwarden/data` |
| Portainer data | `~/.files-portainer` |
| Certificaat | `/opt/ssl/cert.pem`, `/opt/ssl/key.pem` |

### Profit

## Uitbreiding

- [ ] cloud
- [ ] provisioning met ansible (we vergeten terraform, reasons)
- [ ] let's encrypt certificates
- [ ] apache reverse proxy
- [ ] minetest (FOSS Minecraft clone)
- [ ] groep99 LAN/WAN-party

### Prep / AWS Education vs Azure

Budget bepaalt.

- [ ] az vs aws cli
- [ ] python virtual environment met [ansible](https://docs.ansible.com/#developers), [uv](https://docs.astral.sh/uv/) als package/project manager
- [ ] ...

