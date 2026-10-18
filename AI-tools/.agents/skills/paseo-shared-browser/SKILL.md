---
name: paseo-shared-browser
description: Use Paseo's visible shared browser when the user asks to open, view, or interact with a page in the shared browser. Do not use for background browser automation.
---

# Paseo shared browser

Use the `mcp__shared_browser__shared_browser_*` tools. Discover their current schemas if needed. `mcp__paseo__browser_new_tab` opens a background automation tab that the user may not see; `cua_repl` controls a different browser.

1. Read `shared_browser_status`; list tabs if that call responds. Acquire control before changing the page. If another viewer holds control, do not force takeover.
2. Prefer `shared_browser_tab_open` for a new page. If it stalls, inspect the current tab and navigate it only when replacing its contents is appropriate for the request. Do not infer visibility from a Paseo automation snapshot.
3. Navigate to the requested URL. Use `shared_browser_capture` to observe the rendered page before each input; input coordinates must use the captured frame's width and height. Capture again after navigation or any state-changing input. Reacquire control if the lease expires.
4. Verify the result in a final shared-browser capture, then release control. Tab selection can differ by viewer, so name the tab or URL for the user; a capture alone does not prove their view switched. Report a concrete blocker if the shared browser cannot reach it.

For this repo, the dev frontend is `http://localhost:19000`. Start or check the server before opening it; see `taskfiles/integration.yml` for seeded fixtures. Use demo credentials only when the user asks to sign in, and read them from `auth/README.md`.
