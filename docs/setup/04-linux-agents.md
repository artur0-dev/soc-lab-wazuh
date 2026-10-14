# 4. Servidor Linux corporativo

**Máquina:** Ubuntu corporativo — 192.168.58.140 — 2 GB RAM

## Red (netplan)

Dos tarjetas: `ens33` por DHCP (NAT) y `ens37` con IP fija en la red
del laboratorio, **sin gateway** (ver plantilla completa en
`../../configs/netplan/ubuntu-corp.yaml`):

```yaml
network:
  version: 2
  ethernets:
    ens33:
      dhcp4: true
    ens37:
      dhcp4: false
      addresses:
        - 192.168.58.140/24
```

```bash
sudo netplan apply
ip route        # debe haber una única ruta por defecto, por ens33
ping -c 3 8.8.8.8
```

## Servicios base

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y openssh-server apache2 open-vm-tools
sudo systemctl enable --now ssh apache2 open-vm-tools
```

## Agente Wazuh

Instalación vía paquete `.deb` directo:

```bash
curl -fLO https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.14.7-1_amd64.deb
sudo WAZUH_MANAGER='192.168.58.136' WAZUH_AGENT_NAME='ubuntu-corp' dpkg -i ./wazuh-agent_4.14.7-1_amd64.deb
sudo systemctl daemon-reload
sudo systemctl enable --now wazuh-agent
```

Alternativa más robusta, vía repositorio apt (resuelve dependencias
automáticamente y evita el típico error de dpkg):

```bash
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | sudo gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
sudo chmod 644 /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | sudo tee /etc/apt/sources.list.d/wazuh.list
sudo apt update
sudo WAZUH_MANAGER='192.168.58.136' WAZUH_AGENT_NAME='ubuntu-corp' apt install -y wazuh-agent=4.14.7-1
```

## Verificación

```bash
sudo systemctl status wazuh-agent
sudo tail -n 20 /var/ossec/logs/ossec.log
```

Debe aparecer como **Active** en el Dashboard
(`../../evidence/screenshots/infra-endpoints-summary.png`).
