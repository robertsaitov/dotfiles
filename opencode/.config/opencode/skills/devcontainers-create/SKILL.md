---
name: devcontainer-create
description: Create devcontainers for projects
compatibility: opencode
---
## Purpose
Create a reusable Fedora-based devcontainer for any project. The base should always be a stable Fedora release. The skill supports two modes:

1) User-specified tools and versions
2) AI-inferred tools and versions

This skill should avoid editor-specific settings (no VS Code customization blocks).

## Inputs
Provide either:

- A list of tools and versions
- A brief description of the project stack and requirements

## Output
Generate a `.devcontainer/devcontainer.json` with:

- `image` set to `registry.fedoraproject.org/fedora:<release>` (default 41)
- `features` for requested tools (Node, Go, Python, etc.)
- `postCreateCommand` for any extra packages or global installs

## Defaults
- Fedora release: 41
- Include `common-utils` and `git` features
- No editor customization

## Example Invocation
"Create a devcontainer for Node 16.20.2 with Angular CLI 11.2.14 and Gulp. Use Fedora 40."

## Example Output
```json
{
  "name": "fedora-dev",
  "image": "registry.fedoraproject.org/fedora:40",
  "features": {
    "ghcr.io/devcontainers/features/common-utils:2": {},
    "ghcr.io/devcontainers/features/git:1": {},
    "ghcr.io/devcontainers/features/node:1": {
      "version": "16.20.2"
    }
  },
  "postCreateCommand": "npm install -g @angular/cli@11.2.14 gulp"
}
```
