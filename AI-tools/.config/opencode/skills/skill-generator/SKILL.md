---
name: skill-generator
description: Generate Opencode Agent Skills from local or remote repositories using Repomix
---
## Purpose
Generate Agent Skills format output from codebases, creating structured directories that can be used as reusable codebase references. This is particularly useful for referencing implementations from remote repositories while working on local code.

## Preconditions
- repomix installed (`npm install -g repomix`)

## Usage Patterns

### Local directory skills
```bash
repomix --skill-generate
repomix --skill-generate my-project-reference
repomix path/to/directory --skill-generate
```

### Remote repository skills
```bash
repomix --remote https://github.com/user/repo --skill-generate
repomix --remote user/repo --skill-generate repo-name
```

### Documentation-only skills
```bash
repomix --remote https://github.com/vitejs/vite --include docs --skill-generate
repomix --remote https://github.com/reactjs/react.dev --include src/content --skill-generate
```

### Non-interactive usage
```bash
repomix --skill-generate --skill-output ./my-skills --force
repomix --remote user/repo --skill-generate my-skill --skill-output ./output --force
```

### With filtering options
```bash
repomix --skill-generate --include "src/**/*.ts" --ignore "**/*.test.ts"
repomix --skill-generate --compress --remove-comments --remove-empty-lines
```

## Skills Location
- **Agent global skills**: `{baseDir}` - Available across all projects

## Auto-generated names
Names are converted to kebab-case, limited to 64 characters:
- `repomix src/ --skill-generate` → `repomix-reference-src`
- `repomix --remote user/repo --skill-generate` → `repomix-reference-repo`
- `repomix --skill-generate CustomName` → `custom-name`

## Options
- `--skill-output <path>`: Specify skill output directory (skips location prompt)
- `-f, --force`: Skip all confirmation prompts

## Rules
1. Cannot be used with `--stdout` or `--copy` options
2. When generating project skills, consider adding `{baseDir}/repomix-reference-*/` to .gitignore
3. Use `--include` for documentation-only skills when you only want to reference docs
4. Use `--remote` with GitHub URLs to create reference skills from open source projects
5. Skills are automatically available in opencode if saved to `{baseDir}`
