---
name: unicode-animations
description: |
  Drop-in unicode spinner animations for loading states, progress indicators, and
  async-work feedback in UI, CLI, or terminal output. Use when the user asks for a
  spinner, loader, loading indicator, progress animation, "show something is happening",
  busy state, or any text-based animated feedback during async work. Covers React
  components, browser DOM, Node CLI scripts, and TUIs. Triggers on "add a spinner",
  "loading state", "loading indicator", "progress spinner", "show loading", "async
  feedback", "busy state", "build progress", "CLI spinner", "terminal animation".
---

# unicode-animations

A zero-dependency npm package providing **18 unicode spinner animations as raw frame
data**. Works everywhere: React, plain browser DOM, Node CLI, TUI. Each spinner is just
`{ frames: string[], interval: number }` — no framework lock-in, ~1 KB per spinner.

Source: [gunnargray-dev/unicode-animations](https://github.com/gunnargray-dev/unicode-animations).

## When to suggest

- The user wants a loading indicator, spinner, or progress animation in a UI.
- The user is writing a CLI / Node script that does async work and wants visible feedback.
- A long-running step would benefit from an animated cursor-style indicator rather than
  a static "Loading…" string.
- The user wants something more distinctive than the default Material/HeroIcons spinner.

Prefer this over hand-rolling CSS keyframe spinners when the project is already monospace,
terminal-themed, or wants a textual aesthetic.

## Install

```bash
npm install unicode-animations
```

## The 18 spinners

`braille`, `braillewave`, `dna`, `scan`, `rain`, `scanline`, `pulse`, `snake`, `sparkle`,
`cascade`, `columns`, `orbit`, `breathe`, `waverows`, `checkerboard`, `helix`, `fillsweep`,
`diagswipe`.

Preview any of them live before choosing:

```bash
npx unicode-animations            # cycle through all in terminal
npx unicode-animations helix      # preview one
npx unicode-animations --web      # open browser demo
npx unicode-animations --list
```

Rough mental model when picking one:
- **`braille`** — classic dots; safe default, looks at home in CLIs (matches `ora`).
- **`pulse`, `breathe`** — calm, ambient. Good for background sync.
- **`scan`, `scanline`, `fillsweep`, `diagswipe`** — sweep-style; feels like "processing".
- **`helix`, `dna`, `orbit`** — rotational; feels like "computing / generating".
- **`cascade`, `rain`, `waverows`, `columns`** — directional flow; good for streams/loads.
- **`sparkle`, `checkerboard`, `snake`** — playful; use sparingly.

## Usage patterns

### React component

The canonical "AI-Elements-style" drop-in. Tree-shake by importing only the spinner you
need:

```tsx
import { useState, useEffect } from 'react';
import spinners from 'unicode-animations';
// or, smaller bundle:
// import braille from 'unicode-animations/braille';

export function Spinner({ name = 'braille', children }: { name?: string; children?: React.ReactNode }) {
  const [frame, setFrame] = useState(0);
  const s = spinners[name];

  useEffect(() => {
    const t = setInterval(() => setFrame(f => (f + 1) % s.frames.length), s.interval);
    return () => clearInterval(t);
  }, [name]);

  return (
    <span style={{ fontFamily: 'ui-monospace, monospace', fontVariantNumeric: 'tabular-nums' }}>
      {s.frames[frame]} {children}
    </span>
  );
}

// <Spinner name="helix">Generating response…</Spinner>
```

Notes when wiring this up:
- Use a monospace font; otherwise frame width changes and the surrounding text jitters.
- `tabular-nums` keeps adjacent digits stable (good if the spinner sits next to a counter).
- Stop the interval on unmount (the `return` in `useEffect`) — leaving it running leaks.
- Set `aria-live="polite"` on the parent if it announces progress to assistive tech, or
  hide the spinner from screen readers with `aria-hidden="true"` and label the action
  separately.

### Browser (plain DOM)

```js
import spinners from 'unicode-animations';

const el = document.getElementById('status');
const { frames, interval } = spinners.orbit;
let i = 0;

const t = setInterval(() => {
  el.textContent = `${frames[i++ % frames.length]} Syncing…`;
}, interval);

await sync();
clearInterval(t);
el.textContent = '✔ Synced.';
```

### Node CLI — reusable helper

```js
import spinners from 'unicode-animations';

function createSpinner(msg, name = 'braille') {
  const { frames, interval } = spinners[name];
  let i = 0, text = msg;
  const t = setInterval(() => {
    process.stdout.write(`\r\x1B[2K  ${frames[i++ % frames.length]} ${text}`);
  }, interval);
  return {
    update(m) { text = m; },
    stop(m)   { clearInterval(t); process.stdout.write(`\r\x1B[2K  ✔ ${m}\n`); },
  };
}

const s = createSpinner('Connecting…');
const db = await connect();
s.update('Running migrations…');
await db.migrate(migrations);
s.stop('Database ready.');
```

### Multi-step pipeline (one spinner per step)

```js
async function step(label, fn, name = 'braille') {
  const { frames, interval } = spinners[name];
  let i = 0;
  const t = setInterval(() => process.stdout.write(`\r\x1B[2K  ${frames[i++ % frames.length]} ${label}`), interval);
  const out = await fn();
  clearInterval(t);
  process.stdout.write(`\r\x1B[2K  ✔ ${label}\n`);
  return out;
}

await step('Linting…',  lint,    'scan');
await step('Testing…',  test,    'helix');
await step('Building…', build,   'cascade');
await step('Publishing…', publish, 'braille');
```

## When NOT to use

- The project already uses `ora` (Node) or a polished CSS spinner pack and consistency
  matters more than novelty.
- The target environment is not monospace (proportional fonts make frames jitter).
- For a very brief operation (<200 ms) — show nothing, or skip straight to the result.
