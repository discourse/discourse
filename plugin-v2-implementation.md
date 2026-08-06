# `staticModules` — implementation sketch

Companion to `plugin-v2-plan.md`. Records what the existing machinery actually does, the
contract change, a file-by-file plan, and three problems the plan doesn't cover.

## 1. How it works today

Plugins and themes are **not** part of core's rolldown build. They are compiled at Rails
runtime by Ruby, driving `@rollup/browser` inside mini_racer:

| | core | plugin | theme |
|---|---|---|---|
| bundler | rolldown (`frontend/discourse/rolldown.config.mjs`) | `@rollup/browser` in mini_racer | same |
| driver | node, build time | `lib/plugin/js_manager.rb` | `lib/theme_javascript_compiler.rb` |
| entrypoint | real files | generated `virtual:entrypoint` | same generator |
| output | `dist/` + manifest | `app/assets/generated/<plugin>/js/plugins/` + manifest | one DB row (`javascript_caches`) |
| route splitting | **yes — `wizard`** | no | no |

The generator is `frontend/asset-processor/rollup-virtual-imports.js`. For every file in the
plugin/theme it emits a namespace import and stuffs it into one object:

```js
import * as Mod1 from "./discourse/components/chat-channel";
const compatModules = { "discourse/components/chat-channel": Mod1, /* ...everything... */ };
export default compatModules;
```

That default export has **two** consumers, which is the crux of the design:

1. **Core's AMD registry.** `app.js:81-105` does `(await import(link.href)).default` and
   `define("discourse/plugins/<name>/<key>", ...)` for each entry.
2. **Cross-bundle imports.** `babel-resolve-plugin-imports.js:61-129` rewrites
   `import X from "discourse/plugins/chat/discourse/components/foo"` into a real ESM default
   import of the bare specifier `"discourse/plugins/chat"` (satisfied by the importmap in
   `_plugin_js.html.erb`), then indexes into the map: `_plugin_chat["discourse/components/foo"]`.

So **the default export is the plugin's cross-bundle public API**, and `sharedModules` is
precisely the declaration of what belongs in it. Everything eager today; nothing tree-shakes,
because `import * as Mod` roots every module.

Route splitting already exists for core and the runtime contract is fixed by `@embroider/router`:

```js
window._embroiderRouteBundles_ = [
  { names: ["wizard", "wizard.index", "wizard.step"],
    load: () => import("./route-wizard-m7beykpk.digested.js") },
];
```

On navigation the router `find`s a bundle whose `names` contains the route name (exact
`indexOf`), awaits `load()`, and passes `.default` to `resolver.addModules(modules)`.
Discourse's resolver (`app/resolver.js:370`) implements that as plain `define()` calls — so
lazy route modules land in the same AMD registry as everything else. `mapping-router.js`
already extends `EmbroiderRouter` and already overrides `lazyRoute`.

## 2. The contract change

```js
// default export: cross-bundle public API. Legacy = everything; static = `sharedModules`.
export default { "discourse/components/chat-channel": Mod1, ... };

// eager AMD registrations, define()d by core at boot
export const compatModules = { "discourse/initializers/chat": Mod2, ... };

// lazy route bundles, pushed onto window._embroiderRouteBundles_ by core.
// `names` is always concrete — derived at build time, never a wildcard.
export const routes = [
  { names: ["chat.visualizer"], load: () => import("virtual:route:chat.visualizer") },
  { names: ["chat", "chat.channel", "chat.browse"], load: () => import("virtual:route:chat") },
];
```

Emitted per entrypoint, so the `admin` bundle exports its own `routes` in exactly the same shape.

`default` **must** stay the cross-bundle table — `babel-resolve-plugin-imports` and
`generate_import_map` both depend on it. `compatModules` becomes a separate named export so the
AMD set can shrink independently of the public API.

When `staticModules` is absent, emit today's output plus `export const compatModules = default`.
No stale-bundle risk: plugin and theme bundles are always recompiled from source by the running
core, so the contract can change in one step.

## 3. File-by-file

### JS build — `frontend/asset-processor/`

**`rollup-virtual-imports.js`** — the bulk of the work. Extract a pure
`partitionModules(moduleFilenames, frontend)` used by both generators below, returning
`{ shared, eager, routeBundles }`.

- `virtual:entrypoint` — when `frontend.staticModules`, emit the three exports above instead of
  one eager map. Route bundles become `() => import("virtual:route:<glob>")`; rollup code-splits
  them automatically (`chunkFileNames` is already configured).
- `virtual:route:<routeName>` — new generator, same body shape as core's embroider route
  entrypoint:
  ```js
  const routeCompatModules = {};
  routeCompatModules["discourse/routes/chat/channel"] = M1;
  export default routeCompatModules;
  ```
  Keys stay plugin-relative; core prefixes them on load (§4), matching how `compatModules` is
  already handled.

