---
name: devcontainer-create
description: Create devcontainers for the project with Dockerfile + bindep list
compatibility: opencode
---
## Purpose
Create a reusable devcontainer for any project using a generic Dockerfile and a bindep dependency file.
The skill supports two modes:

1) User-specified tools and versions
2) AI-inferred tools and versions

This skill should avoid editor-specific settings (no VS Code customization blocks).

## Defaults
- Fedora release: 43
- Include `common-utils` and `git` features
- No editor customization
- Prefer Linux packages listed in `bindep.txt` over `postCreateCommand`

## Definitions
- `dockerFile` in `devcontainer.json` pointing at the Dockerfile (no `image` field)
- `Dockerfile` based on `registry.fedoraproject.org/fedora:<release>` (default 43)
- `bindep.txt` listing default Linux packages to install (one per line), parsed by the Dockerfile
- `features` only for tools that must be installed via devcontainer features
- `postCreateCommand` for any extra packages (like npm) or global installs

## Rules
- Use the templates in this skill folder as the starting point, copy them into the project, and update them to match the project requirements.
- Make sure to reference all base template files within {baseDir} of this skill directory when you generate project wide files.
- Copy .nprmrc from the home directory of the host if npm packages are needed for the project

## Inputs
Provide/request either:

- A list of tools and versions
- A brief description of the project stack and requirements

## Output
1. Create a `.devcontainer` directory for the project if it does not exist.
2. Generate a `.devcontainer/devcontainer.json` plus a generic `.devcontainer/Dockerfile` and a `.devcontainer/bindep.txt` file in the project directory.
3. Ensure if exist, commands in postCreateCommand start from a new line and are represented in an array form.
