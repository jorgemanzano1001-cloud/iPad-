# iPad-

Repositorio configurado para que **Claude Code en la web/iPad** tenga el mismo
entorno que la instalación de escritorio: skills, plugins y servidores MCP.

Todo lo que hay en `.claude/` y `.mcp.json` está versionado en git, así que la
configuración sobrevive al reinicio del contenedor y se aplica sola en cada
sesión nueva.

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

### Permisos

`.claude/settings.json` pre-aprueba comandos de solo lectura (`git status`,
`git diff`, `git log`, `ls`, `cat`, `head`, `tail`…) para reducir las
interrupciones por permisos. Nada que escriba o borre está pre-aprobado.

## Convenciones del repo

- Las preferencias locales van en `.claude/settings.local.json`, que está en
  `.gitignore` y nunca se commitea.
- Los commits llevan trailer `Co-Authored-By` (`includeCoAuthoredBy: true`).
- `.github/workflows/claude.yml` ejecuta la Claude Code Action al comentar en
  issues y en revisiones de PR.
