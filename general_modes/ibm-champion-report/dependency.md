# Browser dependency for `ibm-champion-report` (Bob)

The skill works without any browser: it always hands you the prefilled-form URL and the
copy-paste sheet. Filling the form in place needs a browser-automation MCP server, because
neither Bob IDE nor Bob Shell ships one (Bob Shell's `browser` tool group is only
`web_fetch`). Two servers are known to work; the skill prefers the first.

| Server | Why | Verified |
|---|---|---|
| **Playwright MCP** (`@playwright/mcp`, Microsoft) - preferred | Clicks by accessibility ref reach every control on the Airtable form, `browser_evaluate` reads field values back for verification, `browser_wait_for` handles the late-rendering form | Dry run completed from Bob, 2026-09-15 |
| **browsermcp** (`@browsermcp/mcp`, browsermcp.io) - fallback | Drives your logged-in Chrome through its extension, but cannot read values back and its clicks miss two controls (Amplify, How-many-more), which the skill works around by keyboard | Fill procedure verified from Bob, 2026-09 |

Bob loads every enabled tool definition into every conversation (no progressive
disclosure), so keep only the tools the skill needs enabled and disable the server when
you are not reporting activities.

## Playwright MCP

### Install

Needs Node.js 18 or newer. Pick a folder that stays put (the Bob config below points at it):

```bash
mkdir mcp-playwright && cd mcp-playwright
npm init -y
npm install @playwright/mcp
```

Alternatively skip the folder and let `npx` fetch it on every start
(`"command": "npx", "args": ["-y", "@playwright/mcp@latest", ...]`); slower to start and
the version floats.

### Wire it into Bob

Bob IDE and Bob Shell read the same file: `~/.bob/settings/mcp.json`
(`%USERPROFILE%\.bob\settings\mcp.json` on Windows). Add a server entry - adjust the path:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "node",
      "args": ["<absolute path>/mcp-playwright/node_modules/@playwright/mcp/cli.js", "--browser", "chrome"],
      "disabled": false,
      "timeout": 120000,
      "alwaysAllow": [
        "browser_navigate", "browser_navigate_back", "browser_snapshot", "browser_find",
        "browser_click", "browser_hover", "browser_type", "browser_press_key",
        "browser_select_option", "browser_fill_form", "browser_evaluate", "browser_wait_for",
        "browser_take_screenshot", "browser_console_messages", "browser_tabs"
      ],
      "disabledTools": [
        "browser_run_code_unsafe", "browser_file_upload", "browser_drop", "browser_drag",
        "browser_webmcp_list", "browser_webmcp_call", "browser_network_requests",
        "browser_network_request"
      ]
    }
  }
}
```

Use forward slashes in the path even on Windows. Reload the Bob window (or restart Bob
Shell); the server shows up in Bob's MCP tab with its tools.

`alwaysAllow` lists the tools the skill uses so Bob does not prompt for each click; drop
`browser_evaluate` from it if you want to approve JavaScript evaluation by hand. The
`disabledTools` are ones the skill never needs; re-enable per task if another workflow
wants them.

### Which browser it drives

| `args` | Behaviour |
|---|---|
| `--browser chrome` (as above) | Launches your installed Google Chrome with Playwright's **own persistent profile** (not your logged-in one). Enough for the champion form, which is public. Expect a cookie banner on first load. |
| `--extension` | Attaches to your **real, logged-in Chrome** (Chrome or Edge). Needs the "Playwright Extension" installed in that browser; `--browser` is ignored. Use it for pages behind a login wall. In this mode Airtable's autosaved draft can override the prefill - see the note in `references/form_fields.md`. |
| `--headless` | No window. Fine for checks, useless when you want to review the filled form. |

`node <path>/cli.js --help` lists the rest (`--cdp-endpoint`, `--isolated`, `--user-data-dir`, ...).

### Use

Nothing to do in the prompt. When the skill reaches the browser step it looks for the
Playwright tools in the live tool list and follows the "Bob / Playwright MCP add-on"
section of `references/form_fields.md`: navigate to the prefilled URL, wait for the form,
snapshot, type the manual fields, tick Amplify, set "How many MORE", read everything back
with `browser_evaluate`, and stop. The PRIVACY checkbox and the Submit button are yours.

### Check the install without Bob

```bash
node <path>/mcp-playwright/node_modules/@playwright/mcp/cli.js --browser chrome --help
```

prints the option list if the package is intact. A full round trip (initialize, tools/list,
navigate, evaluate) can be driven with any MCP client; the server speaks JSON-RPC over stdio.

## browsermcp (fallback)

1. Install the browsermcp Chrome extension from browsermcp.io and connect it to a tab.
2. Add the server to the same `mcp.json`:

```json
"browsermcp": {
  "command": "npx",
  "args": ["-y", "@browsermcp/mcp@latest"],
  "disabled": false,
  "timeout": 120000,
  "alwaysAllow": [
    "browser_navigate", "browser_snapshot", "browser_click", "browser_hover", "browser_type",
    "browser_press_key", "browser_select_option", "browser_wait", "browser_screenshot",
    "browser_get_console_logs", "browser_go_back", "browser_go_forward"
  ]
}
```

3. The skill uses it only when the Playwright tools are absent, following the
   "Bob / browsermcp add-on" section of `references/form_fields.md` (snapshot right after
   navigate to bind the tab; Amplify and "How many MORE" by keyboard from the Link field).

Tool names overlap with Playwright MCP's but are not the same set (`browser_screenshot`
vs `browser_take_screenshot`, `browser_wait` vs `browser_wait_for`); keep the two
`alwaysAllow` lists separate.
