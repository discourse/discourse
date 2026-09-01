# Converting `.js`/`.gjs` to `.ts`/`.gts`

Read this before converting an existing file. The authoring rules in `SKILL.md` still apply;
this file covers what is specific to a conversion: keeping the port faithful, the rename
mechanics, when to defer, and the runtime failure the type-checker cannot see.

## The one rule: a faithful, types-only port

**The type is erased; the runtime behavior is not.** *Never change runtime code to satisfy a
type.* Preserve every existing guard, fallback, coercion, `throw`, call, mutation, and
pass-through, **even when the new type says that path is impossible**, and solve the type
error with a truthful wider type or a documented erased `as` assertion, never a runtime
check. A type annotation asserts a contract; it does not prove that runtime callers obey it,
because types are erased at compile time and `checkJs` is off. Untyped callers, preload
payloads, MessageBus, `JSON.parse`, and server data all still reach your code shaped however
they really are, which is exactly what the old guards were there for. Deleting a "redundant"
guard is a behavior change and the single most common way a conversion silently breaks. If a
guard looks removable, it still stays: note it for a **separate** cleanup PR.

## The faithfulness trap: changes that pass `lint:types` but alter behavior

A conversion that adds types is supposed to be a runtime no-op. The trap: the new types make
certain runtime code *look* removable, so you "tidy" it while typing, and the port is no
longer faithful. Every item below is a real regression from a conversion; each type-checks
clean and reads like an improvement. **None belong in a conversion PR.** They are erased-type
reasoning applied to code that runs against real, untyped data.

**Forbidden transformations. Each is a behavior change, not a type change. Keep the original:**

1. **Deleting a null/undefined guard because the param/field is now typed non-optional.**
   `themeId: number` does not stop a runtime caller passing `null`. Keep
   `if (themeId == null) { return null; }`.
2. **Removing optional chaining because the type says the value is present.**
   `this.args.leaf?.value` to `this.args.leaf.value` throws where the old code returned a
   default. Keep every `?.`.
3. **Dropping a defensive fallback or default the type says "can't" be nullish.**
   `(value || []).map(...)` to `value.map(...)`; a removed `?? ""` / `?? null`.
4. **Removing a runtime shape check (`Array.isArray`, `typeof`) the declared type asserts.**
   `if (!Array.isArray(layout) || ...)` guards against real non-array input; a
   `LayoutEntry[]` annotation does not.
5. **Adding a type-guard *narrowing* that substitutes a fallback for a value old code passed
   through raw.** `?? null` to `isImageArgValue(v) ? v : null`; `?? ""` to
   `normalizeStoredValue(v)`; `mode` to `typeof mode === "string" ? mode : undefined`;
   `enum` to `enum.map(String)`; a truthy check to `=== true`. Invoking a guard, normalizer,
   `String()`, or a stricter comparison **is runtime code**, even though it feels like
   "safely narrowing `unknown`."
6. **Adding a NEW validation gate that rejects inputs old code accepted.** Wrapping a
   `JSON.parse` result in `if (!isRawLayoutEntry(parsed)) return;`; running a preload or
   MessageBus payload through a new validator that drops rows.
7. **Swapping a runtime primitive for a "cleaner" typed equivalent with different
   semantics.** `console.error(msg, errObj)` to `@ember/debug`'s `warn(string)` is not
   equivalent: `warn` is stripped from production, emits at a different level, and
   stringifies the object. Keep the exact original call and its `// eslint-disable`.
8. **Turning a throw into a silent success, or vice-versa.** `entry.args[k] = v` (throws
   when `args` is nullish) to `(entry.args ??= {})[k] = v` (silently initializes).
9. **Replacing an unreachable-but-present fallback with a `throw`.** `default: return
   children` to `default: throw ...`. An "impossible" branch is still behavior.

**Behavior can change with no input change.** "Any input" is not the whole surface. Also
forbidden: changing a value `import` to `import type` or reordering runtime imports (alters
module evaluation and side effects); reordering initialized fields, adding `= undefined`, or
turning a getter/method into a field or vice-versa (alters init order, own-property
presence, descriptors, framework injection); arrow-field to method or back, added/removed
`@action` or `.bind(this)` (alters callback identity and `this`); adding/removing `await` /
`return await` / `catch` / `finally` (alters scheduling and error propagation); spread-copy
vs in-place mutation, `push` vs concat (alters identity and observable mutation); `x.foo =
undefined` vs `delete x.foo` vs omission (property presence differs); `filter(Boolean)`,
dedup, sort, or a changed loop form (alters skipped values, order, callback invocations); and
runtime-producing TS constructs (`enum`, parameter properties, `namespace`, `#private`
fields, and field initializers are **not** erased annotations).

**The litmus test, applied to every hunk of your own diff:**

> "Can this change any observable runtime behavior in any execution, including module
> loading, initialization, mutation, identity, timing, logging, errors, or handling of a
> nullish, wrong-typed, or malformed value a real untyped caller could pass?"

If yes, it does not belong in the conversion. **"The type proves it can't happen" is not a
defense**: the type is erased and `checkJs` is off, so callers can and do violate it; the
guard is exactly what runs when they do.

**When TypeScript cannot prove what the old code assumed:** preserve the old runtime
operation and express the assumption with a truthful **wider type**, an **overload**, or a
documented **erased `as` assertion** at the existing loose boundary (tag it
`TODO(typescript-pending)`). Do NOT add a runtime check, fallback, coercion, or rejection
path to satisfy the checker; that is exactly transformations 5 and 6.

