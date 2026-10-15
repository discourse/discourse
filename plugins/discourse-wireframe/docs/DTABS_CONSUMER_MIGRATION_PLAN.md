# DTabs consumer migration

## Goal and status

Exercise core's new `DTabs` API with the editor and the built-in Tabs block.
The dependency first landed in `f765d3e052`. After discourse/discourse#43108
merged upstream as `ed65dfa58f6`, `67020c15f0e` merged `main` into this branch.
The first four consumers use `tabs.Tab @key` and were committed separately in
`6d1f713553b`. The migration was restored after the lint-only commit
`8d1eb191936`; its safety stash
`263a28c98c8fe0c27c8086465ae893f19a84952c` is retained as a backup.
Visual validation remains pending as listed below.

The editor branch was clean at `02946cc715e`. The user approved merging the
dependency and its exact merge message. Consumer changes stay separate. Do not
push or change PR #40408's base without approval.

## Approach and invariants

Use `discourse/ui-kit/d-tabs` directly, with consumer-owned `@active` and
`@onActivate`, translated group labels, and declarative `tabs.Tab @key` panels.
Do not introduce an editor wrapper or import primitive internals.

The built-in Tabs block uses a custom header for its add button and drag
attributes. The panel switcher uses one to keep the collapse action outside its
vertical tablist. Inspector, image-source and publish tabs use the default header and
scoped BEM hooks. Group-local keys need no duplicate-HTML-ID lint suppression.

Preserve state ownership, inactive-panel destruction, conditional-tab fallbacks,
image URL drafts and uploader teardown, publication intent, detached Conditions,
and stable panel keys. DTabs owns ARIA pairing, roving focus and overflow. Let
overflow scroll instead of retaining the old wrapped tab rows. Remove duplicated
tab visual styles; retain scoped layout and editor integration hooks.

The outline status chips filter one tree and are not tabs. Fill/Fit and alignment
remain value controls.

The activity entries are a fifth consumer. `EditorPanelSwitcher` owns their
vertical tablist and associated panel content, while the shell supplies the
palette, outline and issues components. The rail service retains selection and
collapse preferences. Pass `undefined` as the active key when collapsed, unmount
inactive content and hide the persistent empty panel. Clicking the active tab
still collapses the rail. Arrow keys move focus without activation; the collapse
chevron is a separate button outside the tablist. The resize separator remains
a direct child of the shell grid, positioned at the panel/canvas seam.

## Implementation order

Paths below are relative to the repository root; anchors were checked against the
pre-migration checkout and will move during implementation.

1. Integrate the approved dependency, verifying its head again first.
2. Migrate publish Details/Changes at
   `plugins/discourse-wireframe/admin/assets/javascripts/discourse/components/editor/publish/publish-review-drawer.gts:487`.
   Preserve state outside the panels. Adapt the bounded flex/scroll chain to the
   new DTabs root and persistent panel so long Changes content cannot displace the
   footer. Do not merely retain the former body styles.
3. Migrate default and dark Upload/URL controls at
   `plugins/discourse-wireframe/admin/assets/javascripts/discourse/components/editor/inspector/fields/inspector-image-field.gts:715`
   and the corresponding dark group. Keep their selection and drafts independent.
   Use the default header. The image contextual menu measures the scoped
   `.d-tabs__tablist` to decide whether to offer the inspector shortcut. Put
   spacing on `.d-tabs__strip-controls`, not the inner scroller; this wrapper
   exists in both default and custom-header modes. No custom tablist class or
   new primitive argument is needed. Preserve dark-variant availability and
   blur commits.
4. Migrate Settings/Conditions/Raw JSON at
   `plugins/discourse-wireframe/admin/assets/javascripts/discourse/components/editor/inspector/inspector-panel.gts:395`.
   Preserve effective-selection fallbacks, Settings error treatment, detached
   Conditions stub, and the outer inspector scroll surface. Do not introduce a
   nested scroller solely to use DTabs' panel scroll reset.
5. Migrate the built-in Tabs block at
   `frontend/discourse/app/blocks/builtin/tabs.gts:223`.
   Use stable keyed declarations with rich label blocks. Place `header.Tablist`
   once, unconditionally, including the empty state. Put the append button beside
   it, outside the tablist. Preserve actual-tab and direct-child drop markers,
   active-only inline-edit markers, label DOM identity, added-panel reveal,
   reorder identity and deletion fallback. Replace old panel semantics with the
   primitive's single tabpanel. Adapt alignment to the overflow wrapper.

## Integration review corrections and verification

Source review found the following risks, not runtime-confirmed failures. For every
reproduced defect: add a regression, observe it fail, fix, observe it pass, and
check that a plausible weaker implementation fails too.

