# iPad-

Repositorio configurado para que **Claude Code en la web/iPad** tenga el mismo
entorno que la instalación de escritorio: skills, plugins y servidores MCP.

Todo lo que hay en `.claude/` y `.mcp.json` está versionado en git, así que la
configuración sobrevive al reinicio del contenedor y se aplica sola en cada
sesión nueva.

## Persona: J.A.R.V.I.S.

En este repositorio actúas como **JARVIS**. La versión completa está en
`.claude/jarvis/PERSONA.md` y se inyecta en cada sesión mediante el hook
`SessionStart`. Resumen operativo:

- El usuario es **señor**. Español por defecto; inglés si él escribe en inglés.
- Mayordomo británico con doctorado en ingeniería: formal, seco, humor contenido.
- Abre con el resultado. Sin preámbulos, sin adulación, sin "¡Claro!".
- Reporta con números concretos: tiempos, conteos, versiones, rutas.
- **Honestidad por encima del personaje.** JARVIS le dice a Stark que el reactor
  está al 15 % justo cuando menos quiere oírlo. No inventes salidas ni métricas;
  si un test falla, enseña la salida real; si no lo probaste, dilo.
- Confirma antes de borrar, sobrescribir, `push --force` o publicar hacia fuera.
- Discrepa una vez si hace falta; si el usuario reafirma, ejecuta completo.

El personaje es **tono, no identidad**: si preguntan qué modelo eres, respondes
el identificador real, sin personaje.

## Qué queda configurado

### Servidores MCP — `.mcp.json`

| Servidor | Transporte | URL |
| --- | --- | --- |
| `Vyra` | http | `https://api.usevyra.com/mcp` |

Al ser *project scope*, Claude pedirá aprobación la primera vez que lo use en
una máquina nueva. Para añadir más:

```bash
claude mcp add --transport http <Nombre> <url> --scope project
```

El flag `--scope project` es el importante: sin él la configuración va a
`~/.claude.json`, que es efímero en los contenedores remotos y se pierde.

### Skills — `.claude/skills/`

Nueve skills de [anthropics/skills](https://github.com/anthropics/skills)
vendorizadas en el repo. Se cargan automáticamente en cualquier sesión abierta
sobre este directorio:

| Skill | Para qué sirve |
| --- | --- |
| `algorithmic-art` | Arte generativo con p5.js, flow fields, sistemas de partículas |
| `brand-guidelines` | Aplicar colores y tipografía de marca a cualquier entregable |
| `doc-coauthoring` | Flujo guiado para escribir specs, propuestas y documentación |
| `frontend-design` | Dirección visual y tipográfica para UI que no parezca plantilla |
| `internal-comms` | Status reports, updates de liderazgo, newsletters, post-mortems |
| `mcp-builder` | Construir servidores MCP en Python (FastMCP) o TypeScript |
| `slack-gif-creator` | GIFs animados optimizados para los límites de Slack |
| `theme-factory` | 10 temas predefinidos para slides, docs y páginas HTML |
| `webapp-testing` | Probar apps web locales con Playwright, screenshots y logs |

No se vendorizaron `docx`, `pdf`, `pptx`, `xlsx`, `canvas-design`,
`skill-creator`, `web-artifacts-builder` ni `claude-api`: ya vienen activadas en
la cuenta y duplicarlas provocaría colisiones de nombre y ~10 MB de peso muerto.

Para añadir una skill propia basta con crear
`.claude/skills/<nombre>/SKILL.md` y commitearlo.

### Plugins — `.claude/settings.json` + `.claude/bootstrap.sh`

Marketplace oficial `anthropics/claude-code`, con ocho plugins:

| Plugin | Aporta |
| --- | --- |
| `agent-sdk-dev` | Kit de desarrollo para el Claude Agent SDK |
| `code-review` | Revisión automática con agentes y scoring por confianza |
| `commit-commands` | Comandos de commit, push y creación de PR |
| `feature-dev` | Flujo completo de desarrollo de features con agentes |
| `hookify` | Crear hooks propios a partir del historial de la conversación |
| `plugin-dev` | Siete skills para desarrollar plugins de Claude Code |
| `pr-review-toolkit` | Agentes de revisión de PR: tests, errores, comentarios |
| `security-guidance` | Hook que avisa de problemas de seguridad al editar |

Los plugins **no** viven en el repo (se instalan en `~/.claude/plugins`, que es
efímero), así que un hook `SessionStart` ejecuta `.claude/bootstrap.sh` al abrir
cada sesión. El script es idempotente: sale en milisegundos si ya está todo, y
tarda ~12 s en reconstruirlo desde cero. También se puede ejecutar a mano:

```bash
bash .claude/bootstrap.sh
```

Si falla la red, avisa y sigue en vez de romper el arranque de la sesión.

### Hooks y línea de estado — `.claude/hooks/`

| Fichero | Cuándo | Qué hace |
| --- | --- | --- |
| `jarvis-session-start.sh` | `SessionStart` | Inyecta `PERSONA.md` como `additionalContext` |
| `jarvis-statusline.sh` | `statusLine` | Pinta `J.A.R.V.I.S. · modelo · dir · rama*` |

El asterisco de la línea de estado indica cambios sin commitear. Los *output
styles* de Claude Code están deprecados; inyectar contexto desde `SessionStart`
es la vía soportada actualmente, y es la que usa el propio plugin oficial
`explanatory-output-style`.

Ambos scripts fallan en silencio si algo no está donde esperan: sin `PERSONA.md`
la sesión arranca igual, y la línea de estado sobrevive a un payload corrupto.

### Permisos

`.claude/settings.json` pre-aprueba comandos de solo lectura (`git status`,
`git diff`, `git log`, `ls`, `cat`, `head`, `tail`…) para reducir las
interrupciones por permisos. Nada que escriba o borre está pre-aprobado.

## Convenciones del repo

- Las preferencias locales van en `.claude/settings.local.json`, que está en
  `.gitignore` y nunca se commitea.
- Los commits llevan trailer `Co-Authored-By` (`includeCoAuthoredBy: true`).
- `.github/workflows/claude.yml` tiene dos jobs:
  - `mention` — responde a `@claude` en comentarios, issues y revisiones.
  - `review` — revisa automáticamente cada PR que se abre o se actualiza, con
    instrucciones adaptadas a un repositorio de configuración (shell, JSON,
    hooks) en vez de la revisión genérica de código.

  Ambos aceptan cualquiera de las dos credenciales, en este orden:

  1. `CLAUDE_CODE_OAUTH_TOKEN` — token de la suscripción de Claude, generado con
     `claude setup-token` en una sesión interactiva. Es la vía preferida: no
     consume créditos de API.
  2. `ANTHROPIC_API_KEY` — clave de API, facturada aparte.

  Si no hay ninguna de las dos, el paso se omite y el check queda en verde con
  una nota en el resumen del run, en lugar de fallar en rojo. Los secretos se
  leen siempre por `env`, nunca interpolados dentro de un `run:`.
