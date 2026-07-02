# os-marketing-page judgment

## June Accent Theming

- For June accent work, keep Clay as the flagship/full-color glass preset and make the cool glass presets deliberately dustier: Plum should read purple rather than magenta, Ocean more sea-glass than blue, Sage grayed rather than green — Andrew rejected bright/saturated glass because it overpowers the page. *(2026-07)*
- Keep the marketing-site default accent at Rose unless Andrew explicitly asks to change the site default; Clay can lead the picker ordering without becoming the default — previous fallback logic would have silently changed the JS default when the array was reordered. *(2026-07)*
- On `/june`, OS chrome/icons should stay neutral while June-specific branding can be live-tinted: keep the root OS favicon static, mount the dynamic June favicon only under `app/june/layout.tsx`, and restore the OS icon on unmount — Andrew wanted OS to stay black/default while June carries the accent. *(2026-07)*
- Do not create one Apple touch icon per accent for June; iOS snapshots touch icons and Safari ignores runtime favicon swaps, so use at most one canonical June apple icon, preferably Clay/terracotta, when that asset is worth doing. *(2026-07)*

## Interaction Polish

- For the June accent picker, avoid hover/neighbor-repel retargeting while the open/close fan-out is still running; gate hover visuals during `opening` so mid-animation pointer movement does not inherit stagger delays and hitch. On coarse pointers disable the hover bloom entirely — touch taps fire synthetic pointerenter/focus BEFORE click, kicking the slow drift mid-selection, and iOS keeps that hover sticky. *(2026-07)*
- When changing June accents, avoid main-thread `clip-path` animation on the trigger fill while `--brand` repaints the page; use a transform-only masked disc/droplet and defer WebGL glass recolor until after the picker close animation — mobile Safari visibly snaps/janks otherwise. *(2026-07)*
- Andrew mash-tests every control on his phone; the site must stay smooth under rapid taps. The recurring lag sources, in order found: the 260ms `--brand` transition (every color-mix consumer recomputes per frame — snap it inside the mobile-perf block on touch), env re-bakes of the glass mark keyed by accent/theme with no deferral (debounce, halve bake resolution on coarse), and re-queued per-bead stagger delays on every flip (skip the cascade when a flip lands mid-flight). *(2026-07)*
- Tiny animated controls (accent droplet) must use retargeting transform TRANSITIONS, not keyframe animations — keyframes restart from scratch on each state flip and read as buggy under rapid taps. Two flourishes (mid-flight blur, a u→n meniscus) were built and reverted for this; don't re-propose motion-blur or shape-morph on the droplet. *(2026-07)*
- Small chrome controls (theme toggle, header icons) get the quiet icon-button family — bare glyph, `text-muted-foreground`, soft `foreground/6%` hover fill; Andrew rejected white-alpha borders/fills/backdrop-blur chrome ("rough" in dark mode). The mobile menu likewise: hierarchy by scale and position, no hairline dividers, serif reserved for the big section anchors with small sans for secondary links. *(2026-07)*
- Haptics tick on EVERY tap of the theming/menu chrome (picker trigger open+close, all beads including re-picking active, theme toggle, menu burger+✕) via the `HapticSwitch` overlay — Andrew asked for taps that were initially gated to "commits only" to tick too. *(2026-07)*

## Workflow

- Andrew reviews mobile work on the Vercel branch preview from his phone: after each change, commit, push, poll the commit status until the Vercel check passes, and only then ask him to look. He runs his own `next dev` for this workspace (Next 16 daemonizes and refuses a second instance) — never start another. *(2026-07)*
