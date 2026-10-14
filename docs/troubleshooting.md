# Problemas encontrados y cómo se resolvieron

Registro de los fallos reales surgidos al montar el laboratorio.
Se documentan a propósito: reflejan el proceso de diagnóstico, no
solo el resultado final.

## 1. El cliente no encuentra el dominio aunque hace ping al DC

**Síntoma:**

```
nltest /dsgetdc:soclab.local
Error al obtener el nombre DC: Status = 1355 0x54b ERROR_NO_SUCH_DOMAIN
```

El ping al nombre del servidor funcionaba, pero resolvía a una IP
que **no era la del controlador de dominio** (sufijo `.localdomain`,
señal de que el cliente usaba otro DNS, no el del DC).

**Causa:** el cliente no tenía configurado el DNS del dominio.

**Solución:**

```powershell
Set-DnsClientServerAddress -InterfaceAlias "Ethernet1" -ServerAddresses 192.168.58.137
ipconfig /flushdns
nltest /dsgetdc:soclab.local
```

## 2. Doble ruta por defecto en Ubuntu (sin salida a internet)

**Síntoma:** `ping 8.8.8.8` fallaba en una VM con dos tarjetas de
red, a pesar de tener conectividad con el resto del laboratorio.

**Causa:** la interfaz de la red del laboratorio tenía definido un
`gateway` en el netplan, generando una segunda ruta por defecto que
ganaba por tener menor métrica. El tráfico a internet salía por un
gateway que no existía en esa red.

**Solución:** eliminar el bloque `routes` de la interfaz del
laboratorio, dejando solo el gateway de la interfaz NAT.

```yaml
# INCORRECTO: provoca doble ruta por defecto
ens37:
  dhcp4: false
  addresses: [192.168.58.140/24]
  routes:
    - to: default
      via: 192.168.58.1

# CORRECTO
ens37:
  dhcp4: false
  addresses: [192.168.58.140/24]
```

```bash
sudo netplan apply
ip route   # debe mostrar una única línea "default via ..."
```

## 3. `suricata-update` falla por YAML inválido

**Síntoma:**

```
<Error> -- Failed to parse configuration file at line 41: did not find expected key
```

**Causas encontradas** (en este orden, cada una reveló la siguiente
al corregirla):

1. La clave `address-groups:` había perdido su sangría al editar el
   bloque `HOME_NET`.
2. Faltaban las dos líneas de cabecera obligatorias de Suricata 7:
   ```
   %YAML 1.1
   ---
   ```
   sin ellas, el error cambia a:
   ```
   The configuration file must begin with the following two lines: %YAML 1.1 and ---
   ```

**Lección:** en YAML, cualquier edición manual de un archivo grande
con `nano` es propensa a desalinear la sangría. Validar siempre con
`suricata -T` después de cada cambio, no solo al final.

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml -v
```

## 4. Suricata no genera alertas (o pierde paquetes) en VMware

**Causa:** el offloading de red de la tarjeta virtual (checksum
offloading, GRO/LRO/TSO/GSO) hace que los paquetes lleguen con
checksums "incorrectos" a nivel de kernel, y Suricata los descarta.

**Solución:**

```yaml
af-packet:
  - interface: ens37
    checksum-checks: no
```

```bash
sudo ethtool -K ens37 gro off lro off tso off gso off
```

Y mantener el modo promiscuo activo tras reiniciar con una unidad
`systemd` (`ip link set ... promisc on` no persiste por sí solo).

## 5. dpkg error 127 al instalar el agente Wazuh

**Síntoma:**

```
dpkg: error al procesar el archivo ./wazuh-agent.deb (--install):
 el subproceso nuevo paquete wazuh-agent script pre-installation devolvió el código de salida de error 127
