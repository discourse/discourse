# Coming next — inspector controls improvement roadmap

Roadmap for the inspector-controls UX initiative (best-in-class WYSIWYG layout
editor). Captures what shipped and the deferred phases so the sequence survives
a lost session. Detailed designs live in the linked plan docs; this file is the
index + the polish items that have no doc of their own yet.

## Shipped

- **P1 — Control-kit foundation.** Reusable dimension / stepper / segmented
  inspector controls; gap got direct numeric entry alongside the slider; fixed
  the rich-edit "[Image #N]" display pain. (commit `b7b88947c82`)
- **P2 — Contextual flex/grid args + unified icon control.** flex-wrap,
  justify-content, flex reverse, grid justify-items / align-content / dense
  added to the core layout block + inspector; one Lucide icon-segmented picker
  with a deterministic dropdown fallback; fixed the reverse-ordering drag bug.
  (commit `39dbde2e346`)
- **P3 — FormKit migration of the layout inspector.** `InspectorLayoutForm`
  became a proper FormKit form (every control a `form.Field` — custom slot for
  segmented/dimension/stepper, native toggle for reverse/dense), sharing one
  rendering / chrome / width / validation contract with the generic inspector.
  Uniform uppercase legends across all inspector forms; full-width control
  chain fixed (field → content → control); steppers compact. (commit
  `a16c2257963`)
- **P4 — Inline text editing (all three plan phases).** Click-on-selected →
  edit in place with bold / italic / link on a minimal ProseMirror schema,
  factored as the reusable `richInline` primitive. Shipped: the renderer +
  `marked-text` + `richInline` core validator type (`args.js`); the canvas
  `inline-edit-controller.gjs` + `inline-edit-state.js`; multi-field + Tab +
  container-arg (tabs-label) editing; Enter-split / Backspace-merge / arrow-key
  cross-block navigation. Nine core blocks declare `richInline`. See
  `INLINE_TEXT_EDITING_PLAN.md` for the design (historical — file paths predate
  the blocks→core relocation and the service rename).

## Deferred phases (recommended sequence)

### P5 — Inline-editing tail (deferred from P4)
Two real features the inline-editing design supports but didn't require:
- **Slash menu** — `/` while editing opens a block-insertion menu (heading,
  image, list, …), building on the Phase-3 split mechanism. No artifacts exist
  yet.
- **Editable inspector fallback** — the `rich-inline` inspector control is a
  read-only "Edit on the canvas" summary (`inspector-field.gjs` rich-inline
  branch); a fallback editable field would help headless / no-canvas editing.

### P6 — Token-aware color controls
Color args today are arbitrary hex strings (`wf-media-card.backgroundColor`,
etc.), which let authors produce off-palette themes. Replace the raw hex inputs
with a semantic design-token picker that plugs into core's design-token catalog
(primitives → `--sys-*` → component tokens). Net-new control type; touches the
persisted schema for color args (becomes a contract). **Full design:
`RESPONSIVE_AND_TOKENS_PLAN.md` (Direction 2 — design tokens).**

### P7 — Responsive per-arg overrides
Let the same block adapt per breakpoint instead of forcing a parallel layout
per viewport. Controls gain a breakpoint switcher; per-arg overrides layer on
top of CSS container queries (the default zero-author adaptation). Most
architectural — changes the persisted arg shape, so get it right before
shipping. **Full design: `RESPONSIVE_AND_TOKENS_PLAN.md` (Direction 1 —
responsive).**

### P8 — Polish pass (no dedicated doc — captured here)
Low-risk consistency sweep, no new capability:
- Give `align-self`'s `auto` option an icon so its row is all-icon like the
  alignment control (user chose to keep it as text for now;
  `VALID_ALIGN_SELF = ["auto", …]` in `frontend/discourse/app/blocks/builtin/layout.gjs`).
- Verify the now-uniform uppercase legends (`.wireframe-inspector-form
  .form-kit__container-title`) read well across **every** block's inspector,
  not just layout — the P3 change widened that styling to all inspector forms.
- Sweep the other blocks' inspectors to confirm they use the shared
  segmented/dimension/stepper controls consistently (no leftover bare inputs
  where an icon-segmented control fits).

## Rationale for the order
P6 (token-aware color) is the highest-value remaining feature: net-new control
type, contained to color args, big visual payoff. P5 (inline-editing tail) is
optional polish on an already-shipped feature — do the editable inspector
fallback if headless editing matters; the slash menu is a larger separate
feature. P7 (responsive) is last among features: most architectural,
persisted-schema contract. P8 is opportunistic — fold into whichever phase
touches the area.

Each phase ships green (`bin/lint`, `pnpm build`, `bin/qunit`) and nothing lands
on the production render path without a passing test.