**`rollup-plugins/discourse-virtual-loader.js`** — teach `resolveId`/`load` about
`virtual:route:` ids alongside the existing `virtual:entrypoint:` / `virtual:theme` handling.
The `isTheme` gate at `:9-14` is the seam.

#### Route names are derived at build time, exactly like Embroider

Port `AppFiles#handleClassicRouteFile` + `splitRoute` from `@embroider/core`
(`dist/src/app-files.js:146-198`, `dist/src/virtual-entrypoint.js:200-260`). Embroider builds
its route tree **purely from file paths** — no router AST parsing: it strips the
`routes/` / `controllers/` / `templates/` prefix, nests the remaining segments, and `splitRoute`
joins them with `.` to produce the route name. Ember's own resolver convention guarantees the
file path *is* the route name, so this is sound rather than guesswork.

So **`names` comes out concrete**, and `@embroider/router`'s exact `names.indexOf(routeName)`
works untouched — no wildcard matching, and no change to `mapping-router.js`.

#### The two sides of `splitAtRoutes` are for two different consumers

```json
"splitAtRoutes": {
  "chat/visualizer": "chat.visualizer",
  "chat/*":          "chat.*"
}
```

- **Values are route-name patterns, consumed at build time.** They feed `shouldSplitRoute`
  exactly as Embroider's `splitAtRoutes` does. Both entries go into the split set and ordering
  is irrelevant here: `splitRoute` recurses, so a parent (`chat.*`) claims all descendants into
  one bundle *except* those a more specific child (`chat.visualizer`) splits into its own.
  Two patterns, two bundles, no precedence rules needed.
- **Keys are user-facing URL globs, consumed at request time by Rails**, to decide which route
  chunks to preload. This is why the schema has to stay a map — the URL is not derivable from
  the route name (route names come from the file tree; URLs come from `route-map.js` `path:`
  options, which the build never sees). Here ordering *does* matter: first match wins, so
  `chat/visualizer` must precede `chat/*`.

#### Glob rules: a single trailing `*`, both sides

No mid-path wildcards, no `:id` segments, no regexes. Both sides are either an exact string or a
prefix followed by one trailing star. This keeps the matchers trivial (a `==` or a
`start_with?`) and means the JS and Ruby sides can't drift in their interpretation.

On the **value** side this collapses further than it looks. `chat.*` means "`chat` and everything
beneath it" — but Embroider's `splitRoute` *always* claims descendants when it splits a route, so
that is simply "split at route `chat`". Strip a trailing `.*` and exact-match the remainder
against derived route names; the recursion does the rest, and the ported `shouldSplitRoute` never
needs the regex branch Embroider carries. Worth being explicit in the docs that a bare `chat` and
`chat.*` are therefore *identical* — the star is documentation, not behaviour — or authors will
reasonably assume the starless form splits only the parent's own files, which is not expressible.

On the **key** side, match against the request path with the site's `relative_url_root` stripped,
so subfolder installs work.

#### Preloading — the point of the URL keys

Without this, a user landing directly on `/chat/visualizer` pays a waterfall: HTML → core →
plugin entrypoint → *then* the router discovers it needs a route chunk. The URL keys let Rails
short-circuit that and emit the `<link>` up front, alongside the existing plugin modulepreloads.

Two pieces of work:

1. **Record route chunks in the plugin manifest.** `js_manager.rb:169` only stores chunks where
   `isEntry` is true; route chunks are dynamic entries, so they're written to disk but never
   recorded. `performRollup` must surface them (rollup gives `isDynamicEntry` + `facadeModuleId`
   per chunk — core's rolldown config already does precisely this in its `bundle-manifest`
   plugin, `rolldown.config.mjs:196`), keyed back to the `about.json` URL glob:
   ```json
   "routeBundles": [
     { "url": "chat/visualizer", "fileName": "chat_route-chat-visualizer-a1b2c3.digested.js" },
     { "url": "chat/*",          "fileName": "chat_route-chat-d4e5f6.digested.js" }
   ]
   ```
2. **Match at request time.** In `application_helper` / `_plugin_js.html.erb`, glob `request.path`
   against each plugin's `routeBundles` (first match wins) and emit a `<link rel="modulepreload">`
   — not `rel=preload`, since these are ES modules and `modulepreload` is what the existing
   plugin/chunk preloads already use (`_plugin_js.html.erb:21-27`).

Note this only helps the initial page load. Client-side transitions go through the router's
lazy `load()` as normal, which is the behaviour we want.

#### Route splitting applies to the `admin` entrypoint too

