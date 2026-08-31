---
name: discourse-writing-typescript
description: Write TypeScript for Discourse core, plugins, and themes. Use when authoring new .ts/.gts files (components, modifiers, helpers, services, utils), typing an existing public API, or converting existing .js/.gjs files to .ts/.gts. Covers the component/modifier/plain-class Signature patterns, TSDoc for Signatures, typing untyped dependencies, compile-time type tests, the strict-grade bar under the loose global tsconfig, and the faithful-port and rename pitfalls that the type-checker does NOT catch.
---

# Writing TypeScript for Discourse

Core, plugins, and themes can be authored in `.ts`/`.gts` with full TypeScript. The
reference components are
[`frontend/discourse/app/ui-kit/d-async-content.gts`](../../frontend/discourse/app/ui-kit/d-async-content.gts)
(a generic `Signature`, per-member TSDoc, documented yielded block tuples, `WithBoundArgs`)
and
[`frontend/discourse/float-kit/components/d-tooltip.gts`](../../frontend/discourse/float-kit/components/d-tooltip.gts)
(typed `@service declare` injection, `Element`, several documented `Blocks`, an option bag
derived from a shared type); the developer guide is
[`26-types.md`](../../docs/developer-guides/docs/03-code-internals/26-types.md). **The
global tsconfig is deliberately NOT strict** (it extends the repo-root `tsconfig-base.json`,
which sets no `strict` and no `checkJs`); tightening it is a separate, repo-wide effort.

**Converting an existing `.js`/`.gjs` file?** Read
[references/js-to-ts-conversion.md](references/js-to-ts-conversion.md) first (the faithful-port
rules, rename mechanics, scope triage, and the runtime pitfall), and apply
[references/conversion-completeness.md](references/conversion-completeness.md) before
claiming any file or subsystem converted.

## Golden rules

1. **A conversion is a types-only port.** Types are erased; runtime behavior is not. Never
   change runtime code to satisfy a type. The full rule and the catalogue of changes that
   pass `lint:types` but alter behavior are in the conversion reference.
2. **Write strict-grade TS anyway.** The loose global tsconfig is not a licence for
   sloppiness. Author as if `strict` were on: **no `any`** (implicit or explicit), **no
   `@ts-ignore`/`@ts-nocheck`/`@ts-expect-error`**, no `{{! @glint-nocheck }}`. Proper
   `null`/`undefined` handling, real generics, precise `Signature`s. A documented `as` cast
   at a genuine DOM or loose-runtime boundary is fine; blanket suppression is not.
3. **Never tighten the global tsconfig** in a feature PR; the blast radius is the whole repo.
4. **The type-checker is necessary but NOT sufficient.** `pnpm lint:types` green does not
   mean the code runs. Always also run the tests (see "Verification").
5. **A `Signature` is a contract for ALL consumers, across time, not just the type-checked
   ones.** `checkJs` is off, so untyped `.gjs`/`.js` consumers are not "safe", merely
   *unchecked for now*; they will be measured against today's `Signature` when they convert.
   Do not scope arg types to the handful of files type-checked today; that bakes in a
   too-narrow contract that makes the rest harder to convert later. Type each arg to the
   component's **true contract**: its actual runtime behavior **plus the full range of real
   call sites** (grep every consumer, typed or not), as precise as the contract truly is but
   **no narrower**. Example: `d-flash-message`'s `@flash` is `string | TrustedHTML`, not
   `string`, because live consumers pass a `trustHTML(...)` result; the typed consumers alone
   would not have revealed the untyped one that does.

## Patterns

### `.gts` component (see `d-tooltip.gts`)

```ts
interface XSignature {
  Args: { title?: string; onSelect?: (v: string) => void; /* type every @arg read */ };
  Element: HTMLButtonElement;              // enables ...attributes checking
  Blocks: { default: []; item: [ItemType] };
}
export default class X extends Component<XSignature> { ... }
```

