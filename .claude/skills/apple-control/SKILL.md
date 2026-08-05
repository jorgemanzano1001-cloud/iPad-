---
name: apple-control
description: Controlar las apps de Apple en macOS desde Claude Code — Recordatorios, Calendario, Notas, Mensajes, Música y Atajos — vía osascript y la CLI shortcuts. Úsala cuando el usuario pida crear recordatorios, alarmas, eventos de calendario o notas, reproducir música, enviar mensajes, o automatizar cualquier app de Apple. Solo funciona en macOS.
---

# Control de apps de Apple

Recetas de `osascript` y `shortcuts` para operar las apps de Apple desde el
terminal. Es el puente entre Claude Code y el escritorio del usuario.

## Antes de nada: comprueba que estás en macOS

Estas recetas **solo funcionan en macOS**. En Linux no existe `osascript` y todo
fallará con `command not found`. Comprueba primero y dilo claramente en vez de
intentarlo:

```bash
[ "$(uname)" = "Darwin" ] || echo "No es macOS: estas recetas no aplican aquí."
command -v osascript >/dev/null || echo "osascript no disponible."
```

Si el usuario está en Claude Code **web/iPad**, la respuesta correcta es que
estas capacidades no existen en ese entorno, no un intento que fracase.

## La regla de oro: nunca interpoles datos en el AppleScript

Meter una variable de shell dentro del script con comillas dobles es una vía de
inyección y se rompe con cualquier apóstrofo — «Mamá's» ya basta para romperlo.
Pasa siempre los datos como argumentos con `on run argv`:

```bash
# MAL: se rompe y es inyectable
osascript -e "tell application \"Reminders\" to make new reminder with properties {name:\"$TITULO\"}"

# BIEN: heredoc entrecomillado + argv
osascript - "$TITULO" <<'APPLESCRIPT'
on run argv
    tell application "Reminders"
        make new reminder with properties {name:(item 1 of argv)}
    end tell
end run
APPLESCRIPT
```

El `<<'APPLESCRIPT'` con comillas simples impide que el shell toque el
contenido. Es el mismo principio que evita interpolar secretos en un `run:`.

## Permisos: el fallo que parece un bug

La primera vez que un script controla otra app, macOS muestra un diálogo
—«Terminal quiere controlar Recordatorios»—. Si el usuario lo deniega, o si el
diálogo no aparece porque el proceso no es interactivo, el script falla con:

```
execution error: No se ha permitido el acceso. (-1743)
```

**No es un fallo del script.** Indícale al usuario que vaya a Ajustes del
Sistema → Privacidad y seguridad → Automatización y active el permiso para su
terminal. Sin eso, ninguna receta de este documento funciona.

## Fechas: constrúyelas, no las parsees

`date "10/8/2026"` se interpreta distinto según la configuración regional, y en
español puede acabar en agosto o en octubre. Construye la fecha por campos:

```applescript
on fechaDesde(a, m, d, hh, mm)
    set t to current date
    -- Día a 1 ANTES de tocar mes o año: si hoy es 31 y fijas febrero, la
    -- fecha se desborda a marzo. Es el error clásico de fechas en AppleScript.
    set day of t to 1
    set year of t to a
    set month of t to m
    set day of t to d
    set hours of t to hh
    set minutes of t to mm
    set seconds of t to 0
    return t
end fechaDesde
```

Para tiempos relativos, la aritmética directa es más segura y más legible:

```applescript
set dentroDeDosHoras to (current date) + 2 * hours
set mañanaAlaMismaHora to (current date) + 1 * days
```

## Recordatorios

Crear uno con aviso:

```bash
osascript - "Llamar al fontanero" "2026-08-10 09:30" <<'APPLESCRIPT'
on run argv
    set elTexto to item 1 of argv
    set laFecha to my parseISO(item 2 of argv)
    tell application "Reminders"
        make new reminder with properties {name:elTexto, remind me date:laFecha}
    end tell
end run

on parseISO(s)
    -- Espera "AAAA-MM-DD HH:MM"
    set t to current date
    -- Día a 1 ANTES de tocar mes o año: si hoy es 31 y fijas febrero, la
    -- fecha se desborda a marzo. Es el error clásico de fechas en AppleScript.
    set day of t to 1
    set year of t to (text 1 thru 4 of s) as integer
    set month of t to (text 6 thru 7 of s) as integer
    set day of t to (text 9 thru 10 of s) as integer
    set hours of t to (text 12 thru 13 of s) as integer
    set minutes of t to (text 15 thru 16 of s) as integer
    set seconds of t to 0
    return t
end parseISO
APPLESCRIPT
```

En una lista concreta, añade `tell list "Trabajo"` dentro del `tell application`.

Listar los pendientes:

```bash
osascript <<'APPLESCRIPT'
tell application "Reminders"
    set salida to {}
    repeat with r in (every reminder whose completed is false)
        set end of salida to (name of r)
    end repeat
    return salida
end tell
APPLESCRIPT
```

Marcar como completado por nombre exacto:

```bash
osascript - "Llamar al fontanero" <<'APPLESCRIPT'
on run argv
    tell application "Reminders"
        set coincidencias to (every reminder whose name is (item 1 of argv) and completed is false)
        if (count of coincidencias) is 0 then return "sin coincidencias"
        repeat with r in coincidencias
            set completed of r to true
        end repeat
        return "completados: " & (count of coincidencias)
    end tell
end run
APPLESCRIPT
```

## Alarmas: no hay AppleScript para ellas

