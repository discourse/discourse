---
title: JavaScript type hinting & validation (typescript)
short_title: JS type hinting & validation
id: js-type-hinting
---

Discourse ships type information for its JavaScript code. This can provide inline documentation, autocomplete, and other useful IDE features. It can also be used for some basic type validation, using the `@ts-check` directive.

Much of this will be automatically consumed by IDEs with TypeScript/JavaScript support. But for functionality in `.gjs` files, you'll need some specific configuration and/or IDE plugins.

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

To enable type-checking for a specific file, add `/** @ts-check */` at the top. For some examples, search Discourse core for `@ts-check`.

## Limitations

Discourse's build pipelines do not currently support `.ts` files. Types are built & checked using `.js` / `.gjs` files only.

We do not provide any guarantees about the accuracy of the types - they're provided on a best-effort basis. PRs to improve the JSDoc-based documentation in core are welcome.

## Known Issues

- When importing one gjs file from another, CLI checks will report "Cannot find module". This happens due to a bug in `glint`, which requires the `.gjs` file extension to be added to the type import. The problem can be worked-around by adding a type import alongside the regular extensionless import.

  ```js
  /** @type {import("./slot.gjs").default} */
  import Slot from "./slot";
  ```

  Upstream issue [here](https://github.com/typed-ember/glint/issues/1021).

- Autocomplete inside `<template>` tags requires complete syntax. For example, if you start typing:

  ```
  <DBu
  ```

  This will not autocomplete to DButton, because the template syntax cannot be parsed. The workaround is to close the brackets, and then go back to the variable you'd like to autocomplete:

  ```
  <DBu />
  ```

  Upstream issue [here](https://github.com/typed-ember/glint/issues/765)
