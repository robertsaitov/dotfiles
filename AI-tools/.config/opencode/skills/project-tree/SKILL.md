---
name: project-tree
description: Generate a file tree visualization for the current project and save it to Project-Tree.md. Supports configurable exclusions for directories like node_modules.
---

## Purpose
Generate a visual file tree representation of the current project directory and save it to `Project-Tree.md`. Useful for documentation, understanding project structure, and sharing project layouts.

## Prerequisites
- Python 3.6+

## Usage Patterns

### Generate tree for current directory

```bash
python {baseDir}/project-tree/project-tree.py
```

## Configuration
The skill uses a JSON configuration file at `{baseDir}/project-tree/config.json`:
Based on your current setup, edit `{baseDir}/project-tree/config.json` to customize exclusions:

- **excluded_dirs**: Directories to skip (default: common build/cache directories)
- **excluded_files**: Files to skip (default: system files)
- **max_depth**: Maximum directory depth to traverse (default: 10)

## Output
Creates/updates `docs/Project-Tree.md` in the current working directory with a markdown-formatted file tree.

## When to Use
- When requested
- When new files/directories are added
- When the project structure changes

## Rules
1. Always respects `.gitignore` patterns in addition to config exclusions
2. Runs from the current working directory
3. Overwrites existing `docs/Project-Tree.md` files
4. Safe to run - only reads directory structure, doesn't modify other files
