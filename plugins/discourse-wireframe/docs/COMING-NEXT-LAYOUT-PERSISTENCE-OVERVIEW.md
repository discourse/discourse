# Block-layout persistence: editing, saving & publishing (overview)

## Context

The block editor lets admins edit `<BlockOutlet>` layouts. Those layouts are persisted through
Discourse's theme layer (`block_layout` ThemeFields), and the render pipeline that resolves them
runs on **every production page**. The current persistence story has accumulated problems at the
intersection of the three customization channels users mix freely — plugins, themes, and
theme-components:

- **Saving is instantly live** — there is no draft/publish gate; a save bakes the field and
  MessageBus-broadcasts it to every visitor (`save_block_layout.rb:171-190`).
- **The editor flattens multi-source layouts** — `enter()` clones only the single *winning*
  layer (`wireframe.js` `readResolvedLayout` → `:2364`) and saves the whole blob to one theme,
  so a layout that came from a plugin gets copied wholesale into a theme.
- **A saved edit permanently shadows its source** — the theme layer outranks `code-default`
  forever, so a plugin/theme update never reaches the user, and no provenance is recorded.
- **`api.renderBlocks` is the lowest priority** — a plugin/theme can't ship an authoritative
  layout.
- **Git themes are handled silently** — edits are redirected to an auto-created
  `<name>-customizations` child component the admin is never told about
  (`save_block_layout.rb:85-127`).
- **Concurrent admins clobber each other** — the save path has no version check.
- **A production-only data-loss bug** — the save path reads layout state through a DEBUG-only
  accessor; in a real (`!DEBUG`) build it reads `null` and **saves an empty layout, wiping the
  existing one** (see P0).

This redesign makes the editing → saving → publishing story coherent and safe. It is split into
five ordered phases (P0–P4), each shipped and verified independently. Each phase has its own
`COMING-NEXT-LAYOUT-PERSISTENCE-P*.md` doc with full `file:line` detail.

## Authoritative decisions (confirmed with the team)

1. **Programmatic layouts carry an `overridable` flag.** `api.renderBlocks` is **source-agnostic**
   (plugins *and* theme JS use it). The flag is **editable seed by default** (`overridable:true`)
   and opt-in `overridable:false` **locks** a layout (authoritative, editor read-only). The
   default lives in one constant (`CODE_LAYOUT_OVERRIDABLE_BY_DEFAULT = true`) so the global
   stance is trivially flippable later. "Seed" *is* the overridable state; "locked" *is* the
   non-overridable state — one switch, two behaviours.
2. **Theme-vs-theme ownership = first/parent wins.** The owner of an outlet is the theme with the
   **minimum `Theme.transform_ids` stack-rank** that ships a layout for it; later themes /
   components cannot silently override it. This realigns block layouts with Discourse's general
   field convention (`theme.rb:639` uses the parent theme for most fields), reversing today's
   tail/component-wins behaviour.
3. **Drafts + an explicit Publish ship in v1.** Drafts are per-user, stored in a **dedicated
   `block_layout_drafts` table**, never live. Publish writes the live field and broadcasts.
   A **stale-publish 409 guard** keyed on a ThemeField version token (hash of `value_baked`)
   prevents silent multi-admin clobber.
4. **The editor is page-scoped.** The user edits "a page area" and never picks a theme / layer /
   component. The editor resolves each outlet's owning theme and publishes there automatically.
5. **Git themes: no live write.** The auto child-component overlay is removed. The editor never
   writes a git theme's live field — mirroring core, which hides the CSS/HTML edit affordance for
   git themes (`admin-customize-themes/show/index.gjs:273-275`). Edits live in the per-user draft;
   the paths to make them real are **Export** (commit `block_layouts/<outlet>.json` to the repo)
   or **Duplicate to an editable theme** (a full, non-git clone — *loses upstream updates*, stated
   up front in a confirm dialog).

## Resolution chain (target, after P1)

```
1. Locked programmatic layout (overridable:false)  → wins (authoritative; outlet read-only)
2. SESSION_DRAFT                                    → wins (live editing)
3. Persisted ThemeField for the OWNER theme        → wins (owner = MIN transform_ids stack-rank with a field)
4. Overridable programmatic seed (overridable:true)→ wins (in-code default)
5. → undefined
```

## States and verbs (the user-facing story, after P3)

The user edits *a page area*. Per outlet there are three states plus an editing badge:

