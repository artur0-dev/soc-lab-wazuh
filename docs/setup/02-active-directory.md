# 2. Active Directory y DNS (Windows Server)

**Máquina:** Windows Server 2025 — 192.168.58.137 — 4 GB RAM
**Dominio:** `soclab.local`

## Problema típico al unir clientes al dominio

Si un cliente hace ping al nombre del servidor pero `nltest` no
encuentra el dominio:

```
nltest /dsgetdc:soclab.local
Error al obtener el nombre DC: Status = 1355 0x54b ERROR_NO_SUCH_DOMAIN
```

La causa casi siempre es que el cliente **no usa el DNS del
controlador de dominio**. Unirse al dominio exige resolver los
registros SRV (`_ldap._tcp.dc._msdcs.soclab.local`), que solo existen
en el DNS del propio DC.

## Configurar el DNS del cliente

```powershell
Get-NetAdapter
Set-DnsClientServerAddress -InterfaceAlias "Ethernet1" -ServerAddresses 192.168.58.137
ipconfig /flushdns
```

## Verificación

```powershell
nslookup soclab.local
nslookup -type=SRV _ldap._tcp.dc._msdcs.soclab.local
nltest /dsgetdc:soclab.local
```

Debe devolver `192.168.58.137` y los datos del controlador de
dominio.

## Unión al dominio

Configuración → Cuentas → Acceso a trabajo o escuela, o:

```
sysdm.cpl → Cambiar → Dominio → soclab.local
```

## Auditoría recomendada

Para que aparezcan eventos de logon/logoff y gestión de cuentas
(4624, 4625, 4720, 4728...), activar por GPO:

- Audit Logon Events
- Audit Account Management
- Audit Directory Service Access

El canal `Security` de Windows ya lo recoge el agente Wazuh por
defecto, sin configuración adicional.