- Type `@action`/event params: `click(e: MouseEvent)`, `keyDown(e: KeyboardEvent)`.
- **Type injected services; do NOT leave `@service` bare.** This repo has no service
  `Registry` and `@service` is a bare `PropertyDecorator`, so a bare `@service foo;` makes
  `this.foo` implicitly `any` and every `this.foo.bar()` call goes unchecked: a hidden `any`
  that violates the no-`any` bar. Use Ember's documented pattern (see `d-tooltip.gts`):

  ```ts
  import type TooltipService from "discourse/float-kit/services/tooltip";
  @service declare tooltip: TooltipService;   // `declare` = the decorator sets it
  ```

  Much of the codebase still uses bare `@service router;`. That
  is the loose status quo, **not** the bar to match. In a `.js`/`.gjs` `@ts-check` file you
  are not converting, the equivalent is a
  `/** @type {import("discourse/services/foo").default} */` line above `@service foo;`.

  **Importing an untyped service or model's type is NOT a chain conversion.** A service is
  often backed by an untyped model (`@service site` is `discourse/models/site.js`). Writing
  `import type Site from "discourse/models/site"; @service declare site: Site;` pulls in the
  type TS *already infers* from that `.js` file, as-is, converting nothing. Real getters and
  fields in the class body still resolve. This is strictly better than a hidden `any` and
  costs one `import type`; do it rather than leaving `@service` bare out of a fear of
  "dragging in" the model.
- **Suffix imported service class bindings with `Service`.** Name the local type binding
  after its role even when the source module exports a shorter class name or is still
  JavaScript: `import type MenuService from "discourse/float-kit/services/menu";` then
  `@service declare menu: MenuService;`. Keep the injected property name and module path
  unchanged. Do not add `Service` to models, payloads, utilities, or other non-service types.
- **`declare` for framework-set fields** generally: Ember needs `declare` on `@service` (and
  on any decorated or args field with no initializer) so TS trusts the decorator to set it.
  Fields you initialize yourself do not need it.
- **Generic component:** `class X<T> extends Component<XSignature<T>>` with
  `interface XSignature<T> { ... Blocks: { content: [value: T] } }` (see
  `d-async-content.gts`). `Element` **enables `...attributes` checking**; omit it only when
  the component takes no attributes (Glint then rejects any attribute or modifier on it), and
  set the real element type where you spread `...attributes`.

### Template-only `.gts` component (no backing class)

A `const X = <template>...</template>;` component is typed by annotating the const; there is
no generic slot to fill:

```ts
import type { TOC } from "@ember/component/template-only";

interface XSignature {
  Args: { condition?: boolean };
  Element: HTMLDivElement;                 // still needed for ...attributes
  Blocks: { default: [] };
}

const X: TOC<XSignature> = <template>...</template>;
export default X;
```

(`TOC` is the exported alias of `TemplateOnlyComponent`; either name works.)

### `.ts` modifier (`ember-modifier`, see `ui-kit/modifiers/d-trap-tab.ts`)

```ts
import Modifier, { type ArgsFor } from "ember-modifier";
import type Owner from "@ember/owner";

interface XSignature { Element: HTMLElement; Args: { Named: {...}; Positional: [] }; }
export default class X extends Modifier<XSignature> {
  constructor(owner: Owner, args: ArgsFor<XSignature>) { super(owner, args); ... }
  modify(element: HTMLElement, _positional: [], named: XSignature["Args"]["Named"]) { ... }
}
```

### `.ts` plain class / helper / util

Standard TS. **Export** any interfaces the file's consumers need (e.g. an `XEngineOptions`
for a constructor options bag). Reuse arg types with lookups: `items?: XEngineOptions["items"]`.

### Choose named object types deliberately

Do not mechanically create an `interface` for every object-shaped field, parameter,
response, or private state bag just to attach TSDoc. Name a shape only when the name carries
architectural value:

- Use an `interface` for a component `Signature`, a durable public or exported contract, or
  real declaration-style extension.
- Use a `type` alias for unions, intersections, discriminated variants, and other named
  shapes that do not rely on interface extension.
- Keep a small, single-use parameter/options/state shape inline. Document its nested fields
  with `/** ... */` directly in the inline type when they are part of the public signature.
- Do not extract private one-use response or state bags merely to make the file look typed.

Before defining a local type for a core service, model, helper, or API, import and inspect
the canonical core type, including the type inferred from an unconverted `.js` file. Do not
replace a canonical dependency with a feature-prefixed approximation such as
`PluginCurrentUser` or `PluginSiteSettings` merely because the core file is JavaScript.

Locally extend a core type only after verifying that the runtime really supplies a field the
canonical type omits. Tag every such extension and every temporary boundary cast with
`TODO(typescript-pending)`, state the exact typing gap, and say when the workaround can be
removed. Dynamic plugin site settings need the same TODO until core provides a typed
plugin-setting extension mechanism.

**A plain function IS a valid Glint template helper.** You do not need a class-based
`Helper` to get a precise, argument-dependent return. A generic variadic function with a
`const` type param resolves correctly both as a direct call and in `{{...}}` invocation (see
`frontend/discourse/truth-helpers/helpers/or.ts`):

