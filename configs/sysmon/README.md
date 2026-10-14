# Configuración de Sysmon usada en el laboratorio

Se utilizó la configuración de referencia pública de
[SwiftOnSecurity/sysmon-config](https://github.com/SwiftOnSecurity/sysmon-config)
(`sysmonconfig-export.xml`), sin modificaciones, como punto de
partida. No se redistribuye aquí para evitar duplicar un repositorio
de terceros; se descarga directamente durante el despliegue:

```powershell
Invoke-WebRequest https://raw.githubusercontent.com/SwiftOnSecurity/sysmon-config/master/sysmonconfig-export.xml -OutFile sysmonconfig.xml
.\Sysmon64.exe -accepteula -i sysmonconfig.xml
```

Ver [`docs/setup/03-sysmon-agents-windows.md`](../../docs/setup/03-sysmon-agents-windows.md)
para el procedimiento completo.