No special-casing needed, and nothing about the derivation changes: plugin admin assets use the
same layout (`admin/assets/javascripts/discourse/routes/admin-plugins/show/automation/edit.js`
→ route name `admin-plugins.show.automation.edit`), already dasherized to match `mapping-router`'s
`lazyRoute`. Core needs no change either — the admin bundle is just another
`<link rel=modulepreload data-plugin-name>`, so `loadPluginFromModulePreload` picks up its
`routes` export exactly like `main`'s.

Three things follow:

- **Partitioning is per-entrypoint.** `virtual:entrypoint:<name>` already receives only that
  entrypoint's module list; run the route-tree derivation over each independently. One
  `splitAtRoutes` map in `about.json` covers both, since Ember route names are globally unique —
  a pattern matching only admin route names simply produces no bundles in `main`.
- **Virtual route ids stay unscoped** — `virtual:route:<routeName>`. `main` and `admin` are inputs
  to a single rollup call and share an id namespace, but they already share the
  `discourse/plugins/<name>/…` compat-module namespace too, so non-clashing module names is an
  existing rule, not a new one. Route ids inherit it: a route name resolves to exactly one
  entrypoint, so the loader can find its module list unambiguously.
- **`routeBundles` in the manifest must be recorded per entrypoint**, so Rails only preloads
  admin route chunks on requests where it is already emitting the admin asset
  (`include_admin_asset`). Preloading an admin chunk for an anonymous user would be a leak of
  sorts and a waste besides.

Shared code between `main` and `admin` route chunks is hoisted into common chunks by rollup for
free, since they're inputs to the same build.

**One Discourse-specific guard.** Embroider nests *every* `templates/**` path, so
`templates/connectors/foo/bar` would be misread as a route named `connectors.foo.bar`. Core apps
don't have that directory; Discourse plugins do. Mostly moot once `.hbs` is out of the picture
(modern connectors are `.gjs` under `discourse/connectors/`), but excluding `templates/connectors/**`
and `templates/components/**` from the route tree costs a line and avoids a baffling failure.

### Ruby plumbing

**`lib/plugin/js_manager.rb`** — `compile_js_bundle` already holds the `plugin` object, so pass
`frontend: plugin.about_json_metadata&.dig("frontend")` into `Plugin::JsCompiler`. **Mix
`about.json` into the SHA1 cache digest at `:120-131`** — it isn't there today, so editing the
`frontend` key would not rebuild the bundle.

**`lib/plugin/js_compiler.rb`** — forward `frontend:` into the `opts` hash handed to
`AssetProcessor#rollup`. That hash is the natural carrier; no other transport needed.

**`lib/theme_javascript_compiler.rb`** — **deliberately not plumbed.** Themes never pass a
`frontend` config into `opts`, so the generator always takes the legacy path for them and no
theme can produce a second chunk. See §4.

This is the whole of the theme deferral: the asset-processor side is written generically and
works for themes the moment the config is passed, but the Ruby side simply doesn't pass it. The
compiler is constructed with only `(theme_id, theme_name, minify:)` today and the theme's raw
`about.json` lives in a sibling `ThemeField` (`target_id: Theme.targets[:about]`) it never sees
— so "don't plumb it" is the default, not extra work.

Consequence to accept knowingly: a theme that sets `frontend.staticModules` in `about.json` is
silently ignored rather than rejected. Since nothing validates `about.json` keys today anyway,
that's consistent — but it's the one place a theme author could be misled, so a warning when a
theme declares a `frontend` block is cheap and worth adding.

**Validation** — there is no schema anywhere; unknown `about.json` keys are silently ignored.
Good for compatibility, but nothing will catch `staticModule` or a `splitAtRoutes` glob that
matches no files. Worth a small validator that warns at compile time.

### Core runtime — `frontend/discourse/app/`

**`app.js`** — `loadPluginFromModulePreload` / `loadThemeFromModulePreload` become:

```js
const mod = await import(link.href);
const compatModules = mod.compatModules ?? mod.default;  // legacy bundles: default is everything
for (const [key, m] of Object.entries(compatModules)) {
  define(`discourse/plugins/${pluginName}/${key}`, () => m);
}
for (const { names, load } of mod.routes ?? []) {
  window._embroiderRouteBundles_.push({
    names,
    load: async () => {
      const routeModules = (await load()).default;
      return {
        default: Object.fromEntries(
          Object.entries(routeModules).map(([k, v]) => [`discourse/plugins/${pluginName}/${k}`, v])
        ),
      };
    },
  });
}
```

`window._embroiderRouteBundles_` is set by core's own embroider entrypoint, which is imported by
`app.js` — so it exists by the time this runs, but initialise it defensively.

**`mapping-router.js`** — no change needed. Because `names` is derived concretely at build time,
the router's exact `indexOf` match already works, and the existing `dasherize` override lines up
with the dasherized file paths the names come from.

