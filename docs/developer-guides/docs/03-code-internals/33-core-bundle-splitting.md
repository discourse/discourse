---
title: Bundle splitting in core
short_title: Core bundle splitting
id: core-bundle-splitting
---

Core applies the same idea as plugin `staticModules`: only modules that runtime code looks up by name are registered with `define()` at boot, and route code loads in bundles when a route is entered. This page describes the mechanism and the tools that measure it.

## What loads at boot

`frontend/discourse/lib/discourse-core-modules.mjs` generates `virtual:core-modules`, which replaces embroider's `compat-modules`. It walks `app/` and registers only these directories eagerly: `adapters`, `connectors`, `initializers`, `instance-initializers`, `models`, `services`, `templates/components`, `templates/connectors`, and any `route-map`. Everything else is reached through imports.

Route, controller and template files are grouped into route bundles. The plugin parses `app/routes/app-route-map.js` with the plugin route-map parser and reads `bundleName` from route options:

```js
this.route("discovery", { path: "/", bundleName: "discovery" }, function () {
  ...
});
```

Routes with no name in the map, or in any ancestor, go in the `other` bundle. Routes built in loops are not visible to the parser, so `BareRouter#lazyRoute` walks up the dotted route name until it finds a bundle: `discovery.top-weekly` loads the `discovery` bundle.

A bundle can name modules to load with it in `BUNDLE_PRELOADS`, for code its routes use synchronously. The WarpDrive store implementation loads this way with the `topic` and `other` bundles, while `request()` from any other page loads it on demand.

## Chunking

Rolldown's code splitting groups are driven by the same plugin. After the module graph is complete it assigns every module an owner:

- the boot entrypoint's static closure becomes one chunk,
- each route bundle owns the modules only it reaches,
- each dynamically imported module owns the modules only it reaches,
- modules reached by several route bundles go in `route-shared`,
- other shared modules get one chunk per combination of owners.

Group capture is not recursive, since every module already has an assignment. This keeps a lazy import from dragging a whole route bundle along, and keeps the boot closure in a single request.

## Preloading

The manifest lists `routeBundles` with url globs, in the same form as plugin manifests. `EmberAssets.route_bundle_scripts_for_path` matches the request path, and the layout emits `modulepreload` links for the bundle, its preloads and everything they import.

## Loading code on demand

- `modal.show` accepts a thunk returning `import()`, and loads the component before showing it.
- Registration functions that plugins call live in `app/lib/plugin-registries`, so the modules that read them do not load when something registers.
- Core initializers use `discourse/lib/core-api`, a subset of the plugin API. The full plugin API extends it and loads only when a plugin or theme needs it.
- Components under `app/components/lazy` wrap chrome that renders rarely or on interaction: the composer, cards, header menus, the design wizard and the onboarding banner.

## Measuring

Build production assets, then:

```sh
node script/boot-size/measure.mjs            # static closure sizes per page
node script/boot-size/measure.mjs --save     # append to history.json
node script/boot-size/chart.mjs              # render history.json to chart.svg
node script/boot-size/why.mjs <module>       # shortest static import chain from boot
node script/boot-size/why.mjs --without <m>  # what only loads because of a module
node script/boot-size/edges.mjs <module>     # cost of each import a module makes
CHROME_PATH=... node script/boot-size/browser.mjs   # what a real browser fetches
```

`why.mjs` and `edges.mjs` read `dist/manifest/module-graph.json`, which production builds write. `browser.mjs` needs a running server and reports the chunks a page fetched, sized from the build report, along with any console errors.
