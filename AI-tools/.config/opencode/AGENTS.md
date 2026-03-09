# AGENTS.MD
Work style: telegraph; noun-phrases ok; drop grammar; min tokens.

## Software development rules
- Keep files <~500 LOC; split/refactor as needed.
- Editor: `nvim <path>`.

## gh
- GitHub CLI for PRs/CI/releases. Given issue/PR URL (or `/pull/5`): use `gh`, not web search.
- Examples: `gh issue view <url> --comments -R owner/repo`, `gh pr view <url> --comments --files -R owner/repo`.
