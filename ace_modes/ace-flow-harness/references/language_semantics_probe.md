# Language-semantics probe - "what does parser X do with construct Y?"

A different job from a flow harness: the question is not "does my flow work" but "how
do the ACE parsers treat this piece of syntax". Worked exemplar:
`D:/GIT/Ace_test_cases/ExecutableComments/` (`gen.py`, `build.cmd`, `server.cmd`,
`toolkit.cmd`, `TESTING.md`) - it established on ACE 13.0.8.1 that the runtime executes
`/*!{ }!*/` and `--!{` while the Toolkit treats both as comments.

## The shape

1. **One variant per deployable unit.** A generator (`gen.py`) writes one tiny app per
   syntax variant from a single msgflow/project template (HTTPInput -> Compute ->
   HTTPReply, the Compute holding the variant). A runtime parse failure then isolates to
   that one app instead of failing the whole deploy.
2. **One work dir, every app.** `ibmint package` each app, `mqsicreateworkdir` once,
   `ibmint deploy --output-work-directory` each BAR, start one standalone server.
   `ibmint package` and `deploy` do not parse ESQL at all: the integration server at
   start is the first runtime parser to see the file.
3. **One Toolkit workspace per app** for the Toolkit's verdict:
   `mqsicreatebar -data <ws>/<App> -b <App>.bar -a <App> -cleanBuild`. It checks the
   whole workspace for error markers, so one bad app in a shared workspace poisons
   every verdict.
4. **Each parser's verdict comes from its own log, never an exit code.**
   - Runtime: wait for `BIP1991I`, call each app (`curl http://127.0.0.1:7801/<app>`),
     and design the response so each key proves one statement ran. An app missing
     altogether has a `BIP4125E` / `BIP2401E` / `BIP2432E` / `BIP4127E` naming it.
   - Toolkit: the per-app log ends in `BIP0986I` (clean) or `BIP0965E` + problem markers.
5. **A must-fail canary before reading any pass.** Put the same defect in the open
   (`ToolkitCanaryGarbage`: the garbage outside the markers). If the Toolkit does not
   reject the canary, its clean verdict on the hidden variant means nothing.

## cmd scars (they cost a rerun each)

- `mqsicreateworkdir` and the other `mqsi*` commands are batch files: `call` them, or the
  calling script silently ends there.
- `%ERRORLEVEL%` inside a `for` body expands once at parse time and reports 0 for every
  iteration. Use `setlocal enabledelayedexpansion` + `!ERRORLEVEL!`, or better, assert on
  the BIP message in the log.
- `chcp 1252` before `IntegrationServer`, or every flow fails at startup with `BIP2132E`.
- Stop the server port-scoped (`netstat -ano` on its admin port, `taskkill /PID`), never
  `taskkill /IM IntegrationServer.exe` - that kills every server on the box.

Record the measured matrix (variant x runtime x Toolkit) in the test folder's TESTING.md
and the conclusion in the vault; the probe folder lives in `D:/GIT/Ace_test_cases/`.
