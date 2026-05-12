# UI-Kit conventions

Components, helpers, and modifiers under `frontend/discourse/app/ui-kit/` are the **public component contract** that core, plugins, and themes consume. Because the surface is wide and stable, the bar for files in this folder is higher than for app-internal code.

This document is the source of truth for what "hardened" means. The ESLint rule `local/require-ts-check` and the CI step `pnpm lint:types` enforce the mechanical parts; the rest is on reviewers.

## The bar

Every file in `ui-kit/`, `ui-kit/helpers/`, and `ui-kit/modifiers/` must have:

1. **`// @ts-check`** as the first line.
2. **A Glint Signature typedef** (components only; helpers/modifiers use `@param`/`@returns` instead).
3. **`@extends {Component<<Name>Signature>}`** on the class.
4. **A component-level JSDoc block** above the class — didactic, 3-6 sentences, with `@example` when args are non-obvious.
5. **DEBUG-time asserts** for required args, enum args, and mutually exclusive args.
6. **Tests**: one smoke test plus behavioral tests covering each meaningful `@arg` and observable state.

## 1. `// @ts-check`

Goes on line 1, no exceptions. Without it, TypeScript skips the file and your JSDoc types are decorative only.

```js
// @ts-check
import Component from "@glimmer/component";
```

The ESLint rule `local/require-ts-check` fails the build if it's missing. Files that pre-dated the rule are listed in the lint-to-the-future allowlist; touching one of those files means bringing it up to standard.

## 2. The Signature typedef

The Signature is what enables Glint to type-check `<DFoo @arg={{x}} />` invocations from the outside. Three blocks: `Args` (the args bag), `Element` (the rendered root element type, for `...attributes`), `Blocks` (named yields).

```js
/**
 * @typedef DFooSignature
 *
 * @property {object} Args
 *
 * /* Text *​/
 * @property {string} [Args.label] Translatable i18n key used as the visible label. Pass `translatedLabel` instead if the string is already translated.
 * @property {string} [Args.translatedLabel] Pre-translated visible label. Mutually exclusive with `label`.
 *
 * /* State *​/
 * @property {boolean} [Args.disabled] When true, the underlying control is disabled and click handlers do not fire.
 *
 * /* Callbacks *​/
 * @property {(value: string) => void} [Args.onChange] Invoked with the new value whenever the user edits the field.
 *
 * @property {HTMLInputElement} Element
 *
 * @property {object} Blocks
 * @property {[]} Blocks.default Optional contents rendered inside the field wrapper.
 */
```

Rules:

- **Every `@property` line gets a description**, not just a type. Junior-programmer readable, complete sentences with articles and prepositions.
- **Group args with `/* Section */` comments**. Never banner comments (`// ===...===`).
- **Optional args use brackets**: `[Args.label]`. Required args don't.
- **Element** is the actual rendered HTML element type (`HTMLButtonElement`, `HTMLInputElement`, `HTMLDivElement`...). This is what makes `...attributes` type-aware.
- **Blocks** lists named yields. Use `Blocks.default` for the unnamed yield, `Blocks.header`, `Blocks.footer`, etc. The value `[]` means the block receives no positional yield params.
- **`@extends`** the Component class so the Signature is actually wired up: `/** @extends {Component<DFooSignature>} */`.

### Template-only components

If the file is a template-only component (`const DFoo = <template>...</template>;` with no class), wire up the Signature with a `@type` annotation using `TOC` (template-only component) from `@ember/component/template-only`:

```js
// @ts-check

/**
 * @typedef DFooSignature
 * @property {object} Args
 * @property {string} [Args.title]
 * @property {HTMLDivElement} Element
 */

/** @type {import("@ember/component/template-only").TOC<DFooSignature>} */
const DFoo = <template>
  <div>{{@title}}</div>
</template>;

export default DFoo;
```

Template-only components have no constructor, so DEBUG asserts about arg shape are not available without converting to a class. Convert to a class only if asserts add real value — otherwise the Signature alone is enough.

Reference example: `d-button.gjs` (class component), `d-empty-state.gjs` (template-only).

## 3. Component-level JSDoc

A block above the class (or above the Signature) explaining the component's role, when to use it, and when not to. Aim for 3-6 sentences in a didactic tone. Include an `@example` when the args interact in non-obvious ways.

```js
/**
 * A primary text input for short, single-line values. Renders a native
 * `<input>` element, so all native HTML attributes flow through via
 * `...attributes`. Use this for free-form text. For controlled numeric or
 * date input, reach for `DNumberField`, `DDateInput`, or the corresponding
 * FormKit field.
 *
 * The value is two-way bound through `@onChange` rather than `(mut)` — pass
 * an action that updates your local state from the new value.
 *
 * @example
 * <DTextField @value={{this.name}} @onChange={{this.updateName}} />
 */
```

The component-level block describes the component as a whole. Per-arg notes belong inside the Signature `@property` descriptions, not in the component block.

## 4. DEBUG-time asserts

Use Ember's `assert` from `@ember/debug`. These messages are stripped from production builds by `ember-cli-terser`, so they're free at runtime in prod and loud during development.

