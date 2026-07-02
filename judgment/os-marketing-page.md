# os-marketing-page judgment

## June Accent Theming

- For June accent work, keep Clay as the flagship/full-color glass preset and make the cool glass presets deliberately dustier: Plum should read purple rather than magenta, Ocean more sea-glass than blue, Sage grayed rather than green — Andrew rejected bright/saturated glass because it overpowers the page. *(2026-07)*
- Keep the marketing-site default accent at Rose unless Andrew explicitly asks to change the site default; Clay can lead the picker ordering without becoming the default — previous fallback logic would have silently changed the JS default when the array was reordered. *(2026-07)*
- On `/june`, OS chrome/icons should stay neutral while June-specific branding can be live-tinted: keep the root OS favicon static, mount the dynamic June favicon only under `app/june/layout.tsx`, and restore the OS icon on unmount — Andrew wanted OS to stay black/default while June carries the accent. *(2026-07)*
- Do not create one Apple touch icon per accent for June; iOS snapshots touch icons and Safari ignores runtime favicon swaps, so use at most one canonical June apple icon, preferably Clay/terracotta, when that asset is worth doing. *(2026-07)*

## Interaction Polish

- For the June accent picker, avoid hover/neighbor-repel retargeting while the open/close fan-out is still running; gate hover visuals during `opening` so mid-animation pointer movement does not inherit stagger delays and hitch. *(2026-07)*
- When changing June accents, avoid main-thread `clip-path` animation on the trigger fill while `--brand` repaints the page; use a transform-only masked disc/droplet and defer WebGL glass recolor until after the picker close animation — mobile Safari visibly snaps/janks otherwise. *(2026-07)*