## 4. The eager set, and two landmines

### The eager set

`compatModules` is everything Discourse still resolves **by name** at runtime:

| eager (`define()`d) | why |
|---|---|
| pre-/api-/instance-initializers | `loadInitializers` enumerates `requirejs.entries` (`app.js:221`) |
| `route-map` | `mapRoutes()` scans `requirejs.entries` for `/route-map$/` |
| plugin-outlet connectors | resolved by name by the outlet system |
| **services, models, adapters** | `@service chat` → `SuffixTrie` over `requirejs.entries` (`resolver.js:114`) |
| routes / controllers / templates | resolved by name — minus whatever `splitAtRoutes` claims |

**Helpers, components and modifiers are deliberately *not* eager.** Under `staticModules` they
are imported statically from `.gjs`, and resolver-based lookup for them is dropped.

**`.hbs` is not supported in this mode at all.** Assume it isn't used — no detection, no
compile-time errors, no graceful degradation. A static plugin that ships `.hbs` is simply
broken, and that's the author's problem. This is what lets the eager set stay as small as it is.

This also settles what `sharedModules` is for: the default export is reached by **ESM indexing**
from other bundles (`babel-resolve-plugin-imports` compiles cross-plugin imports into
`_plugin_chat["discourse/components/foo"]`), not through AMD. So `sharedModules` does *not*
need `define()`ing — `default` and `compatModules` stay genuinely separate sets, and only the
latter is registered.

Everything outside both sets — `lib/`, unshared `models/`, dead code — now tree-shakes, which it
cannot today because `import * as Mod` roots every module.

### The landmines

**(a) Two boot-time caches are never invalidated.** `lookupModuleBySuffix` memoises its trie on
first use, and `populate-template-map` snapshots `Object.keys(requirejs.entries)` once, in an
instance-initializer. Modules `define()`d later by a lazy route bundle are invisible to both.
Core's `wizard` split gets away with it because core templates sit at canonical paths that
ember-resolver finds directly; plugin/theme templates live at
`discourse/plugins/<n>/discourse/templates/...` and *only* `DiscourseTemplateMap` knows how to
map them. Fix centrally in the resolver, which is the single funnel for lazily added modules:

```js
addModules(modules) {
  for (const [key, value] of Object.entries(modules)) {
    define(key, () => value);
  }
  expireModuleTrieCache();
  DiscourseTemplateMap.setModuleNames(Object.keys(requirejs.entries));
}
```

`expireModuleTrieCache()` currently has exactly one caller: a test helper
(`tests/helpers/temporary-module-helper.js`), which does precisely this pair of calls.

**(b) Themes cannot code-split at all — so themes are deferred.** `theme_javascript_compiler.rb:52`
keeps only the chunk named `main` and drops the rest; the result is a single DB row served by
digest at `/theme-javascripts/:digest.js`. A second chunk would be silently discarded and the
theme would break at runtime. Plugins have none of this problem: they already emit multiple
chunks to disk next to the entrypoint, so a relative `import("./chunk-x.js")` just resolves.

**We are not fixing this now.** The asset-processor is written generically — nothing in the
generator or the `virtual:route:*` loader is plugin-specific — but `ThemeJavascriptCompiler`
never passes a `frontend` config, so themes always take the legacy path and can never reach the
code-splitting branch. The deferral is enforced by omission, which is what makes it safe.

When it *is* picked up, the cleanest fit looks like: make each chunk's filename *be* its content
digest, store one `JavascriptCache` row per chunk, and let the existing `theme-javascripts/:digest`
route serve them — a relative import from `/theme-javascripts/<digest>.js` then resolves to a
sibling digest with no URL rewriting anywhere.

## 5. Suggested order

1. Split the entrypoint contract (`compatModules` named export) with no behaviour change; core
   reads `mod.compatModules ?? mod.default`. Ships alone, no flag.
2. Fix the resolver cache invalidation (landmine (a)). Independently correct, unblocks the rest.
3. `frontend.staticModules` for **plugins** only: partition in the generator, plumb `about.json`
   through `JsManager` (+ cache digest). No route splitting yet — this alone buys tree-shaking,
   and shakes out the `.gjs`-only contract on a real plugin before any lazy loading is involved.
4. `splitAtRoutes` for plugins: port the route-tree derivation, add `virtual:route:*`, the
   `routes` export, and `_embroiderRouteBundles_` registration. Lazy loading works, with a
   waterfall on direct navigation. Dogfood on `chat`.
5. Preloading: surface route chunks in the plugin manifest, match the URL globs in Rails, emit
   the `modulepreload`. Removes the waterfall from step 4.
6. *(deferred)* Themes: multi-chunk persistence and serving, then pass `frontend` through
   `ThemeJavascriptCompiler` and everything above applies unchanged.
