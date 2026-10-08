# Phase 2 — Extension API GA + tooling + first high-traffic migrations

**Goal:** the plugin extension API is finalized and documented, migration tooling
exists, and the highest-traffic pickers move behind their old tags.

See RFC: *Extension model*, *Legacy `modifySelectKit` bridge*, *Migration strategy*.

## Tasks

- ☐ Finalize `select-content` / `select-on-change` transformers + the `modifySelectKit`
  bridge (all fidelity requirements); register the deprecation ids; wire
  `discourse-deprecation-collector` (per-use + per-component telemetry).
- ☐ Build the codemod harness (`ember-template-recast` + jscodeshift): both import
  specifiers + the runtime arg-alias table; `@options={{hash}}` → flat args; static
  `@content` → `@load`.
- ☐ Migrate the highest-traffic pickers behind facades under old tags (`combo-box`,
  `category-chooser`).
- ☐ Migrate FormKit's `select` control + the ~12 native `<select>` (`DNativeSelect`)
  consumers; deprecate `DNativeSelect`. Full FormKit integration (validation / `name` /
  form submit / `aria-invalid`).

## Exit criteria

- Extension API documented + GA; codemod runs clean on core.
- Deprecation telemetry live.
- FormKit `select` + native consumers migrated.