- Real Tabs block proxy dragging immediately after initial mount: deferred tab
  portals may arrive after the synchronous proxy-source scan. If reproduced,
  adapt discovery to mounted descendants rather than adding a timing delay.
- Canvas overflow arrows must receive pointer events and scroll without changing
  block selection. Keep any exception scoped to the Tabs navigation surface.
- Drag dwell must ignore clipped tabs while preserving center-third activation,
  edge insertion and existing strip auto-scroll. Include RTL and partial clipping.
- Requested image focus must survive deferred panel mounting, including an empty
  image and requests originating from Conditions/Raw. Consume a focus request only
  when its target is available if the race reproduces.
- Verify actual rich-label first-click selection, second-click editing, caret
  arrow handling, synthetic reveals, and panel insertion/removal/reordering.
- Manual arrow focus and Enter/Space activation must be tested separately from
  pointer selection. Preserve synthetic reveal without changing editor selection.
  Check destructive editor shortcuts while focus is on another tab; do not silently
  change selection for every activation to resolve keyboard-specific behavior.
- Keep only the active panel mounted. Check URL blur, Uppy destruction, draft
  retention, publication intent, detached Conditions, and conditional tab removal.
- Check independent nested tab groups, accessible labels, paired IDs, focus after
  removal, and narrow overflow. Replace selectors tied to old active classes with
  semantic state where appropriate.

Run focused core and plugin QUnit tests, workspace type validation, and lint on
changed files. Extend real-consumer tests rather than relying only on stand-in
markup fixtures. Run actual browser checks for drag, editing, overflow, focus and
the bounded publish footer. Use the implementation-time `discourse-visual-review`
pass across Foundation/Horizon, light/dark, narrow/default/wide inspector widths,
long translated labels and RTL. Source conformance review cannot establish visual
quality.

## Approval boundaries

- Dependency integration is complete using the approved merge strategy.
- Exact commit messages require approval before committing.
- Push and GitHub PR base changes require separate approval.
- If real-consumer tests expose a DTabs API gap, document the failing case before
  proposing a public API change. Do not modify the dependency's original branch.
- If keyboard activation requires a different editor-selection policy, surface
  that behavior explicitly rather than changing synthetic navigation semantics.

## Verification receipts and remaining work

- Panel-switcher follow-up: renamed the component to `EditorPanelSwitcher` and
  the system-test page object to `WireframePanelSwitcher`
  (`wireframe_panel_switcher.rb`). No `LeftRail` naming remains in these consumers.
- Panel-switcher, shell save-flow and rail-service coverage: 27 QUnit tests
  passed, seed `OksakAWU`. The tablist/panel-pairing regression was observed
  failing against the original toolbar before the migration. Changed-file lint
  passed. The focused plugin type check still reports 18 diagnostics outside
  the changed panel-switcher and shell files.
- Expanded and collapsed desktop screenshots were generated for both themes
  and color modes under `tmp/wireframe-panel-switcher-screenshots/compare.html`.
  The final screenshot-run summary was not retained, so these artifacts alone
  are not a receipt for a passing full matrix. Initial browser verification
  encountered stale stylesheet caches; moving `tmp/stylesheet-cache` and
  `tmp/cache/assets` aside caused the updated grid styles to regenerate.
- After merging main, adopting `@key` and fully rebuilding the frontend:
  all five focused system examples passed, seed `3892`, covering overflow,
  label editing, publish panels, image sources and inspector shortcuts.
  Changed-file lint passed, including the new system specs and fixture.
- Core DTabs, Tabs block, FloatKit lifecycle and segmented controls:
  62 QUnit tests passed, seed `vpsepZ44`.
- Affected editor consumers and integration: 79 QUnit tests passed, seed
  `vpsepZ44`, after the full frontend rebuild.
- Restart the frontend watcher after integrating a large upstream change.
  The old watcher reported a successful build but retained pre-merge core
  chunks alongside updated tests. The duplicate-key and held-touch tests failed
  against those chunks, then passed with the same seed after a full rebuild,
  without source changes.
- Desktop screenshot matrix: 13 examples passed, seed `49778`, across
  Foundation/Horizon and light/dark. Rendered-pixel review and remaining width
  checks are still pending; passing capture is not a visual verdict.
- After simplifying the image header: three browser flows passed, seed `29259`:
  source replacement/removal, inspector shortcut navigation, and dark variants.
- Workspace type resolution needs `preserveSymlinks` so imports within the local
  declaration package resolve through the plugin's `discourse` workspace alias.
  The post-merge repository-wide type check reports 18 Wireframe diagnostics
  outside the DTabs API changes: drag coordinates, inspector callback signatures,
  readonly block-part locks, abstract block constructors and the rich-text
  renderer signature. Events and Gamification also report 17 block-type
  diagnostics against published declarations. The type check is not green;
  do not suppress those errors.
