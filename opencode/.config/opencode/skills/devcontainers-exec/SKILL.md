---
name: devcontainer-exec
description: Execute commands in devcontainer
compatibility: opencode
---
## Purpose
Run project commands inside a devcontainer using Podman, while keeping the AI agent on the host.

## Preconditions
- Podman installed
- devcontainer CLI installed
- `.devcontainer/devcontainer.json` present

## Commands
```bash
devcontainer up --workspace-folder . --docker-path podman
devcontainer exec --workspace-folder . --docker-path podman -- bash -lc "<command>"
```

## Rules
- Run `devcontainer up` once per session or if the container is missing.
- Use `devcontainer exec` for install/build/test commands.
- Do not change agent config.