- **Locked** — read-only; owned by a locked programmatic layout ("Provided by `<source>`").
- **Default** — renders an editable seed; no admin edit yet.
- **Published** — the admin's edit is live.
- **Editing (unsaved changes)** — orthogonal badge while a draft is dirty.

Four core verbs (plus two git-only paths): **Save draft** (private, never live), **Publish**
(live + broadcast), **Reset to default** (delete the live field), **Discard changes** (drop the
draft). On a git-owned outlet, **Publish is disabled** and replaced by **Export** + **Duplicate
to an editable theme**. The word "live" appears only on Publish.

## Issues and the phase that fixes each

| # | Issue | Fixed in |
|---|---|---|
| 🔴 I13 | DEBUG-gated read accessors → prod reads `null` and **save wipes layouts** | **P0** |
| 🔴 I1 | Save instantly live; no draft/publish gate | P2 + P3 |
| 🔴 I2 / I3 | Editor flattens multi-source; saved edit shadows source; no provenance | P1 |
| 🟠 I4 | `renderBlocks` lowest priority; can't be authoritative | P1 |
| 🔴 I5 | Git persistence silent/confusing (hidden child overlay) | P2 (remove) / P4 (replace) |
| 🟠 I6 | No reset/delete endpoint | P2 |
| 🟠 I7 | Concurrent admins: silent last-write-wins | P2 (409 guard) |
| 🟠 I8 | Theme last/component silently wins; diverges from core | P1 (owner/first) |
| 🟠 I9 | Orphaned / by-name re-adopted `-customizations` child | P2 (redirect removed) |
| 🟡 I10 | Orphaned blocks (disabled plugin) silently dropped | P3 (surfaced) |
| 🟡 I11 | Two plugins on one outlet = hard throw | P1 (collision matrix) |
| 🟡 I12 | Diff/override persistence blocked (no persisted stable id) | out of scope (below) |

## Phase map (ordered; each depends on the prior)

- **P0** — Fix the production read/save bug. Precondition; ship first and independently.
- **P1** — Resolution model + `overridable` flag + provenance (core `block-outlet.gjs`).
- **P2** — Drafts/Publish/Reset server + the `block_layout_drafts` table + 409 guard; remove the
  git redirect.
- **P3** — Editor UX: page-scoped targeting, states, verbs, conflict/stale modals.
- **P4** — Git flow: single-outlet Export + Duplicate-to-editable-theme (full clone).

## Cross-phase coordination

- **i18n** (`COMING-NEXT-BLOCK-LAYOUT-I18N.md`): P1 must keep `entry.themeId` stamped on theme
  entries (`block-outlet.gjs:618-619`) and must not collide with the i18n render-context arg
  (`__themeId`); the i18n plan threads `themeId` through the render context and re-stamps it on the
  `SESSION_DRAFT` layer. Land P1 before the i18n work builds on the stamped entry.
- **Per-theme metadata preload** (added in P1) is the single source of truth for per-outlet owner
  *name* and *git-status*, consumed by P3 (page-scoped targeting) and P4 (git-awareness). The
  editor never infers git-status from an entry-path URL param.
- **No data migration anywhere.** The plugin is pre-release; removing the git redirect (P2) needs
  only code + spec changes. Stray `-customizations` components from dev are harmless and can be
  deleted by hand.
- **Deferred follow-up:** emit an explicit `stack_index` per layout row from
  `theme_block_layouts_json` (and the `SaveBlockLayout` publish payload) to delete the client-side
  rank inference P1 introduces. Recommended after P1/P2.

## Out of scope (documented)

- **Diff/override persistence** (persist only the user's deltas so plugin/theme updates flow
  through except where explicitly changed). This is the ideal long-term answer to flattening
  (I2/I3), and the composite `overrides` system proves the id/path-keyed merge mechanism works —
  but it is **blocked on a persisted stable per-entry identity** that does not exist:
  `__stableKey` is minted client-side and stripped on save; `entry.id` is persisted but optional.
  Pursue only after introducing a persisted stable entry id (validated like composite part ids),
  bumping `BLOCK_LAYOUT_SCHEMA_VERSION`, and migrating wholesale → override documents.

## Verification (whole effort)

Each phase: `bin/rspec` (server), `bin/qunit` (JS), `bin/lint --fix --recent`, and a manual
end-to-end pass via the `discourse-dev` MCP across **a non-git theme, a git theme, a multi-theme
stack, and a locked outlet**. P0 ships first and on its own — it is a live data-loss fix. Run
`/discourse-code-conventions` on staged JS/Glimmer before any commit.
