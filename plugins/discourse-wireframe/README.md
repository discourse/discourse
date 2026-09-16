# discourse-wireframe

Drag-and-drop wireframe for the Discourse UI, built on the Blocks system. Lets permitted users compose Block Outlet layouts without writing code, with the resulting layouts persisted as theme fields.

This plugin is **experimental** and shipping in phases. See [`docs/PLAN.md`](docs/PLAN.md) for the architecture and phased rollout.

## Status

- **Phase 1 (current)**: read-only overlay — admins can enter editor mode on any page with a `<BlockOutlet>` and inspect the block tree, but cannot yet edit, drag, or save.

## Enabling

Two site settings gate the plugin:

- `wireframe_enabled` — master switch (default: off).
- `wireframe_allowed_groups` — groups whose members can use the editor (default: admins). Admins always have access regardless.

## Architecture

See [`docs/PLAN.md`](docs/PLAN.md) for full details. Highlights:

- Foundation: the existing Blocks system (`@block` decorator, `BlockOutlet`, `services/blocks.js`). Plugin Outlets are explicitly out of scope.
- Persistence (Phase 3+): a new `block_layout` ThemeField type — layouts ride the theme system's preview/baking/install/export infrastructure.
- Resolution: a fixed three-layer enum (`session-draft` / `theme` / `code-default`).
- Styling: layout-only. Block args expose presentation knobs; raw CSS stays in the theme editor.
