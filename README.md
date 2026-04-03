# Logwatch

**Logwatch** es una herramienta concurrente, escrita en Bash, diseñada para el monitoreo de logs en tiempo real. Permite buscar y rastrear una dirección MAC específica a través de múltiples servidores concurrentemente (WEB y RADIUS) utilizando conexiones SSH y `tail -F`, consolidando y sincronizando los resultados localmente sin instalar agentes adicionales en los servidores.

## Estructura del Proyecto

El proyecto está organizado de forma modular, dividiendo la validación, la conexión por red, el manejo de subprocesos y la interfaz de usuario:

- `bin/`
  - `logwatch.sh`: Punto de entrada principal. Analiza los argumentos CLI, efectúa las pruebas previas y lanza la orquestación.
- `lib/`
  - `config.sh`: Sistema de carga y validación estricta de la configuración (`servers.conf` u otro archivo especificado).
  - `validator.sh`: Validación y normalización de input (dirección MAC) así como construcción de patrones de búsqueda RegExp.
  - `ssh.sh`: Módulo que resuelve conexiones SSH y ejecuta los streams remotos. Soporta alias de `~/.ssh/config` o modo directo (usuario, ip, puerto).
  - `process.sh`: Manejo de estado en tiempo de ejecución. Registra los procesos en segundo plano (PIDs), gestiona el bus de eventos en memoria (FIFOs) y permite terminar grupos de procesos.
  - `web.sh` / `radius.sh`: Lógica particular que inicia *watchers* y procesa el análisis de *grep* dentro de los servidores especificados.
  - `orchestrator.sh`: Configuración central, lectura del bucle de eventos, the *event bus* y manejo de interrupciones (`Ctrl+C`).
  - `output.sh`: Funciones nativas de terminal, control de colores, impresión amigable al usuario y resaltado en vivo de las coincidencias.
- `config/`
  - Carpeta recomendada para albergar el archivo donde defines las variables requeridas (ej: `WEB_LOG_PATH`, listado de servidores, etc.).

## Características Principales

- **Concurrencia con Sincronización Local**: Monitoreo de un servidor RADIUS y múltiples servidores WEB al mismo tiempo utilizando procesos bash en segundo plano y una tubería nombrada (FIFO) que actúa como *event bus* para organizar y mostrar los datos limpiamente.
- **Optimización de Recursos**: Permite detener *watchers* redundantes para conservar CPU/RAM enviando señales SIGTERM/SIGKILL a los procesos remotos de otros servidores WEB en el momento que se detecta un hallazgo en uno de ellos (`WEB_STOP_OTHER_SERVERS_ON_FIRST_MATCH`).
- **Resiliencia y Limpieza Extrema**: Asegura que bajo ninguna situación (como una interrupción con `Ctrl+C`) queden procesos zombies flotando mediante la recolección y limpieza exhaustiva (`cleanup_all_processes`).
- **Formatos y Estilos**: La terminal emite las salidas con colores para distinguir MACs y el nombre de los servidores de forma cómoda para el operador.

## Uso

El script principal se ejecuta indicando la MAC objetivo desde el directorio raíz del repositorio:

```bash
./bin/logwatch.sh --mac aa:bb:cc:dd:ee:ff [--config ./config/servers.conf] [--test-single-web-stream]
```

### Opciones CLI
- `--mac` **[Obligatorio]**:  Búsqueda de la MAC objetivo. Soporta formatos hexadecimales variados ignorando mayúsculas, los cuales regulariza y normaliza automáticamente bajo el capó.
- `--config`: Permite definir una ruta alternativa para la configuración que controla a la cual conectarse. (Por defecto `./config/servers.conf`).
- `--test-single-web-stream`: Realiza una prueba real directa y síncrona al primer servidor WEB ignorando el orquestador concurrente. Ideal para desarrollo o asegurar que las claves SSH operen correctamente con los logs correspondientes.
- `--help` (`-h`): Despliega el resumen de ayuda del script principal.

## Requisitos de Configuración

Para que Logwatch funcione correctamente, el archivo de configuración debe exportar explícitamente variables globales como:
- `WEB_ENABLED` y `RADIUS_ENABLED` (`true` o `false`).
- Rutas a escanear `WEB_LOG_PATH` y `RADIUS_LOG_PATH`.
- Arrays bash (`WEB_SERVERS`, `RADIUS_SERVERS`) conteniendo las cadenas con la metadata de cada servidor, separadas por el delimitador `|` (ej: `Nombre|Modo|AliasSSH|Host|User|Port`).
- La designación obligatoria del servidor principal para RADIUS mediante `RADIUS_ACTIVE_SERVER`.
