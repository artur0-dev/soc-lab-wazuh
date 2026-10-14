# Arquitectura del laboratorio

## Topología de red

Cada máquina Linux tiene dos tarjetas de red: una en NAT
(`192.168.125.0/24`), solo para salir a internet e instalar paquetes,
y otra en la red interna del laboratorio (`192.168.58.0/24`), por
donde circula todo el tráfico relevante y los logs hacia Wazuh. Los
Windows siguen el mismo esquema con `Ethernet0` (NAT) y `Ethernet1`
(laboratorio).

```
                        Internet
                           │
                 NAT (192.168.125.0/24)
                           │
┌──────────────────────────┴───────────────────────────────┐
│          Red del laboratorio  192.168.58.0/24             │
│                                                            │
│  Kali ──────────► Ubuntu corp / Win Server / Win 11       │
│  .134               (.140)        (.137)       (.138)     │
│  (atacante)             │             │            │      │
│                         └─────────────┴────────────┘      │
│                                │ logs (1514/1515 tcp)      │
│  Sensor Suricata ──────────────┤                           │
│  .141 (eve.json)               ▼                          │
│                          Ubuntu SOC .136                   │
│                Wazuh Manager + Indexer + Dashboard         │
└─────────────────────────────────────────────────────────────┘
```

## Interfaces de red por máquina

| Máquina | Interfaz laboratorio | IP laboratorio | Interfaz NAT | IP NAT |
|---|---|---|---|---|
| Ubuntu SOC | ens37 | 192.168.58.136/24 | ens33 | 192.168.125.138 |
| Windows Server | Ethernet1 | 192.168.58.137/24 | Ethernet0 | 192.168.125.189 |
| Windows 11 | Ethernet1 | 192.168.58.138/24 | Ethernet0 | 192.168.125.188 |
| Ubuntu corporativo | ens37 | 192.168.58.140/24 | ens33 | 192.168.125.191 |
| Sensor Suricata | ens37 (promiscua) | 192.168.58.141/24 | ens33 | 192.168.125.192 |
| Kali Linux | eth1 | 192.168.58.134/24 | eth0 | (sin usar) |

Capturas de `ip a` / `ipconfig` de cada máquina en
`../evidence/screenshots/infra-network-*.png`.

## Flujo de datos

1. **Sysmon** (Windows Server y Windows 11) genera telemetría de
   procesos, red y ficheros en el canal
   `Microsoft-Windows-Sysmon/Operational`.
2. El **agente Wazuh** de cada máquina (Windows y Linux) lee sus
   fuentes de log — Sysmon, `auth.log`, Windows Security, o
   `eve.json` de Suricata — y las envía cifradas por el puerto
   **1514/tcp** al Manager.
3. El **agente del sensor Suricata** lee `/var/log/suricata/eve.json`
   y envía las alertas de red al mismo Manager.
4. El **Wazuh Manager** (contenedor Docker en el Ubuntu SOC) aplica
   el motor de reglas (`ossec-analysisd`) y genera alertas.
5. El **Wazuh Indexer** almacena las alertas y eventos.
6. El **Wazuh Dashboard** (puerto 443) permite consultarlos mediante
   Discover (Threat Hunting → Events) y el módulo de Endpoints.

## Estado de agentes

Ver `../evidence/screenshots/infra-endpoints-summary.png` para el
listado completo de agentes activos en el Manager.