```js
import { assert } from "@ember/debug";

// Required arg
assert("[d-text-field] @value is required", this.args.value !== undefined);

// Enum arg
const FLASH_TYPES = ["success", "error", "warning", "info"];
assert(
  `[d-flash-message] @type must be one of ${FLASH_TYPES.join(", ")}`,
  !this.args.type || FLASH_TYPES.includes(this.args.type)
);

// Mutually exclusive args
assert(
  "[d-button] pass either @label or @translatedLabel, not both",
  !(this.args.label && this.args.translatedLabel)
);

// Type narrowing on callbacks
assert(
  "[d-toggle-switch] @onChange must be a function",
  !this.args.onChange || typeof this.args.onChange === "function"
);
```

Message format: `\`[<component-name>] <what's wrong>\``. The bracketed prefix makes asserts grep-able and tells the developer immediately which component is unhappy.

**Prefer `assert` over `throw`** for contract violations. Use `throw` only when the failure must propagate to production (rare in UI components).

## 5. Smoke + behavioral tests

Every hardened component must have at least:

- **One smoke test** that renders the component with the minimum-required args and asserts the root element exists. The smoke test catches boot-time regressions (wrong import, syntax errors in Signature blocks, etc.) cheaply.
- **Behavioral tests** covering each meaningful `@arg` and each observable state (`@disabled`, `@isLoading`, each enum value, each callback, each named block).

Smoke-test template:

```js
// frontend/discourse/tests/integration/ui-kit/d-foo-test.gjs
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import DFoo from "discourse/ui-kit/d-foo";

module("Integration | ui-kit | DFoo", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the root element", async function (assert) {
    await render(<template><DFoo @value="hello" /></template>);
    assert.dom("input.d-foo").exists();
  });

  test("@disabled disables the underlying input", async function (assert) {
    await render(<template><DFoo @value="x" @disabled={{true}} /></template>);
    assert.dom("input.d-foo").isDisabled();
  });

  // ... one test per documented @arg / state.
});
```

For components used 50+ times in the codebase (`d-button`, `d-modal`, `d-text-field`, `d-page-header`), aim for ≥80% coverage of the documented Args surface. For smaller components, cover everything the Signature documents.

## Deprecating args

When an arg should still work but consumers should migrate off it, mark it deprecated with **JSDoc `@deprecated` inline on the Signature property**. IDE and type-checker pick this up and strike through the prop in usage sites:

```js
/**
 * @property {string} [Args.id] Native `id` attribute. @deprecated Pass `id` via `...attributes` instead.
 */
```

Do **not** add a runtime `deprecate()` call from `@ember/debug` as part of normal hardening — it generates console noise across every consumer and that's a separate decision. Only wire up runtime deprecations when explicitly asked.

## Constructor signature

When you need a constructor (for asserts or service-dependent init), use **named params**:

```js
constructor(owner, args) {
  super(owner, args);
  assert(...);
}
```

Avoid `constructor() { super(...arguments); }` — `arguments` doesn't have a tuple type and the spread fails strict TS checks. Avoid `constructor(...args) { super(...args); }` for the same reason: the rest-spread doesn't satisfy `super`'s `(owner, args)` signature.

## Glint escape hatches

When the **JS layer** is clean but the **template** trips Glint due to a dynamic root element (e.g. `<this.wrapperElement>`), a curried component yield, or an integration with a classic component, add a single comment at the top of the template:

```hbs
<template>
  {{! @glint-nocheck: <one-line reason> }}
  ...
</template>
```

This keeps the JSDoc Signature authoritative for consumers (because emitted `.d.ts` files are unaffected) while quieting fixable-later template noise. Use it sparingly and always include the reason — a future cleanup pass should be able to grep these out.

## Anti-patterns

- **Don't `throw` for arg validation**. Use `assert`. Throws cost production cycles and conflate developer errors with runtime errors.
- **Don't omit descriptions on `@property` lines**. A bare `@property {string} [Args.label]` tells the reader nothing the type alone didn't.
- **Don't use banner comments inside the Signature.** `/* Section */` only.
- **Don't accept `@onChange` and `(mut)` simultaneously.** Pick a callback contract and document it.
- **Don't make every component a Signature.** Helpers (`ui-kit/helpers/*.js`) and modifiers (`ui-kit/modifiers/*.js`) use plain JSDoc `@param`/`@returns` — they don't have a Glint Signature.
- **Don't add `@component name` to the JSDoc** — it's redundant with the filename.

## Verification commands

```bash
# Lint a single file (fixes formatting, surfaces require-ts-check):
bin/lint frontend/discourse/app/ui-kit/d-foo.gjs

# Type-check the whole project (fails on Signature mistakes):
pnpm lint:types

# Run the integration tests for a single component:
bin/qunit frontend/discourse/tests/integration/ui-kit/d-foo-test.gjs

# Run every ui-kit test:
bin/qunit frontend/discourse/tests/integration/ui-kit/
```

## Reference component

`frontend/discourse/app/ui-kit/d-button.gjs` is the live example of every requirement above. Copy its shape — the order of imports, the position of the Signature relative to the class, the assert placement — when adding a new component to `ui-kit/`.
