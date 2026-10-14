# 3. Sysmon y agente Wazuh (Windows Server y Windows 11)

**Máquinas:** win-server-2025 (192.168.58.137), win11-pc1
(192.168.58.138)

## Instalar Sysmon

PowerShell como administrador, en cada equipo:

```powershell
mkdir C:\Sysmon
cd C:\Sysmon
Invoke-WebRequest https://download.sysinternals.com/files/Sysmon.zip -OutFile Sysmon.zip
Expand-Archive Sysmon.zip -DestinationPath .
Invoke-WebRequest https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml -OutFile sysmonconfig.xml
.\Sysmon64.exe -accepteula -i sysmonconfig.xml
```

Configuración usada: la de referencia de
[SwiftOnSecurity](https://github.com/SwiftOnSecurity/sysmon-config)
(ver `../../configs/sysmon/`).

Comprobar:

```powershell
Get-Service Sysmon64
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 3
```

## Instalar el agente Wazuh

Versión igual o inferior a la del Manager (4.14.7):

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri https://packages.wazuh.com/4.x/windows/wazuh-agent-4.14.7-1.msi -OutFile $env:TEMP\wazuh-agent.msi
Test-Path $env:TEMP\wazuh-agent.msi
msiexec.exe /i $env:TEMP\wazuh-agent.msi /q WAZUH_MANAGER="192.168.58.136" WAZUH_AGENT_NAME="win11-pc1"
NET START WazuhSvc
```

(Cambiar `WAZUH_AGENT_NAME` a `win-server-2025` en el servidor.)

> El comando debe ejecutarse en **PowerShell**, no en CMD: `$env:TEMP`
> no se expande igual en ambos y provoca instalaciones silenciosas
> fallidas.

## Hacer que el agente lea Sysmon

Añadir en `C:\Program Files (x86)\ossec-agent\ossec.conf`, antes de
`</ossec_config>` (ver plantilla en
`../../configs/wazuh/ossec-windows-sysmon.xml`):

```xml
<localfile>
  <location>Microsoft-Windows-Sysmon/Operational</location>
  <log_format>eventchannel</log_format>
</localfile>
```

```powershell
Restart-Service -Name WazuhSvc
```

## Verificación

```powershell
Get-Content "C:\Program Files (x86)\ossec-agent\ossec.log" -Tail 20
```

En el Dashboard, **Threat Hunting → Events**, filtrar por:

```
data.win.system.providerName: Microsoft-Windows-Sysmon
```

Resultado real obtenido: ver
`../../evidence/screenshots/uc04-powershell-sysmon-detection.png`.