**Diff discipline. Self-check before claiming a file converted, and again _after_ `bin/lint
--fix`** (member and import reordering can introduce changes after your first read). Read
the conversion as a literal `git diff` of old vs new and classify every changed hunk as one
of: (a) erased type syntax: annotation, `Signature`, `declare`, `import type` for a
**newly added** type dependency (a pre-existing value import stays a value import); (b) a
formatting or import change **verified to preserve the emitted program, runtime import
order, module evaluation, and template output**; (c) a comment/JSDoc edit; (d) a mechanical
rename or module-specifier change **strictly required for the converted file to resolve**,
resolving to the same module and preserving runtime binding, evaluation order, and side
effects (identify each such hunk explicitly; this does not permit logic cleanup). **Anything
else (a changed conditional, default, guard, coercion, call argument, control-flow edge,
decorator, field order, mutation, logging call, async flow, or return shape) is a red flag
to revert.** If it seems a genuine improvement, raise it as a **separate** follow-up.

**Lint interaction:** `sort-class-members` may want an arrow-function field turned into an
`@action` method. During a conversion, do NOT make that swap; arrow-field to method changes
callback identity and `this`-binding. Keep the original member form, re-read the file after
`bin/lint --fix`, and re-run the diff check above, since the reorder itself can introduce a
behavior change.

## Rename mechanics: a single commit

git's rename detection is content similarity at diff time (50% threshold). For a **small
file**, adding types drops it below that (a 2-line `eq.js` to a typed `eq.ts` is under 50%
similar), so a single delete+add commit is not detected as a rename, and `git blame` /
GitHub / `git log --follow` show it as a fresh add.

The classic two-commit trick (commit 1 = pure `git mv` with byte-identical content, commit 2
= overwrite with the typed content) only helps on repos that keep branch commits. **Discourse
squash-merges PRs**, which collapses the whole branch into ONE commit on `main` and discards
the intermediate pure-rename commit. What lands on `main` is a single `delete .js` + `add
.ts (typed)`, so blame-through-rename depends solely on that one squashed commit's
similarity, which the branch's commit structure cannot change. The two-commit dance is pure
ceremony here.

**Therefore default to a SINGLE commit** (`git mv x.js x.ts`, overwrite with typed content,
`git add`, one commit). Do not split rename-then-types.

Practical consequence: blame-through-rename survives *only* when the typed file stays at or
above 50% similar to the original (`git status` shows `R`, not `D`+`A`). When it drops below,
as a real conversion of a small file usually does, blame breaks at the conversion commit no
matter what, and contorting the code to stay similar is not worth it. Do not promise blame
preservation you cannot deliver under squash. Files under roughly 40 alphanumeric characters
fall below git's copy-detection floor entirely (but have no meaningful history to lose).

## When to defer a whole conversion (scope triage)

Not every file is a clean "convert one file" job. Before starting, gauge the blast radius;
if it is large, **defer the file to its own coordinated PR** rather than dragging the scope
sideways into an otherwise-clean change. A clean conversion:

- pulls in **no internal untyped-component casts** (only untyped *helpers*, which need no
  cast; they resolve fine in templates), and
- produces **little or no consumer fallout** when its `Signature` tightens.

Defer when the file instead:

- **drags in several untyped internals** that each need a local `ComponentLike` or interface
  cast, and/or
- has a **large consumer surface** (dozens of call sites) where tightening leaks type errors
  across many files, and/or
- is **owned by another area** (FloatKit, FormKit) where the contract should be agreed with
  the owner.

A widely used FloatKit or FormKit primitive is the cautionary case: several sibling ui-kit
components with zero internal casts and one trivial fallout ship together in one PR; the
primitive with dozens of consumers gets its own.

## The runtime pitfall (the one that bites)

**`ember-tsc` does NOT catch runtime module-resolution errors in non-`@ts-check` `.js`/`.gjs`
consumers.** When you rename `x.gjs` to `x.gts`, any consumer that imported it with the
**explicit old extension**

```js
import X from "discourse/ui-kit/x.gjs";   // stale extension: breaks at runtime after rename
```

will pass `pnpm lint:types` (the consumer is not type-checked) but **throw a global "Failed
to resolve module specifier" at test/runtime**, breaking the whole bundle load (every test
in it fails or the run hangs to timeout). After any rename:

1. **Grep for extensioned imports** of the renamed file across the repo:
   `grep -rnE 'from "[^"]*x\.gjs"' frontend plugins themes` and fix each to
   **extensionless** (`from "discourse/ui-kit/x"`).
2. **Remove any stale `@type {import("...x.gjs")}` resolution workaround.** Such annotations
   existed only to paper over an old extensionless-resolution bug in glint (TS2307 "Cannot
   find module" on an extensionless `.gjs` import). Extensionless `.gjs` imports resolve now,
   so a `@type {import(...)}` that existed *solely* for resolution is dead weight: **delete
   it** (do not "update it to `.gts`"), then confirm `pnpm lint:types` is still green. An
   `@type {import(...)}` that documents a *real* type (e.g. an extensionless `@service` in a
   `.js` file) still stands; only the resolution stopgap is obsolete.
3. **Run the tests**, not just the type-check.
