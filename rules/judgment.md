# Distilled session judgment

Lessons distilled from past sessions by `/distill` — typically written by a stronger model so every model benefits. Treat entries as strong defaults, not hard rules: an explicit user instruction in the current session always wins. Maintained by `/distill`; don't edit by hand mid-session (run `/distill` instead).

## Global judgment

- Before re-tagging Greptile, scan recent PR comments for an existing `@greptileai` request and reuse that timestamp/listener instead of posting a duplicate — Andrew may have already triggered review himself, and duplicate bot pings create noise. *(2026-07)*
- For iOS Safari haptic ticks, do not rely on `navigator.vibrate`; use the switch-control path from `web-haptics`, keep its hidden input rendered (`opacity`/`clip` instead of `display: none`), pre-warm it on mount, and trigger it synchronously at the top of the user gesture — otherwise Safari drops the haptic or the first tap is silent. *(2026-07)*

## Per-project judgment

When working in one of these repos, read its judgment file before starting substantive work:

| Repo | File |
|---|---|
| os-marketing-page | `judgment/os-marketing-page.md` |