```ts
export default function or<const T extends MaybeTruthy[]>(...args: T): FirstTruthy<T>;
export default function or(...args: MaybeTruthy[]) { /* impl returns a loose type */ }
```

Use the **overload pattern** (a public typed signature callers see, plus a looser
implementation signature the body satisfies) when the real return is a conditional type the
implementation cannot prove. Confirm the template-invocation typing with a Glint type test
(see "Type tests"). Keep the helper a plain function when it is also imported and called
directly (a class-based `Helper` cannot be called as `helper(a, b)`); converting a function
to a class is a runtime change, not a types-only port.

**Advanced: different signatures in template vs plain-JS position.** Overloads cannot gate
one shape to *template* invocation only; a plain-JS caller can still pick the template-only
overload and fail later. When a function genuinely needs two signatures depending on how it
is called (e.g. an `owner` argument the helper manager injects only during template
invocation, so the template form takes one fewer positional), intersect a normal call
signature with a `DirectInvokable<...>`-branded one from
`@glint/template/-private/integration`. Glint resolves the branded member for template
invocation; TypeScript uses the plain member for direct JS calls. This imports a **private**
Glint path and is a specialist tool; the overload pattern stays the default.

## JSDoc

Keep the didactic **prose** descriptions (Discourse likes docs a junior can read), but
**drop the now-redundant `@param {type}` / `@returns {type}` type tags**; the types live in
the signature. Keep `@param name - description` prose only where it adds meaning.

### Documenting the `Signature` (TSDoc, not `//`)

A `Signature` is the component's public API surface, so its members deserve docs that
**surface in editor intellisense on hover**. That means `/** ... */` TSDoc, member by member;
a `//` line comment above a property does **not** attach to it for hover.

- **Every `Args` and `Blocks` member gets its own `/** ... */`.** Do not lump several under
  one comment. (A `//` comment that merely *groups* members, such as `// Text` /
  `// Actions`, is fine as a grouping and is not meant to surface per property.)
- **Document nested object-arg inner properties too.** `icons?: { left?: string; right?:
  string }` gets a `/** ... */` on `left` and on `right`, not just on `icons`.
- **Document each yielded block value inline on the named tuple member.** TS surfaces TSDoc
  on tuple elements, so prefer per-item docs over describing them in the block's prose:

  ```ts
  /** Rendered when the data rejects; when omitted, handled per `@errorMode`. */
  error: [
    /** The rejection reason. */
    error: Error,
    /** A component, pre-bound to the error, that renders the inline error message. */
    retry: WithBoundArgs<typeof AsyncContentInlineError, "error">,
  ];
  ```

- **Say what the argument IS, not how it is wired internally.** `@type` is "The severity of
  the message", not "selects the `alert-*` modifier class". The class it maps to is an
  implementation detail the consumer does not need.
- **Explain the *why* when a member's purpose is not self-evident.** `@context` on
  `d-async-content` is not just "a value forwarded to the function form": it is **tracked**,
  so updating it re-invokes the function and reloads the data; the doc should tell the
  consumer to pass the reactive state the data source depends on.
- **Watch the phrasing.** Read each line back as a consumer would. "Icon ID displayed at the
  start" reads backwards (the *icon* is displayed, not the ID): "ID of the icon displayed at
  the start of the input." "Rendered ... (no default: a spinner)" is cryptic: "When omitted, a
  loading spinner is shown in its place." Awkward or ambiguous docs are worse than none.

## Typing untyped dependencies (the common blocker)

Consuming an **untyped `.gjs` component or helper from a `.gts` file** gives Glint no
`Signature`, so its invocation errors (`unknown not assignable to Element`, `X does not exist
in type ...`, or a helper returning a loose or wrong type). Two fixes:

- **Untyped component**: a local typed alias, tagged for later removal:

  ```ts
  import { type ComponentLike } from "@glint/template";
  import SomeWidgetUntyped from "discourse/components/some-widget";

  // TODO(typescript-pending): drop once SomeWidget is authored in .gts with a real
  // Signature, then import it directly. Untyped .gjs today, so no arg/block/attr types.
  const SomeWidget = SomeWidgetUntyped as unknown as ComponentLike<{
    Args: { ... }; Element: HTMLElement; Blocks: { default: [] };
  }>;
  ```

  Same runtime import (zero runtime effect). **Always tag `TODO(typescript-pending)`** so
  these stopgaps are greppable and get removed once the underlying component is typed.

