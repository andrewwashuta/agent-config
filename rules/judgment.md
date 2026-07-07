# Distilled session judgment

Lessons distilled from past sessions by `/distill` — typically written by a stronger model so every model benefits. Treat entries as strong defaults, not hard rules: an explicit user instruction in the current session always wins. Maintained by `/distill`; don't edit by hand mid-session (run `/distill` instead).

## Global judgment

- Before re-tagging Greptile, scan recent PR comments for an existing `@greptileai` request and reuse that timestamp/listener instead of posting a duplicate — Andrew may have already triggered review himself, and duplicate bot pings create noise. *(2026-07)*
- iOS 27 WebKit plays the switch haptic ONLY for a trusted tap on a real `<input type="checkbox" switch>` — synthetic `.click()`s are silent, so web-haptics and every click-a-hidden-switch scheme (including the old re-hide patch) are dead; overlay a full-size opacity-0 native switch inside the control so the finger toggles it and the click bubbles to the host's onClick (reference impl: os-marketing-page `components/haptic-switch.tsx`; verified on-device via a disposable bisect page with one strategy per row — build one of those before theorizing about haptics). *(2026-07)*
- When a codex-rescue job sits in "verifying" for many minutes, `ps` for its build/test process before waiting longer — codex can keep polling a process that already died silently; cancel the job and run the verification yourself (the applied edits are already in the working tree). *(2026-07)*
- When Andrew tunes visual weight (shadows, borders, rings, tints), change ONE small dial per round and name the dial and its next steps in the reply — he converges through quick ±1-step iterations against reference screenshots, and a multi-dial change makes the feedback loop ambiguous. *(2026-07)*
- Before claiming what a declared `font-weight` renders, read the `@font-face` blocks and check `font-synthesis`: with limited faces (e.g. 400+600 only) CSS resolves 500 DOWN to 400 but 700 UP to 600 — an os-june audit inverted this and nearly mis-scoped a 127-site sweep; grep the shipped faces first, then reason per the desired-weight matching rules. *(2026-07)*

## Per-project judgment

When working in one of these repos, read its judgment file before starting substantive work:

| Repo | File |
|---|---|
| os-marketing-page | `judgment/os-marketing-page.md` |
| os-june | `judgment/os-june.md` |
