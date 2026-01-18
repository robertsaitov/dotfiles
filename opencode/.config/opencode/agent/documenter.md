---
description: Agent to document changes
mode: subagent
permission:
  edit: allow
  bash:
    "*": ask
    "git diff": allow
    "git log*": allow
    "grep *": allow
  webfetch: allow
---
