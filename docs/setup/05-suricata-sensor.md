# 5. Sensor Suricata

**Máquina:** vmsensor — 192.168.58.141 — 2 GB RAM

VM independiente con Ubuntu Server 24.04, dos tarjetas de red (NAT +
laboratorio), dedicada solo a Suricata y al agente Wazuh.

## Instalación

```bash
sudo add-apt-repository ppa:oisf/suricata-stable -y
sudo apt update && sudo apt install -y suricata
```

## Configuración de red del propio Suricata

En `/etc/suricata/suricata.yaml` (ver plantilla completa en
`../../configs/suricata/suricata.yaml.example`):

```yaml
vars:
  address-groups:
    HOME_NET: "[192.168.58.0/24]"
    EXTERNAL_NET: "!$HOME_NET"

af-packet:
  - interface: ens37
    cluster-id: 99
    cluster-type: cluster_flow
    defrag: yes
    checksum-checks: no   # evita descartes por offloading en VMware
```

Desactivar offloading de la tarjeta y fijar el modo promiscuo de
forma persistente (unidad systemd, ver
`../troubleshooting.md` para el detalle):

```bash
sudo ethtool -K ens37 gro off lro off tso off gso off
sudo ip link set ens37 promisc on
```

## Reglas

```bash
sudo suricata-update
```

Regla propia de prueba en
`../../detections/suricata-local.rules`:

```
alert icmp any any -> $HOME_NET any (msg:"LAB ICMP detectado"; sid:1000001; rev:1;)
```

## Validar y arrancar

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml -v
sudo systemctl enable --now suricata
```

## Agente Wazuh leyendo eve.json

```bash
curl -fLO https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.14.7-1_amd64.deb
sudo WAZUH_MANAGER='192.168.58.136' WAZUH_AGENT_NAME='suricata-sensor' dpkg -i ./wazuh-agent_4.14.7-1_amd64.deb
sudo systemctl enable --now wazuh-agent
```

En `/var/ossec/etc/ossec.conf` (plantilla en
`../../configs/wazuh/ossec-suricata.xml`):

```xml
<localfile>
  <log_format>json</log_format>
  <location>/var/log/suricata/eve.json</location>
</localfile>
```

```bash
sudo systemctl restart wazuh-agent
```

## Verificación

```bash
sudo tail -f /var/log/suricata/fast.log
```

Prueba real: escaneo con Nmap desde el Kali detectado como
`ET SCAN Possible Nmap User-Agent Observed` — ver
[UC02](../use-cases/uc02-port-scan.md).

## Limitación conocida

En un switch virtual tipo VMnet, el sensor en modo promiscuo puede
ver solo su propio tráfico y el de difusión (broadcast), no el
tráfico entre otras dos VMs. Si ocurre, las pruebas se dirigen contra
la IP del propio sensor, o se instala Suricata también en la máquina
objetivo. Detalle en `../troubleshooting.md`.
