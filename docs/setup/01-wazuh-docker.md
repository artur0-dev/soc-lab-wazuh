# 1. Wazuh Manager + Indexer + Dashboard (Ubuntu SOC)

**Máquina:** Ubuntu SOC — 192.168.58.136 — 8 GB RAM

Despliegue mediante el `docker-compose` oficial de Wazuh
(`single-node`), versión **4.14.7**.

## Contenedores desplegados

```
sudo docker ps
```

```
CONTAINER ID   IMAGE                          NAMES
744b043dcf7a   wazuh/wazuh-dashboard:4.14.7   single-node-wazuh.dashboard-1
5333b024782d   wazuh/wazuh-manager:4.14.7     single-node-wazuh.manager-1
b40b41462129   wazuh/wazuh-indexer:4.14.7     single-node-wazuh.indexer-1
```

Puertos publicados:

| Puerto | Servicio |
|---|---|
| 443 → 5601 | Dashboard (HTTPS) |
| 1514-1515/tcp | Comunicación agente ↔ Manager |
| 514/udp | Syslog |
| 55000/tcp | API de Wazuh |
| 9200/tcp | Indexer |

## Acceso al Dashboard

```
https://192.168.58.136
```

Certificado autofirmado (aceptar aviso del navegador).

## Red

La VM tiene dos tarjetas: `ens33` (NAT, DHCP) y `ens37`
(`192.168.58.136/24`, red del laboratorio). **Importante:** solo debe
existir una ruta por defecto (por la tarjeta NAT); si la interfaz del
laboratorio también define gateway, se pierde la salida a internet
(ver `../troubleshooting.md`).

## Comprobaciones

```bash
sudo docker ps
sudo docker logs single-node-wazuh.manager-1 --tail 30
sudo docker exec single-node-wazuh.manager-1 /var/ossec/bin/agent_control -l
```

## Mantenimiento

Asegurar que los contenedores se levanten solos tras un reinicio del
host (política `restart: always`/`unless-stopped` en el
`docker-compose.yml`, y Docker habilitado):

```bash
sudo systemctl enable docker
```
