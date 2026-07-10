---
title: JavaScript type hinting & validation (typescript)
short_title: JS type hinting & validation
id: js-type-hinting
---

Discourse ships type information for its JavaScript code. This can provide inline documentation, autocomplete, and other useful IDE features. It can also be used for some basic type validation, using the `@ts-check` directive.

Much of this will be automatically consumed by IDEs with TypeScript/JavaScript support. But for functionality in `.gjs` files, you'll need some specific configuration and/or IDE plugins.

## Writing TypeScript

Core, themes and plugins can be authored directly in TypeScript. Use a `.ts` extension for plain modules, or `.gts` for Glimmer components with a `<template>` tag. Type syntax is stripped at build time, so no separate compilation step is required. Linting (`@discourse/lint-configs`) and type-checking (`pnpm lint:types`) both understand these files.

## Type tests

When a module's _types_ carry meaning that a runtime test can't capture — a generic that must resolve to a precise type, an overload that must pick the right signature, a helper whose return depends on its arguments — assert those types at compile time with [`expect-type`](https://github.com/mmkal/expect-type). These assertions are checked by `pnpm lint:types` alongside everything else.

Type tests live in a dedicated `type-tests/` directory (a sibling of `app/`, `tests/`, etc.), grouped by the feature under test, e.g. `frontend/discourse/type-tests/truth-helpers/`. This location matters:

- The directory is added to the project's `tsconfig.json` `include`, so `ember-tsc` type-checks it.
- It sits **outside** the `tests/` tree that the QUnit loader scans and outside any `compat-modules.js` glob, so the files are never pulled into the test or production bundle. Nothing imports them at runtime, and `expect-type` stays a dev dependency.

A `.ts` file uses `expectTypeOf` for direct calls:

```ts
import { or } from "discourse/truth-helpers";
import { expectTypeOf } from "expect-type";

const maybeString = "x" as string | undefined;
expectTypeOf(or(maybeString, "fallback")).toEqualTypeOf<string>();
expectTypeOf(or(maybeString, "fallback")).not.toEqualTypeOf<boolean>();
```

For types that only surface through a `<template>`, add a `.gts` file that exercises the value in a template and feeds it into a typed arg — Glint then checks it. Negative cases (things that must _not_ type-check) use `{{! @glint-expect-error }}`, which is the one sanctioned use of a Glint directive: asserting that code fails to compile.

## Usage

- **CLI**: Run `pnpm lint:types`

- **VSCode**: Install the [Glint v2](https://marketplace.visualstudio.com/items?itemName=typed-ember.glint2-vscode) extension. This is part of our [recommended config](https://github.com/discourse/discourse/blob/main/.vscode/extensions.json), so you may already have it. If anything isn't working, you may need to trigger "Restart extension host" from VSCode's command palette, or restart the IDE.

- **JetBrains** (RubyMine, WebStorm, Intellij, etc.): Install the [EmberExperimental](https://plugins.jetbrains.com/plugin/15499-emberexperimental-js) plugin.

## Troubleshooting

Ensure that you've run `pnpm install` recently

## Enabling for a theme or plugin

Official themes/plugins, and the official skeletons, are all wired up for types. To enable it for your own plugin/theme, pull in the latest changes from the relevant skeleton (`package.json`, `tsconfig.json`)

## Live type updates for bundled plugins and themes

If you're adding or changing core types and need to use those changes immediately in a bundled plugin or theme, use live type updates.

To do so, temporarily change the plugin or theme's `package.json` to:

```json
{
  "private": true,
  "dependencies": {
    "discourse": "workspace:@discourse/types@*"
  }
}
```

Then run `pnpm install` and start the type watcher with `pnpm types:watch`.

## Enable checking for a file

`.ts` and `.gts` files are always type-checked. For `.js` / `.gjs` files, type-checking is opt-in: add `/** @ts-check */` at the top. For some examples, search Discourse core for `@ts-check`.

## Limitations

We do not provide any guarantees about the accuracy of the types - they're provided on a best-effort basis. PRs to improve the type documentation in core are welcome.

## Known Issues

- Autocomplete inside `<template>` tags requires complete syntax. For example, if you start typing:

  ```
  <DBu
  ```

  This will not autocomplete to DButton, because the template syntax cannot be parsed. The workaround is to close the brackets, and then go back to the variable you'd like to autocomplete:

  ```
  <DBu />
  ```

  Upstream issue [here](https://github.com/typed-ember/glint/issues/765)
