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

Types whose meaning a runtime test can't capture (a generic's resolved type, an overload pick, a return type derived from arguments) can be asserted at compile time with [`expect-type`](https://github.com/mmkal/expect-type), in `.ts`/`.gts` files under `frontend/discourse/type-tests/` (e.g. `type-tests/truth-helpers/`). They are checked by `pnpm lint:types` but kept out of the test and production bundles.

## Usage

- **CLI**: Run `pnpm lint:types`

- **VSCode**: Install the [TypeScript (Native Preview)](https://marketplace.visualstudio.com/items?itemName=TypeScript.native-preview) and [Glint v2](https://marketplace.visualstudio.com/items?itemName=typed-ember.glint2-vscode) extensions. Glint 1.4.0 and newer hands `.gts`/`.gjs` files to TypeScript's own language server. Both are part of our [recommended config](https://github.com/discourse/discourse/blob/main/.vscode/extensions.json), so you may already have it. If anything isn't working, you may need to trigger "Restart extension host" from VSCode's command palette, or restart the IDE.

- **JetBrains** (RubyMine, WebStorm, Intellij, etc.): Install the [EmberExperimental](https://plugins.jetbrains.com/plugin/15499-emberexperimental-js) plugin.

## Troubleshooting

Ensure that you've run `pnpm install` recently

## Enabling for a theme or plugin

Official themes/plugins, and the official skeletons, are all wired up for types. To enable it for your own plugin/theme, pull in the latest changes from the relevant skeleton (`package.json`, `tsconfig.json`)

## Bundled plugins and themes

Plugins and themes in this repository depend on `@discourse/types` through the pnpm workspace and reference the core project from their `tsconfig.json`. `pnpm lint:types` builds core first, so a core type change is checked against every bundled plugin in the same run, with no release or version bump in between.

In the editor, the TypeScript 7 language server resolves core imports straight to core source. Editors still on TypeScript 6 read the declarations that the last `pnpm lint:types` emitted, so run it, or keep `pnpm types:watch` running, after changing core types.

External plugins and themes consume the published `@discourse/types` package. It is published from `main` by the `publish-types` workflow.

## Relative imports

Relative imports name the file with its extension: `./foo.ts`, `./foo.js`, `./foo.gts`, `./foo.gjs`. TypeScript 7 only resolves a `.gts` or `.gjs` module when the specifier carries the extension, and the same rule is applied to every extension so that the type checker, the build and ESLint agree. ESLint reports a missing extension and adds it with `--fix`.

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
