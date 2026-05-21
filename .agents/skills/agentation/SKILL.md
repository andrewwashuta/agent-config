---
name: agentation
description: Install and set up Agentation (v2.x) visual feedback tool for AI coding agents. Detects package manager, installs the npm package, adds the component to the app, and optionally configures the MCP server for direct agent integration.
---

# Agentation Setup (v2.x)

Install and configure [Agentation](https://agentation.com) — a visual feedback tool that lets you click elements on your page, add notes, and copy structured output that helps AI coding agents find the exact code you're referring to.

## Steps

1. **Detect the package manager** in the current project (look for `bun.lock` → bun, `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `package-lock.json` or fallback → npm).

2. **Install the package as a dev dependency**:
   ```bash
   <detected-pm> install agentation -D
   # e.g.: npm install agentation -D
   # e.g.: bun add agentation -d
   ```

3. **Add the `<Agentation />` component** to the app's root layout or entry point — it should render alongside the main app content, NOT wrap it:
   ```tsx
   import { Agentation } from 'agentation';

   // Add AFTER (sibling to) your app content, inside a fragment or wrapper:
   <>
     <YourApp />
     {process.env.NODE_ENV === 'development' && <Agentation />}
   </>
   ```

   - For **Next.js**: Add to `app/layout.tsx` inside the `<body>` tag, after `{children}`
   - For **Vite/CRA**: Add to `src/App.tsx` or `src/main.tsx`
   - For **Remix**: Add to `app/root.tsx`
   - Only render in development — wrap in `process.env.NODE_ENV === 'development'` or equivalent

4. **Set up the MCP server** (optional but recommended) — this lets agents like Claude Code receive annotations directly, bypassing copy-paste:
   ```bash
   # Auto-detect installed agents and configure:
   npx add-mcp "npx -y agentation-mcp server"

   # Or for Claude Code specifically:
   claude mcp add agentation -- npx agentation-mcp server

   # Or use the interactive wizard:
   npx agentation-mcp init
   ```
   The MCP server auto-starts when the agent launches (uses npx, no global install needed). It runs an HTTP server on port 4747 (for the browser toolbar) and an MCP server via stdio (for agents), sharing the same data store.

5. **Confirm** the setup by telling the user to run their dev server and look for the Agentation toolbar in the bottom-right corner.

## Key Details

- React 18+ required
- Zero runtime dependencies
- Desktop browsers only
- Dark/light mode — automatically matches user preference
- The toolbar appears in the bottom-right corner — click to activate, then click any element to annotate

## Annotation Capabilities

- **Click to annotate** — automatic selector identification
- **Text selection** — annotate specific content by selecting text
- **Multi-select** — drag to select multiple elements simultaneously
- **Area selection** — drag to annotate any region, including empty space
- **Animation pause** — freeze all animations (CSS, JS, videos) to capture specific states
- **Structured output** — copy markdown with selectors, positions, and context

## Output Modes

Four output modes control how much detail is included when copying annotations:

- **Compact** — just the selector and your note
- **Standard** — adds position and selected text
- **Detailed** — includes bounding boxes and nearby context
- **Forensic** — captures everything including computed styles

## MCP Integration (v2.0+)

The `agentation-mcp` package provides an MCP server so agents can fetch current annotations, acknowledge them, ask follow-up questions, resolve issues with summaries, or dismiss feedback with reasons — all without copy-paste. Just annotate and talk to your agent.
