# Opdracht 5

## Introduction

Omwille van de verscheidenheid aan besturingssystemen en hypervisors, die trouwens al deels geconfigureerd zijn, kozen we voor een bootstrap script dat wordt uitgevoerd binnenin de vm.  

## BASIS 

### Assumptions

- Een gekend statisch ip
- debian variant: debian, ubuntu, ..
- account heeft sudo privileges

### Wat wordt geïnstalleerd

- [ ] neofetch
- [ ] fail2ban
- [ ] ufw
- [ ] docker
- [ ] vaultwarden (docker compose)
- [ ] portainer (docker compose)
- [ ] self-signed certificate
- [ ] rocket (ROCKET_TLS="{certs=/ssl/cert.pem,key=/ssl/key.pem}")

- [ ] beide docker compose containers starten automatisch op met het system

### Installatie

- log aan op je VM met ssh
- zet deze variabele, met jouw wachtwoord uiteraard
```bash
export VM_PASSWORD=osboxes.org
```
- zorg dat curl is geïnstalleerd op het systeem
```bash
sudo apt update && sudo apt install curl -y
```
- installeer de stack met dit commando
```bash
curl https://github.com/mtdig/opdracht-5/opdracht5-installatie.sh | bash
```

### Post-Installatie

<ip> vaultwarden.opdracht5.local
<ip> portainer.opdracht5.local


Installeer client / browser extensie

### Profit

## Uitbreiding

- [ ] cloud
- [ ] provisioning met ansible (we vergeten terraform, reasons)
- [ ] minetest (FOSS Minecraft clone)
- [ ] groep99 LAN/WAN-party

### Prep / AWS Education vs Azure

Budget bepaalt.

- [ ] az vs aws cli
- [ ] python virtual environment met [ansible](https://docs.ansible.com/#developers), [uv](https://docs.astral.sh/uv/) als package/project manager
- [ ] ...

