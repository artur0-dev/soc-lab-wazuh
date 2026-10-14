# SOC Lab: Wazuh + Suricata + Sysmon + Active Directory

Laboratorio de monitorización y detección que simula un entorno
corporativo pequeño: dominio Windows con Active Directory, servidores
Linux, un sensor de red con Suricata y un SIEM Wazuh centralizando
toda la telemetría. Construido en VMware con máquinas virtuales
aisladas en una red interna.

> Entorno de laboratorio con fines de aprendizaje y práctica de
> detección (blue team). Todo el tráfico de ataque se generó contra
> máquinas propias y aisladas de internet.

## Arquitectura

```
                        Internet
                           │
                 NAT (192.168.125.0/24)
       (solo para instalar paquetes, 2ª tarjeta de las VMs Linux)
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

Diagrama completo y detalle de interfaces de red en
[`docs/architecture.md`](docs/architecture.md).

## Inventario de máquinas

| Máquina | IP (lab) | SO | RAM | Rol | Software instalado |
|---|---|---|---|---|---|
| Ubuntu SOC | 192.168.58.136 | Ubuntu | 8 GB | SIEM | Docker, Wazuh Manager / Indexer / Dashboard 4.14.7 |
| Windows Server | 192.168.58.137 | Windows Server 2025 | 4 GB | Controlador de dominio | AD DS, DNS (`soclab.local`), Sysmon, agente Wazuh |
| Windows 11 | 192.168.58.138 | Windows 11 Pro | 5-6 GB | Estación de trabajo | Unido al dominio, Sysmon, agente Wazuh |
| Ubuntu corporativo | 192.168.58.140 | Ubuntu Server 24.04 | 2 GB | Servidor Linux | SSH, Apache, agente Wazuh |
| Sensor Suricata | 192.168.58.141 | Ubuntu Server 24.04 | 2 GB | IDS de red | Suricata 7.0.3, agente Wazuh |
| Kali Linux | 192.168.58.134 | Kali Linux | 3-4 GB | Atacante | nmap, hydra |

## Tecnologías

Wazuh 4.14.7 · Suricata 7.0.3 · Sysmon (SwiftOnSecurity config) ·
Active Directory / DNS · Docker · VMware Workstation · Ubuntu Server
24.04 · Windows Server 2025 · Kali Linux

## Casos de uso de detección

| ID | Escenario | Técnica MITRE ATT&CK | Fuente de detección |
|----|-----------|----------------------|----------------------|
| [UC01](docs/use-cases/uc01-ssh-bruteforce.md) | Fuerza bruta SSH contra servidor Linux | T1110 – Brute Force | Agente Wazuh (`sshd`), regla 5760 |
| [UC02](docs/use-cases/uc02-port-scan.md) | Escaneo de puertos con Nmap | T1046 – Network Service Discovery | Suricata (ET SCAN), regla 86601 |
| [UC03](docs/use-cases/uc03-ad-logon-failure.md) | Intentos de autenticación fallidos en el DC | T1110.001 – Password Guessing | Agente Wazuh (Windows Security), regla 60122 |
| [UC04](docs/use-cases/uc04-powershell-discovery.md) | Actividad de descubrimiento y PowerShell sospechosa | T1059.001 – PowerShell / T1082 / T1083 | Sysmon + reglas Wazuh 92031-92205 |
| [UC05](docs/use-cases/uc05-ransomware-simulation.md) | Simulación de ransomware en estación de trabajo (cifrado masivo a `.locked`) | T1486 – Data Encrypted for Impact | Sysmon (Event 11) + regla propia 100111 |

Cada caso incluye el comando de ataque ejecutado, la captura de la
alerta generada en el Dashboard y una breve explicación de por qué se
detecta.

## Despliegue paso a paso

La guía completa de cómo se montó cada pieza está en `docs/setup/`:

1. [Wazuh Manager / Indexer / Dashboard en Docker](docs/setup/01-wazuh-docker.md)
2. [Active Directory y DNS en Windows Server](docs/setup/02-active-directory.md)
3. [Sysmon y agente Wazuh en los equipos Windows](docs/setup/03-sysmon-agents-windows.md)
4. [Agentes Wazuh en Linux (Ubuntu corporativo)](docs/setup/04-linux-agents.md)
5. [Sensor Suricata](docs/setup/05-suricata-sensor.md)

## Reglas propias

El simulador de UC05 está en [`scripts/`](scripts). En [`detections/`](detections) se incluyen las reglas personalizadas
usadas en el laboratorio:

- `local_rules.xml`: reglas Wazuh propias (reducción de ruido SCA, correlación de fuerza bruta en AD y detección de ransomware, regla 100111).
- `suricata-local.rules`: regla Suricata de prueba (`LAB ICMP detectado`).

## Problemas encontrados y solución

Un resumen de los fallos reales que surgieron al montar el laboratorio
(DNS del dominio, doble ruta por defecto, YAML roto de Suricata,
checksums de red en VMware, dpkg bloqueado, y una regla de ransomware
que no disparaba por colgar del evento Sysmon equivocado) está documentado en
[`docs/troubleshooting.md`](docs/troubleshooting.md). Se incluye a
propósito porque refleja el proceso real de diagnóstico, no solo el
resultado final.

## Qué no incluye este repositorio

No se suben las máquinas virtuales (discos, SO con licencia) ni
credenciales reales. Los archivos de configuración son plantillas
(`*.example`) con los valores sensibles sustituidos por
`CHANGE_ME`. Ver [`.gitignore`](.gitignore).

## Próximos pasos

- Validar la regla de correlación `100110` de UC05 (ver el apartado
  "Mejora pendiente" del caso de uso) y automatizar la contención con
  Active Response.
- Añadir reglas de correlación propias para detectar la cadena
  completa reconocimiento → explotación → persistencia.
- Configurar Active Response en Wazuh (bloqueo automático de IP tras
  fuerza bruta SSH).
- Añadir Samba/FTP en el Ubuntu corporativo para ampliar superficie.
- Resolver la visibilidad de tráfico este-oeste del sensor Suricata
  en el switch virtual (ver troubleshooting).
