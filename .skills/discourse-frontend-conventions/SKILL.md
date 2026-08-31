---
name: discourse-frontend-conventions
description: Conventions for Discourse frontend code, JavaScript and TypeScript alike (.js/.gjs/.ts/.gts), in core, plugins, and themes that the linter does not enforce. Use when writing, reviewing, or preparing to commit class-based code or templates. Covers the private-symbols pattern (#, unprefixed, _), class member ordering beyond the lint buckets, blank lines before documented fields, no banner comments, safe in-template comments, attribute/argument/modifier ordering on invocations, and the comment necessity gate.
---

# Frontend code conventions

This skill keeps Discourse frontend code (JavaScript, TypeScript, and Glimmer templates in
`.js`, `.gjs`, `.ts`, and `.gts` files) consistent on the things `bin/lint`
alone does not guarantee: which members are private and how they are named, the order of
class members, and whether a comment deserves to exist. Work through the steps in order.
For TypeScript-specific rules (`Signature`s, typed services, type tests) see the
`discourse-writing-typescript` skill.

## Step 0: decide the scope

The scope of what you fix depends on whether the file is new or already exists. Get this
right before touching anything; reaching into untouched code creates noisy, unrequested
churn in diffs.

- **New file** (untracked, or created in this session): audit and fix the **whole file**.
- **Existing file**: only the code being **added or changed** now. Do NOT reorder
  pre-existing members to satisfy the ordering rules. A new method must land in its correct
  position relative to its bucket, but members you did not touch stay where they are.
- **Explicit override**: if asked to "revamp the whole file" (or equivalent), audit the
  entire file as if it were new.

Determine new vs existing with `git status` (untracked = new) and `git diff` /
`git diff --staged` (which lines changed in existing files).

## Step 1: private-symbols pattern

Every class member falls into one of three buckets, in priority order:

1. **`#field` / `#method()`**, real JS private. Use whenever possible: any member that is
   NOT decorated, NOT read from a template, AND accessed only from within its own class
   body. `#` is scoped to the declaring class (see the access-scope rule below).
2. **Unprefixed**, public API. Use for anything called from a template (`{{this.foo}}`,
   `{{on "click" this.bar}}`), for decorated members the template binds to, AND for any
   member reached from another class (a service method called as
   `this.someService.doThing()`, a parent reaching into a child, a modifier). If something
   outside the class can call it, it IS public API. Templates and other classes are the API
   surface; nothing they touch gets a `_`.
3. **`_prefix`**, last-resort fallback, ONLY when all three apply: (a) the member needs a
   decorator that cannot apply to `#` (`@tracked`, `@action`, `@cached`, ...), (b) it is NOT
   used from a template, AND (c) it is accessed only from within its own class.

**Access-scope rule (the deciding test).** A `#` member is reachable *only* inside the class
that declares it; `this.#x` from any other class is a hard error. So before choosing `#` or
`_`, check who calls the member:

- Called only within its own class: `#` (or `_` if it also needs a decorator `#` cannot
  take).
- Called from a template: unprefixed.
- Called from another class in **production code** (service consumers, sibling components,
  an owning instance, a modifier): **unprefixed**. It is public API regardless of how
  "internal" it feels. `_` does NOT license cross-class access; a `_` member with external
  production callers is mis-prefixed.
- Called **only from test files**: `_` is correct and should stay. Tests legitimately poke
  non-public members, and that is precisely why `_` exists rather than `#` (a `#` member
  cannot be reached from a test at all). Classify callers as production vs test and ignore
  the test ones for this rule.

When a decorator is needed but the implementation should stay private, decorate a thin
public entry and delegate to a `#` implementation:

```js
@action
onClick(e) {
  this.#applyMutation(e.target.value);
}

#applyMutation(value) {
  // ...
}
```

Flag and fix:

- A `_` member that is neither decorated nor template-bound AND is called only within its
  own class: should be `#`.
- A `_` (or `#`) member that is called from another class: it is public API. **Rename it
  to unprefixed and update every call site.** Grep for the old name (`\.<oldName>\(` /
  `\.<oldName>\b`) before renaming so no caller is missed; this is a multi-file edit.
- A `#` member that a template reads or a decorator needs: cannot be `#`. Make it
  unprefixed (template) or `_` (decorated, non-template-bound, single-class).

Treat a decorated member or a getter on a component class as template-bound until you have
opened the template and proven otherwise. "No callers found" is a reason to look harder,
not permission to make the member private.

## Step 2: member ordering

The `sort-class-members` ESLint rule (from `@discourse/lint-configs`) enforces the
**top-level bucket order** for fields and lifecycle hooks, but drops every method into one
unordered `[everything-else]` bucket. This step adds the method sub-order the rule leaves
open, plus a within-bucket tie-break that applies to every bucket.

### Top-level buckets (fixed order)

```
[static-properties]                      lint-enforced
[static-methods]                         lint-enforced (bucket only)
@service / @optionalService              lint-enforced
@controller                              lint-enforced
@tracked properties                      lint-enforced
plain (unprefixed) instance properties   lint-enforced
#private / _private properties           lint-enforced
constructor                              lint-enforced
init                                     lint-enforced
willDestroy / other lifecycle hooks      lint-enforced
[everything-else]: methods, in this sub-order (enforce here):
    1. getters          (plain and @cached together)
    2. methods          (public, whether or not @action)
    3. private #methods (then _-prefixed private methods)
<template>                               lint-enforced (last, .gjs/.gts only)
```

The three method buckets key off *stable, syntactic* properties (`get`, plain vs `#`), so a
member only moves when its kind genuinely changes, not when an unrelated diff touches it.
They are deliberately NOT split finer: `@cached` and `@action` are togglable decorators
(added or removed for memoisation or template binding), so ordering on them would force
churn the moment a getter is memoised or a method becomes an action. `@cached` getters sit
among the other getters, and `@action` methods among the other methods, placed by purpose
and name, not by decorator.

### Within-bucket ordering (applies to EVERY bucket above)

*Within* a single bucket (static properties, static methods, services, controllers,
`@tracked`, plain properties, private properties, and each method sub-group), apply this
chain in order:

0. **Dependency order** (property buckets only, hard constraint): when one member's
   initializer references another member or a static, the dependency comes first. This
   overrides clustering and alphabetical. The linter keeps members in their bucket but does
   not reason about init-time references, so you must.
1. **Cluster by purpose**: keep related members adjacent. Two services used together, a
   getter and the action that mutates the same state, a `handleX`/`onX` handler family, a
   `formatX` helper family, a group of related static factories. Purpose locality wins over
   alphabetical.
2. **Alphabetical**: within a purpose cluster, or when there is no meaningful cluster, sort
   A to Z by name.

## Step 3: comments and blank lines

### Blank line before a documented field

The `lines-between-class-members` rule forces blank lines around methods and getters and
after services, but does NOT separate plain fields, so a field carrying a doc block ends up
with its doc pressed against the previous declaration:

```js
  @tracked activeThemeId = null;
  /**            // cramped: this doc reads as attached to the line above
   * Snapshot of the selected item.
   */
  @tracked selectedItem = null;
```

Insert a blank line before any class member whose leading line is a block comment (`/**`
or `/*`), so each doc-plus-field is one visual unit:

```js
  @tracked activeThemeId = null;

  /**
   * Snapshot of the selected item.
   */
  @tracked selectedItem = null;
```

Do NOT add the blank line when the member is already preceded by one or sits immediately
after the class's opening brace. Bare, undocumented fields may still pack together.

### No section or banner comments

Do NOT add `/* Section */` headers or `// ====` dividers to delineate buckets. The ordering
convention is self-documenting, and banner comments rot the moment a member moves. Remove
any within the touched scope.

### Safe in-template comments (`.gjs`/`.gts`)

A `{{! ... }}` comment **inside a `<template>`** must NOT contain backticks, angle-bracket
tokens (`<form.Field>`, `<@form.Field>`), attribute-like `="..."` snippets, or `|`. These
silently break `ember-eslint-parser` scope analysis: the entire template scope is dropped,
so eslint reports **every template-only import** as `no-unused-vars`. The component renders
fine and prettier and `ember-tsc` pass, so it looks mysterious.

**Tell:** a `.gjs` fails lint with a *cluster* of "X is defined but never used" errors for
symbols obviously used in the `<template>`.

**Fix:** reword the comment in plain prose. JS-body `/* */` and `//` comments may use those
characters freely; only in-template `{{! }}` comments choke.

## Step 4: invocation ordering (`.gjs`/`.gts`)

On every component invocation and element tag touched by the diff, the pieces are grouped
by KIND, never interleaved, in this order:

1. **Attributes** (`class=`, `data-*`, `aria-*`, `title=`, ...), with `...attributes`, when
   present, kept somewhere inside this group.
2. **`@arguments`** (component invocations only).
3. **Modifiers** (`{{on ...}}`, custom modifiers), always last.

This matches core precedent (`docked-composer.gjs`, `topic-navigation.gjs`). An `@argument`
or a modifier sitting between two plain attributes is the violation this step catches.

**`...attributes` placement is load-bearing; never move it relative to plain attributes.**
Its position sets override precedence: an attribute written AFTER the splat beats the
caller's value, one written BEFORE it yields to the caller (`class` merges regardless). The
splat belongs to the attributes group, but WHERE it sits inside that group is the author's
semantic choice. When rearranging, other attributes keep their side of the splat. If
satisfying the grouping would force an attribute across the splat, leave that invocation
alone and flag it instead of silently changing who wins.

The splat also carries caller-supplied modifiers, so moving it across the element's own
modifiers changes install order. Moving element modifiers after the splat (the normal
outcome of "modifiers last") is fine unless a modifier visibly depends on running before
the caller's.

Within the `@arguments` group, sort alphabetically unless a small purpose cluster clearly
reads better. Plain attributes need no strict sort, but keep them together.

Two more cautions when rearranging:

- **Preserve the relative order of the modifiers themselves.** Modifiers install in source
  order, and some pairs depend on it. Move the block; do not reshuffle inside it.
- A `{{! }}` comment that explains one modifier moves WITH that modifier, staying
  immediately above it.

## Step 5: documentation review

Review every JSDoc and inline comment in scope. Comments earn their place; the default is
no comment. Apply the necessity gate FIRST, then the shaping tests only to survivors.

**Necessity (existence gate, per comment).** Would a competent reader make a *wrong edit*
without this: a footgun, a non-local dependency (another file, service, or observer relies
on this value), a deliberately odd value, an ordering constraint, a browser quirk? If the
comment only states a rationale the reader would infer, or does not need to act correctly,
**DELETE it; do not reword it.** This is the quantity control. Judged one at a time, a
merely "non-obvious why" survives on nearly every line, so a file ends up commented
wall-to-wall even when each comment is individually defensible. A file that is 15%+ comment
lines, or has a comment on more than roughly one statement in five, is over-commented
regardless of per-comment quality; the fix is deletion. Prefer one section-level note over
many per-line preambles.

A comment that passes necessity must then survive all four shaping tests:

- **Redundancy.** Does the code already say it? Cut comments that narrate the line beneath
  them or restate a name, a nearby JSDoc, or a getter.
- **Durability.** Will it drift? Explain the *intent or constraint*, never the current
  arithmetic, DOM shape, or the list of things a rule happens to touch today. Do not bake in
  magic numbers or exact counts. In CSS, describe *why* a rule exists, not what it renders
  or how it compares to a sibling rule.
- **Brevity.** An inline comment is at most 2 lines, a JSDoc paragraph at most 3. Over that,
  either the code needs better names or the explanation belongs in the declaration's JSDoc.
  Keep the non-obvious sentence and delete the setup around it.
- **Plain language.** Would a reader get it in ONE pass? One idea per sentence. Lead with
  subject and verb. Name things directly. No trailing clause bolted on with a comma and a
  participle. Prefer verbs to nominalizations ("refuse the press", not "refusal of the
  press"). Read it aloud; if you stumble, rewrite it.

Also check that JSDoc is accurate and complete for the code as it now stands, and that
inline comments were updated where the logic they describe changed. Document declarations
with a `/** */` block, not `//` (a `//` block above a declaration does not reach editor
intellisense). Reserve `//` for a step inside a body.

Comments that fail necessity are deleted. Comments that fail brevity or plain language are
rewritten; write the replacement rather than describing it.

## Step 6: lint

Run `bin/lint --fix` on every touched file. This confirms the manual reordering agrees with
`sort-class-members` and prettier, and catches anything the steps above missed. Re-read the
file afterwards: the autofix can move a member away from a comment that was attached to it.
The lint must pass clean before the work is done.

**Staging note:** `bin/lint <file>` (and `--recent`/`--unstaged`/`--wip`) lints the
**working-tree** content, so edits are reflected immediately with no `git add`. Only
`bin/lint --staged` and the real `pre-commit` hook lint the **staged** blob (the hook hides
unstaged changes so a commit lints exactly what it will commit). After fixing a finding,
`bin/lint <file>` confirms it; re-stage the fix before committing.