- **Untyped helper:** either wrap the value in a typed getter at the call site, or, better,
  type the helper itself (and add a type test). `truth-helpers` is fully typed, so `or`/`and`
  already return the precise value union; a still-untyped helper can follow the same
  plain-function-with-overload pattern. Tag any interim workaround `TODO(typescript-pending)`.

- **Sibling types:** `HelperLike<Sig>` / `ModifierLike<Sig>` are the same idea for untyped
  helpers and modifiers; **`WithBoundArgs<typeof Comp, "argName">`** types a *curried*
  component you yield with some args pre-bound (e.g. an inline error component yielded to an
  `:error` block with `error` already set; see `d-async-content.gts`). The bound args become
  **optional and stay overridable** at the invocation site, the same semantics as
  `{{component}}`. Bind several with a union: `WithBoundArgs<typeof Comp, "a" | "b">`. In an
  `expect-type` test, a curried result asserts as `WithBoundArgs<typeof Comp, "arg">`, **not**
  the raw component type.

## Type tests (compile-time)

When a module's *types* carry meaning a runtime test cannot capture (an argument-dependent
return, an overload picking the right signature, a generic that must resolve to a precise
type), assert them at compile time with `expect-type` (a devDependency of
`frontend/discourse`). They are checked by `pnpm lint:types`.

- **Location:** `frontend/discourse/type-tests/<feature>/`, a **sibling** of `app/` and
  `tests/`, already in the discourse `tsconfig.json` `include`. It sits outside the QUnit
  loader glob (`tests/**/*-test.*`) and outside every `compat-modules.js` glob, so the files
  reach **neither the test nor the production bundle**. Do NOT place them under
  `truth-helpers/` or any `compat-modules` dir; that glob WOULD sweep them into the runtime
  bundle. tsconfig `include` governs type-checking only, never the bundle.
- **Naming:** the repo's `-test.ts` / `-test.gts` suffix; safe here precisely because the
  dir is outside `tests/`.
- **Direct-call tests:** `expectTypeOf(or(maybeStr, "x")).toEqualTypeOf<string>()`,
  `.not.toEqualTypeOf<boolean>()`. A mismatch surfaces either as `error TS2344` or as the
  cryptic **"Expected 1 arguments, but got 0"** on the `.toEqualTypeOf<T>()` (no-value) form;
  that IS expect-type's mismatch signal, not a real arity bug.
- **Template-invocation tests** (a helper or component whose types only surface in a
  `<template>`): a `.gts` with a typed **template-only component** (`TOC`, NOT an empty
  backing class, which trips `ember/no-empty-glimmer-component-classes`) that feeds the value
  into a typed arg (see `type-tests/truth-helpers/glint-test.gts`). Negative cases use
  `{{! @glint-expect-error }}`, the **one sanctioned** use of a Glint directive.
