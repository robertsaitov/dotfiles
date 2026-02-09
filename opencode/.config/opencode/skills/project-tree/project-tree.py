#!/usr/bin/env python3
"""
Project Tree Generator
Generates a file tree visualization and saves it to Project-Tree.md
Compatible with Windows, Linux, and macOS
"""

import os
import sys
import json
from pathlib import Path
from fnmatch import fnmatch


def load_config(script_dir):
    """Load configuration from config.json or use defaults."""
    config_path = os.path.join(script_dir, 'config.json')
    default_config = {
        "excluded_dirs": ["node_modules", "__pycache__", ".git", "venv", ".venv"],
        "excluded_files": [".DS_Store", "Thumbs.db"],
        "max_depth": 10
    }

    if os.path.exists(config_path):
        try:
            with open(config_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        except (json.JSONDecodeError, IOError):
            print(f"Warning: Could not read config.json, using defaults", file=sys.stderr)

    return default_config


def load_gitignore(root_dir):
    """Load patterns from .gitignore file."""
    gitignore_path = os.path.join(root_dir, '.gitignore')
    patterns = []

    if os.path.exists(gitignore_path):
        try:
            with open(gitignore_path, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    # Skip empty lines and comments
                    if line and not line.startswith('#'):
                        patterns.append(line)
        except IOError:
            pass

    return patterns


def matches_pattern(name, patterns):
    """Check if a name matches any of the glob patterns."""
    for pattern in patterns:
        # Handle directory-specific patterns (ending with /)
        if pattern.endswith('/'):
            pattern = pattern[:-1]

        if fnmatch(name, pattern):
            return True

        # Also check without leading slash or asterisk
        clean_pattern = pattern.lstrip('*/')
        if fnmatch(name, clean_pattern):
            return True

    return False


def should_exclude(name, is_dir, config, gitignore_patterns):
    """Determine if a file or directory should be excluded."""
    if is_dir:
        if name in config.get('excluded_dirs', []):
            return True
    else:
        if name in config.get('excluded_files', []):
            return True

    # Check gitignore patterns
    if matches_pattern(name, gitignore_patterns):
        return True

    return False


def generate_tree(root_dir, config, gitignore_patterns, prefix='', current_depth=0):
    """Recursively generate tree structure."""
    max_depth = config.get('max_depth', 10)

    if current_depth >= max_depth:
        return []

    try:
        items = sorted(os.listdir(root_dir))
    except PermissionError:
        return []
    except OSError:
        return []

    tree_lines = []
    visible_items = []

    for item in items:
        item_path = os.path.join(root_dir, item)
        is_dir = os.path.isdir(item_path)

        if not should_exclude(item, is_dir, config, gitignore_patterns):
            visible_items.append((item, is_dir))

    for i, (item, is_dir) in enumerate(visible_items):
        is_last = (i == len(visible_items) - 1)

        # Use box-drawing characters
        connector = '└── ' if is_last else '├── '
        line = prefix + connector + item

        if is_dir:
            line += '/'

        tree_lines.append(line)

        if is_dir:
            extension = '    ' if is_last else '│   '
            subtree = generate_tree(
                os.path.join(root_dir, item),
                config,
                gitignore_patterns,
                prefix + extension,
                current_depth + 1
            )
            tree_lines.extend(subtree)

    return tree_lines


def main():
    """Main function to generate project tree."""
    # Get the directory where the script is located
    script_dir = os.path.dirname(os.path.abspath(__file__))

    # Load configuration
    config = load_config(script_dir)

    # Use current working directory as the project root
    project_root = os.getcwd()
    project_name = os.path.basename(project_root)

    # Load .gitignore patterns
    gitignore_patterns = load_gitignore(project_root)

    # Generate tree
    tree_lines = [project_name + '/']
    tree_lines.extend(generate_tree(project_root, config, gitignore_patterns))

    # Create markdown content
    markdown_content = f"""# Project Tree

```
{chr(10).join(tree_lines)}
```
"""

    # Create docs/ directory if it doesn't exist
    docs_dir = os.path.join(project_root, 'docs')
    os.makedirs(docs_dir, exist_ok=True)

    # Write to docs/Project-Tree.md
    output_path = os.path.join(docs_dir, 'Project-Tree.md')
    try:
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(markdown_content)
        print(f"Project tree generated: {output_path}")
    except IOError as e:
        print(f"Error writing file: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