```

**Causa:** el código 127 indica "comando no encontrado" dentro del
script de preinstalación del paquete, generalmente por una
instalación anterior cancelada a medias, o por faltar utilidades
básicas del sistema.

**Solución:**

```bash
sudo dpkg --configure -a
sudo apt --fix-broken install -y
sudo dpkg --purge wazuh-agent
sudo rm -rf /var/ossec
sudo apt install -y curl gnupg apt-transport-https procps adduser passwd lsb-release
```

Y reinstalar. Si persiste, usar el repositorio apt oficial en lugar
del `.deb` suelto (resuelve dependencias automáticamente).

## 6. Edición de `ossec.conf` denegada por permisos (Windows)

**Causa:** `C:\Program Files (x86)\ossec-agent\` está protegida; el
Bloc de notas abierto sin privilegios no puede guardar ahí.

**Solución:** abrir el editor **como administrador**, o editar desde
una consola ya elevada:

```powershell
notepad "C:\Program Files (x86)\ossec-agent\ossec.conf"
```

## 7. `$env:TEMP` no se expande en CMD

**Síntoma:** `msiexec.exe /i $env:TEMP\wazuh-agent.msi` fallaba de
forma silenciosa, y el servicio aparecía como "ya iniciado" con una
configuración incorrecta.

**Causa:** `$env:TEMP` es sintaxis de PowerShell; en CMD se pasa como
texto literal.

**Solución:** ejecutar siempre estos comandos desde **PowerShell**,
nunca desde `cmd.exe`.

## 8. Una regla propia no dispara: colgaba del evento Sysmon equivocado

**Síntoma:** la regla de ransomware (UC05) filtraba por la extensión
`.locked`, pero no generaba ninguna alerta aunque Sysmon y el agente
funcionaban.

**Causa:** usaba `<if_sid>61603</if_sid>`. En el ruleset oficial
(`0595-win-sysmon_rules.xml`):

| Regla | Evento Sysmon |
|---|---|
| 61603 | Event ID **1**: creación de proceso |
| 61613 | Event ID **11**: creación de archivo |

`targetFilename` solo existe en el Event 11, así que la regla nunca
podía cumplirse y tampoco daba error.

**Solución:** `<if_sid>61613</if_sid>`. Validar y reiniciar:

```bash
docker exec single-node-wazuh.manager-1 /var/ossec/bin/wazuh-analysisd -t
docker restart single-node-wazuh.manager-1
```

**Método de diagnóstico** (de fuera hacia dentro, descartando capas):
1. ¿Sysmon registra el evento? `Get-WinEvent -LogName Microsoft-Windows-Sysmon/Operational`
2. ¿Llega al manager? Activar `logall_json` y buscar en `archives.json`.
3. ¿Qué regla hay cargada de verdad? `grep` en `local_rules.xml` del contenedor.

## 9. Sysmon no registra los archivos que interesan

**Causa:** la configuración de SwiftOnSecurity solo registra
`FileCreate` en rutas y extensiones concretas. Los `.locked` creados
en `Documents` no estaban incluidos.

**Solución:** añadir la extensión a `FileCreate` y recargar sin
reinstalar (como administrador):

```powershell
C:\Sysmon\Sysmon64.exe -c C:\Sysmon\sysmonconfig.xml
```

Ver [`configs/sysmon/sysmon-filecreate-ransomware.xml`](../configs/sysmon/sysmon-filecreate-ransomware.xml).
Nota: leer el canal `Microsoft-Windows-Sysmon/Operational` requiere
una consola de administrador; el agente Wazuh no tiene ese problema
porque corre como SYSTEM.

## 10. La consulta de comprobación daba 0 resultados aunque los datos existían

**Causa:** `match_phrase: "locked"` sobre `data.win.eventdata.targetFilename`,
un campo `keyword`: busca el valor exacto `locked`, no la ruta completa.
Un resultado vacío no probaba nada.

**Solución:** buscar por `rule.id` o por comodín:

```json
{"wildcard": {"data.win.eventdata.targetFilename": "*.locked"}}
```

