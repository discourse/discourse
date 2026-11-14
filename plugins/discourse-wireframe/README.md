# discourse-wireframe

Drag-and-drop wireframe for the Discourse UI, built on the Blocks system. Lets permitted users compose Block Outlet layouts without writing code, with the resulting layouts persisted as theme fields.

This plugin is **experimental** and shipping in phases. See [`docs/PLAN.md`](docs/PLAN.md) for the architecture and phased rollout.

## Status

- **Phase 1 (current)**: read-only overlay — admins can enter editor mode on any page with a `<BlockOutlet>` and inspect the block tree, but cannot yet edit, drag, or save.

## Enabling

Two site settings gate the plugin:

- `wireframe_enabled` — master switch (default: off).
- `wireframe_allowed_groups` — groups whose members can use the editor (default: admins). Admins always have access regardless.

## Editable outlets

For now the editor only exposes the homepage outlet (`homepage-blocks`). Every other block outlet on the page renders as it does live — no boundary, chrome, drop target, outline row, issue, or draft. The allow-list lives in `admin/assets/javascripts/discourse/lib/editor-outlets.ts`; widening it is a change there only.

## Editor chrome

Every outlet and block in the editor carries a header strip (`components/editor/chrome/block-toolbar.gts`): its name on the left, status plus the gear and "…" actions menu on the right. The outlet strip always shows its publish state; a block strip shows a status only when something changes how it renders (hidden by conditions, a viewport or persona condition, a layout warning, a render error — see `lib/block-status.ts`). Settings and conditions stay in the inspector.

## Architecture

See [`docs/PLAN.md`](docs/PLAN.md) for full details. Highlights:

- Foundation: the existing Blocks system (`@block` decorator, `BlockOutlet`, `services/blocks.js`). Plugin Outlets are explicitly out of scope.
- Persistence (Phase 3+): a new `block_layout` ThemeField type — layouts ride the theme system's preview/baking/install/export infrastructure.
- Resolution: a fixed three-layer enum (`session-draft` / `theme` / `code-default`).
- Styling: layout-only. Block args expose presentation knobs; raw CSS stays in the theme editor.
