# Schema DSL Spec Trim Plan

## Goals

- Keep strong coverage for behavior that can break migrations in production.
- Reduce maintenance cost from highly granular unit specs.
- Shift coverage toward contract/integration specs at module boundaries.

## Current Problem

The DSL test suite has many small, overlapping unit tests across builders, resolver, validator, and differ. This creates high review and refactor overhead while still missing important cross-component failures (for example plugin-name normalization mismatches).

## Keep (High Signal)

- `migrations/spec/lib/database/schema/dsl/generator_spec.rb`
- `migrations/spec/lib/database/schema/dsl/validator_spec.rb` (reduced)
- `migrations/spec/lib/database/schema/dsl/schema_resolver_spec.rb` (reduced)
- `migrations/spec/lib/database/schema/dsl/differ_spec.rb` (reduced)
- `migrations/spec/lib/database/schema/dsl/plugin_manifest_spec.rb`
- `migrations/spec/lib/cli/schema_sub_command_spec.rb` (focused on command behavior, not internals)

## Reduce / Merge

1. Merge small builder-only specs into one contract file.
   - Merge:
     - `migrations/spec/lib/database/schema/dsl/config_builder_spec.rb`
     - `migrations/spec/lib/database/schema/dsl/conventions_builder_spec.rb`
     - `migrations/spec/lib/database/schema/dsl/enum_builder_spec.rb`
     - `migrations/spec/lib/database/schema/dsl/ignored_builder_spec.rb`
     - `migrations/spec/lib/database/schema/dsl/table_builder_spec.rb`
   - Into:
     - `migrations/spec/lib/database/schema/dsl/dsl_definition_contract_spec.rb`

2. Collapse registry/loader micro-tests into one loader contract spec.
   - Replace:
     - `migrations/spec/lib/database/schema/dsl/registry_spec.rb`
     - `migrations/spec/lib/database/schema/dsl/loader_spec.rb`
   - With:
     - `migrations/spec/lib/database/schema/dsl/loader_contract_spec.rb`

3. Reduce duplication between `validator_spec` and `differ_spec`.
   - Keep in `validator_spec`:
     - Validation failures and diagnostics.
   - Keep in `differ_spec`:
     - Diff classification and output categories.
   - Remove duplicate setup permutations tested identically in both files.

4. Reduce `schema_resolver_spec` to representative transformations.
   - Keep one test per transformation type:
     - include/include_all/ignore behavior
     - rename/type overrides
     - enum resolution
     - primary key mapping
     - index/constraint projection
   - Remove repetitive datatype/nullability permutations already validated elsewhere.

## Add (Critical Missing Coverage)

- One integration spec covering plugin-name normalization end-to-end:
  - ignored plugin declared with underscore name
  - manifest using hyphenated plugin key
  - validator + differ both behave correctly

- One integration spec for stale manifest regeneration failure path:
  - stale manifest
  - regeneration failure
  - command fails clearly (no silent fallback)

## Proposed Rollout

1. Phase 1: Introduce merged contract specs while keeping existing files.
2. Phase 2: Delete superseded micro-spec files once contracts pass.
3. Phase 3: Enforce a rule: new tests should target public behavior, not private helper branches.

## Success Criteria

- Fewer total spec files and lines in DSL test area.
- No loss in behavioral coverage of CLI + validator + resolver + generator workflows.
- Faster refactors with fewer brittle spec updates.
