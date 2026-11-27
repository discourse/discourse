---
name: discourse-glimmer-conversion
description: Convert classic Ember components to Glimmer in Discourse core, plugins, or themes. Use for requests to glimmerize a component or remove an ember/no-classic-components suppression.
---

# Convert a classic component to Glimmer

Preserve the component's module and resolver names, inputs and yields, rendered DOM and
behavior. Change the public contract where needed to replace classic bindings or wrapper
configuration. Apply [frontend conventions](../discourse-frontend-conventions/SKILL.md) to
the lines you touch. Keep unrelated cleanup out of the conversion.

For campaign target selection, batching, and PRs, see [PLAN.md](PLAN.md).

## Preflight

### Step 0: Scope

- Confirm the default export is a classic component by following its superclass. An
  `@ember/component` import can be for a built-in input, an identity check, or infrastructure.
- Convert a base with its in-tree subclasses. Treat select-kit and its subclasses as a
  separate migration. Inspect calls that pass the component itself to a helper or registry
  for assumptions about the classic receiver, including `get()` and callback `this`.
- Identify classic consumers of any native getter the conversion introduces. When a
  dependent-key chain crosses the getter, use `@dependentKeyCompat` or convert the consumer
  in the same change. Prefer leaves with no classic consumers.

### Step 1: Analyze

Run from the core checkout:

```bash
.skills/discourse-glimmer-conversion/scripts/analyze.sh path/to/component.gjs
```

The report gives leads. Read the component and its consumers to confirm args and defaults,
writes, the wrapper, lifecycle effects, subclasses, plugin patches, and coverage. For
out-of-tree targets pass their path. Set `CORE_DIR` for a different core checkout and
`ALL_THE_DIR` for external plugin and theme checkouts. See
[consumer discovery](references/consumers-and-tests.md#discovery) for paths the search can
miss. If a component has no call sites, check indirect and external consumers before
proposing deletion. A connector can be reached through its directory alone.

Summarize the conversion before editing. Identify each binding's owner, the wrapper and
lifecycle replacements, consumers to update or flag, and tests that exercise those paths.
Include whether the result can be template-only and whether it needs TypeScript.

### Choose the file type

Use `.gts` for ui-kit and where the directory or component family is mostly TypeScript.
Use `.gjs` elsewhere. Check the neighborhood in the analyzer output. Follow the
[TypeScript skill](../discourse-writing-typescript/SKILL.md) for the component signature,
TSDoc, type tests for ui-kit, and typing untyped dependencies. Base arg types on actual
callers, including external consumers. Outside ui-kit, use its scope guidance when the
port would require widespread typing work. See
[rename and importer checks](references/consumers-and-tests.md#extension-changes).

## Convert

1. **State and args.** Replace observers, computeds, action hashes, and writes to own
   state with native getters, methods, assignments, and tracked fields where needed.
   Switch the base import to `@glimmer/component`. Check callers for fields they
   override and preserve observable defaults. Declare formerly implicit services
   with `@service`. A native getter reading a plain legacy model field may need Ember's
   `get()` to track writes. When the class becomes empty, prefer a
   template-only export. Flag external subclass or prototype patch contracts before
   changing the export. See [imports](references/feature-mapping.md#imports),
   [args and state](references/feature-mapping.md#args),
   [observers](references/feature-mapping.md#observers), and
   [classic reactivity boundaries](references/feature-mapping.md#reactivity-boundary-with-classic-code).
2. **Wrapper and events.** Recreate the implicit wrapper, including the default `div`,
   its bindings, and `...attributes`. A tagless component stays a fragment. Caller
   attributes go after overridable defaults and before component-owned attributes.
   Classes merge either way. Use a fixed tag when callers agree and `dElement` when
   they choose different tags. Attach replacement listeners on the same element to receive
   bubbling events, and preserve the old effects of returning `false` where needed.
   See [wrapper and event recipes](references/feature-mapping.md#wrapper-element).
3. **Lifecycle.** Use Glimmer construction and destruction for instance work and
   `modifier()` for DOM setup and teardown. Keep mount-only reads separate from reactive
   effects and avoid adding `@ember/render-modifiers`. Preserve the original reset
   trigger, including hooks that kept local state when an arg cleared. Defer effects
   that must write state the current render already read. See [lifecycle recipes](references/feature-mapping.md#lifecycle).
4. **Data flow and consumers.** Trace direct and forwarded writes before choosing a
   callback or local state. A classic child can still write through a forwarded arg even
   after its parent becomes Glimmer. Update affected callers, tests, outlet connectors,
   and bundled patches in the conversion's repo. Report required edits in other repos
   for coordination. See [data-flow recipes](references/data-flow.md) and
   [consumer updates](references/consumers-and-tests.md#what-each-call-site-needs).

Keep pre-existing behavior unless a fix is as small as preserving it. Verify any bug you
report against the classic behavior and describe any fix separately.

## Verify

- Use the [test recipes](references/consumers-and-tests.md#tests) and
  [JS test skill](../discourse-writing-js-tests/SKILL.md). Exercise the wrapper contract,
  binding callbacks, reset or update behavior, and caller overrides that the conversion
  can break. Change the affected input on the same mounted instance to test reactivity.
  For new regression coverage, verify that removing the fix makes the test fail.
- Run relevant `bin/qunit` files by path, including plugin tests, and relevant system
  specs with `bin/rspec`. Treat analyzer matches as candidates and confirm they exercise
  the changed behavior. For DOM-heavy changes, exercise the real page.
- Run `scripts/self-args.py` from this skill on the converted files to flag template
  `@name` reads that match class members. Review the template reads directly as well.
- Run `bin/lint --fix` on the changed files after implementation and `pnpm lint:types`
  for `.gts`. Remove obsolete classic suppressions. Use the narrowest supported exception
  when preserving a specific contract requires one. The event and guarded-reset recipes
  show examples.

## Report

Start with **Breakages outside core**: each file in the external checkouts that the
conversion breaks (a subclass, prototype patch, template override, or read of classic
state), what breaks, and the exact edit, noting whether the edit also works on older core.
Write "None" only after a full sweep. Never fold breakages into other notes. Then
summarize interface and call-site changes, any pre-existing bug found and its disposition,
and any behavior difference. Explain a `.gjs` exception in a TypeScript neighborhood. List
verification results and any coverage gaps.
