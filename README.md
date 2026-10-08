# Flow Tracker

An [Omarchy](https://omarchy.org/) shell **overlay plugin** that renders an
interactive flow-chart canvas from `flow.json`, compiled by
[`flowc`](../flowc) from a repo's `flow.md`.

Plugin id: `io.github.madddtone.flow-tracker`

## What it does

- Adds a **bar icon** (sitemap glyph) in the right section; click it to open
  the canvas. Also bound to `SUPER + CTRL + G`.
- Draws the whole flow with a deterministic layered layout.
- **Table nodes** (`type: table`) render a header + columns with PK/FK badges —
  the first 5 key columns on the node, all of them in the inspector. Handy for
  data-flow diagrams.
- **Click a node** to trace its routes: immediate next steps are highlighted,
  everything else dims. Press `d` to widen the trace to the full downstream
  subgraph. Upstream (ancestor) nodes stay faintly lit for orientation.
- **Inspector popup** shows the selected node's attributes: type, actor, owner,
  status, priority, code reference, tags, subflow, plus the prose sections
  (Logic, Requirements, Prerequisites, Inputs, Outputs, Failure Modes, Notes).
- **Project switcher** — press `p` (or click the *Projects* chip) to list every
  project in the central store and switch between them without leaving the canvas.
- **Subflow drill-in** — a `type: subflow` node shows a `↳ N` badge and opens
  its nested flow on the same canvas, with a breadcrumb to navigate back.
- Edge conditions/labels appear on the traced route.
- Zoom (scroll), pan (drag), fit (`f`), search (`/`).
- Live: reloads when `flowc watch` recompiles `flow.json`, and when the active
  project changes.

## Requirements

- `flowc` for producing `flow.json` and the active-flow pointer:
  `~/Work/projects/flowc` (or a release binary on `PATH`).

## Install

```sh
omarchy plugin add <this-repo-url> --section right
```

The plugin declares both `overlay` and `bar-widget` kinds, so enabling it as a
bar widget also makes the overlay loadable. For local development, place the
directory at `~/.config/omarchy/plugins/io.github.madddtone.flow-tracker/`, then:

```sh
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.madddtone.flow-tracker --section right
```

> A third-party **bar widget's** code is only re-read on `omarchy restart shell`
> (overlay code changes do hot-reload, but `keepLoaded` overlays also need a
> shell restart to be replaced).

## Use

```sh
flowc new "Checkout Service" --repo ~/code/checkout
flowc prompt checkout-service   # hand this to your AI, or edit it yourself
flowc open checkout-service     # compiles, sets active, summons the canvas
```

Switch projects from inside the canvas with `p`, or from the shell with
`flowc use <project>`.

Or bind a key in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + CTRL + G", "Flow Tracker", "omarchy-shell shell toggle io.github.madddtone.flow-tracker")
```

## Controls

| Key / input | Action |
|---|---|
| click node | select + trace its routes |
| double-click / Enter on a `subflow` node | drill into that subflow |
| Backspace / Esc | go back up a subflow (then clear / close) |
| `←` / `↑` | step to a predecessor |
| `→` / `↓` | step to a successor |
| `d` | toggle immediate vs full-downstream trace |
| `p` | open the project switcher |
| scroll | zoom at cursor |
| drag | pan |
| `f` | fit to screen |
| `0` | reset zoom/pan |
| `/` | search nodes (id, title, actor, tag) |
| `+` / `-` | zoom in / out |
| `esc` | clear selection, then close |
| `q` | close |

## Data flow

```
projects/<id>/flow.md  --flowc compile-->  projects/<id>/flow.json
     (central store,            ^                    |
      authored by AI/human)     |                    v
                          flowc watch         canvas overlay reads it

~/.local/share/flow-tracker/index.json        project list (press p)
~/.local/state/flow-tracker/active.json       active project (+ last error)
```

`flowc open`/`use` write `active.json`; the overlay watches it and swaps the
canvas. Switching from the canvas runs `flowc use <project>` for you. If a
compile fails, the error is recorded in `active.json` and shown as a banner.

## Files

- `manifest.json` — Omarchy shell plugin manifest (`overlay`, `keepLoaded`)
- `FlowTracker.qml` — window, data loading, pan/zoom, keyboard, IPC
- `FlowModel.js` — graph traversal + edge geometry helpers
- `NodeItem.qml`, `EdgeItem.qml`, `Inspector.qml` — rendering components

## License

MIT