- **Split positives and negatives into separate `.gts` files.** A single
  `{{! @glint-expect-error }}` **anywhere** in a `.gts` makes Glint stop reporting *all
  other* type errors in that file, so a mixed file lets the positives pass **even against a
  broken declaration**. Keep positive template type-tests in files with **zero** Glint
  directives; put every `@glint-expect-error` negative in its own file (see
  `type-tests/ui-kit/d-drag-and-drop-adoption-test.gts` vs `...-adoption-errors-test.gts`).
  A short comment at the top of the positives file ("keep this file free of
  `@glint-expect-error`") stops someone reintroducing one.
- **Non-strict gotchas** (type-level results diverge from the strict mental model): a
  `Conditional<null>`/`<undefined>` often resolves to `true` not `false`; a `const`-inferred
  object or tuple return carries `readonly`, which `toEqualTypeOf` treats as a mismatch; and
  `string | undefined` collapses to `string`. Assert the **robust, real** cases; avoid
  `null`/`undefined`-literal and object-return edge assertions that only hold under strict.

## Glint directives: avoid in production code

`{{! @glint-expect-error }}` / `{{! @glint-ignore }}` / `{{! @glint-nocheck }}` are NOT
acceptable escape hatches; fix the type instead (a `ComponentLike` shim, a narrow, a
documented `as` cast). `@glint-expect-error` is only for **type tests that assert code does
NOT compile**; `@glint-nocheck` is only for **gradual migration** of a template you are not
converting yet. If you reach for one to silence a real error, stop and type the thing.

Also: an in-`<template>` `{{! ... }}` comment must not contain backticks, `<...>` tokens,
`="..."`, or `|`; they break `ember-eslint-parser` scope analysis (spurious `no-unused-vars`
on template imports). Reword to plain prose. JS-body `//` and `/* */` are fine.

## Specific type recipes

- **Trusted HTML:** type as `TrustedHTML` imported from `@ember/template` (the return type
  of `trustHTML()`), NOT `SafeString`/`htmlSafe()`, NOT `ReturnType<typeof trustHTML>`
  (roundabout), and NOT the DOM Trusted Types `TrustedHTML` (not in this project's lib).
- **`super.willDestroy()`:** both `@glimmer/component`'s base (`willDestroy(): void {}`) and
  `@ember/object`'s `CoreObject` (`willDestroy() {}`, invoked by the framework as
  `registerDestructor(self, () => destroyable.willDestroy())`) declare **no parameters and
  are called with none**, so `super.willDestroy(...arguments)` is provably identical to
  `super.willDestroy()`. Write `super.willDestroy();` (the spread also trips eslint
  `prefer-rest-params` in `.ts`/`.gts`). This is a **method-specific** exception verified
  against source; do NOT generalize it to a `super.<hook>(...arguments)` whose base actually
  reads its arguments. Keep the spread there.
- **`@ember/render-modifiers` `{{didInsert}}`/`{{didUpdate}}` handler:** the callback is
  `(element: El, args: PositionalTuple)`; the extra positionals arrive as **one tuple in the
  2nd param**. So `{{didInsert this.announce count}}` is `announce(el: HTMLElement, [count]:
  [number])` (destructure the tuple), not `announce(el, count)`.
- **DOM element types:** `querySelector` returns `Element` (no `.focus()`/`.tabIndex`); use
  `el.querySelector<HTMLElement>(sel)`. Type element params as `HTMLElement` /
  `HTMLInputElement` where you call element methods, not `Element`.
- **`EmberObject.create()`-populated fields:** declare them `declare foo: T;` (no runtime
  field initializer that would clobber the value `create()` sets).
- **`import type`:** use it for type-only imports; prettier may collapse it since the repo has
  no `verbatimModuleSyntax`. That is fine.
- **Args-bag / options-object param:** type it as `object`, NOT `Record<string, unknown>`. A
  named interface with no index signature is assignable to `object` but **not** to
  `Record<string, unknown>`, so `object` accepts a real component's `this.args` (and any
  interface-typed bag) while `Record<string, unknown>` rejects it.
- **Pass-through callbacks on a widely-used primitive: do not over-tighten.** For a
  lifecycle or relay callback that many consumers pass with varied shapes (a menu's
  `onClose`/`onShow`), pinning `() => void` rejects any consumer callback that takes an arg or
  returns a value. Use a named broad-but-*real* signature: `type XCallback = (...args:
  any[]) => void`. It accepts functions of any arity, documents intent, type-checks the
  internal call, and needs **no** eslint-disable. Do NOT use the bare global `Function` type
  (eslint `no-unsafe-function-type`; calling it yields `any`) nor `any`. Caveat: a value the
  *consumer* has typed as the bare `Function` will not assign even to `(...args: any[]) =>
  void`; that is the consumer's own under-typing to fix (often a lazy `@property
  {Function}`), not a reason to loosen the primitive. Precision rarely forces a consumer
  chase: a param typed `(x: T) => void` still accepts a consumer's `() => void`.

## Lint hazard: member ordering can split comments

`sort-class-members` (via `bin/lint`) reorders class members and can **split a comment that
was attached to a member it moves**: an arrow-function field (`foo = () => ...`) sorts into
the *field* bucket, landing between another field and its leading comment. When **authoring
new** code, prefer `@action` methods over arrow-function fields for template-referenced
callbacks (auto-bound AND sorted into the methods bucket). **Re-read the file after
`bin/lint --fix`** to confirm no comment got orphaned or split.

## Verification (all three, in order)

1. `bin/lint --fix <files>`: clean.
2. `pnpm lint:types` from the **repo root** (composite `ember-tsc -b`): **0 errors**. This
   is the type gate; it also surfaces consumer fallout when you tighten a previously loose
   type (e.g. an untyped helper's return).
3. `bin/qunit` for the touched files' tests: behavior plus the runtime module-resolution
   check in the conversion reference.

Green on `lint:types` alone is **not** done: a run that hangs or reports a single "Global
error ... Failed to resolve module specifier" is the runtime pitfall described in the
conversion reference.