**Sé honesto en este punto.** El Reloj de macOS no expone diccionario
AppleScript, así que no se puede crear una alarma como en el iPhone. Las
alternativas reales, por orden de utilidad:

1. **Un recordatorio con hora** (arriba). Es lo más parecido y suena en todos
   los dispositivos del usuario con la misma cuenta de iCloud.
2. **Un Atajo llamado desde la CLI** — si el usuario crea un Atajo que ponga
   una alarma, se dispara con `shortcuts run`.
3. **`launchd` o `at`** para ejecutar un comando a una hora dada, si lo que
   quiere es que *ocurra algo*, no que suene una alarma.

No inventes un `tell application "Clock"`: no existe.

## Calendario

```bash
osascript - "Personal" "Revisión de diseño" "2026-08-10 16:00" "60" <<'APPLESCRIPT'
on run argv
    set elCalendario to item 1 of argv
    set elTitulo to item 2 of argv
    set inicio to my parseISO(item 3 of argv)
    set duracion to (item 4 of argv) as integer
    tell application "Calendar"
        tell calendar elCalendario
            make new event with properties {summary:elTitulo, start date:inicio, end date:inicio + duracion * minutes}
        end tell
    end tell
end run

on parseISO(s)
    set t to current date
    -- Día a 1 ANTES de tocar mes o año: si hoy es 31 y fijas febrero, la
    -- fecha se desborda a marzo. Es el error clásico de fechas en AppleScript.
    set day of t to 1
    set year of t to (text 1 thru 4 of s) as integer
    set month of t to (text 6 thru 7 of s) as integer
    set day of t to (text 9 thru 10 of s) as integer
    set hours of t to (text 12 thru 13 of s) as integer
    set minutes of t to (text 15 thru 16 of s) as integer
    set seconds of t to 0
    return t
end parseISO
APPLESCRIPT
```

El nombre del calendario debe existir tal cual. Para comprobarlo:

```bash
osascript -e 'tell application "Calendar" to return name of every calendar'
```

Eventos de hoy:

```bash
osascript <<'APPLESCRIPT'
set hoy to current date
set hours of hoy to 0
set minutes of hoy to 0
set seconds of hoy to 0
set mañana to hoy + 1 * days
tell application "Calendar"
    set salida to {}
    repeat with c in every calendar
        repeat with e in (every event of c whose start date ≥ hoy and start date < mañana)
            set end of salida to (summary of e) & " — " & (start date of e as string)
        end repeat
    end repeat
    return salida
end tell
APPLESCRIPT
```

Esta consulta puede tardar bastante si hay muchos calendarios suscritos. Avisa
al usuario en vez de dejarle mirando un cursor parado.

## Notas

```bash
osascript - "Ideas de producto" "Primera línea del cuerpo." <<'APPLESCRIPT'
on run argv
    tell application "Notes"
        tell folder "Notes"
            make new note with properties {name:(item 1 of argv), body:(item 2 of argv)}
        end tell
    end tell
end run
APPLESCRIPT
```

El cuerpo admite HTML básico: `<div>`, `<b>`, `<ul><li>`. El nombre de la
carpeta depende del idioma del sistema — en español puede ser «Notas». Si falla,
lista las carpetas con `return name of every folder`.

## Atajos (Shortcuts)

La vía más potente, porque cubre lo que AppleScript no alcanza — incluido buena
parte de lo que existe en iOS.

```bash
shortcuts list                          # ver los disponibles
shortcuts run "Nombre del Atajo"        # ejecutar
echo "texto" | shortcuts run "Mi Atajo" # pasarle entrada por stdin
shortcuts run "Mi Atajo" -o salida.txt  # capturar la salida
```

Si el usuario quiere algo que AppleScript no puede hacer, casi siempre la
respuesta correcta es: «cree un Atajo que lo haga y lo llamo desde aquí».

## Música

```bash
osascript -e 'tell application "Music" to play'
osascript -e 'tell application "Music" to pause'
osascript -e 'tell application "Music" to return name of current track & " — " & artist of current track'
osascript -e 'tell application "Music" to set sound volume to 40'
```

## Mensajes

```bash
osascript - "+34600000000" "Llego en diez minutos." <<'APPLESCRIPT'
on run argv
    tell application "Messages"
        set elServicio to 1st account whose service type = iMessage
        send (item 2 of argv) to participant (item 1 of argv) of elServicio
    end tell
end run
APPLESCRIPT
```

**Confirma siempre el destinatario y el texto con el usuario antes de enviar.**
Un mensaje enviado no se puede recuperar, y equivocarse de contacto tiene coste
social real. Esto no es opcional.

## Notificaciones y voz

```bash
osascript -e 'display notification "Compilación terminada" with title "Claude"'
say "Compilación terminada"
say -v Monica "Listo, señor."   # voz en español; ver 'say -v ?'
```

## Diagnóstico

| Síntoma | Causa habitual |
| --- | --- |
| `-1743` | Permiso de automatización denegado. Ajustes → Privacidad → Automatización |
| `-1728` («no se puede obtener») | El objeto no existe: nombre de lista, calendario o carpeta mal escrito |
| `command not found: osascript` | No estás en macOS |
| `command not found: shortcuts` | macOS anterior a Monterey (12) |
| La fecha cae en el mes equivocado | Estás parseando una cadena. Constrúyela por campos |

Para ver el diccionario AppleScript completo de una app, ábrelo en el Editor de
Scripts: Archivo → Abrir diccionario. Es la fuente de verdad cuando una receta
de aquí no encaja con la versión de macOS del usuario.
