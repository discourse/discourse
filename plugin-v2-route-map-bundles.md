# Route bundles from the route map

A plugin declares its lazy bundles inline in its route map, with a `bundleName` option. The build
parses the map and derives both the route names in each bundle and the URLs that reach them.
`splitAtRoutes` in `about.json` goes away.

```js
// plugins/chat/assets/javascripts/discourse/chat-route-map.js
this.route("chat", { bundleName: "chat" }, function () {
  this.route("disabled", { bundleName: "foo" });
  this.route("search", { bundleName: "foo" });
  this.route("channel", { path: "/c/:channelTitle/:channelId" }, function () { ... });
});
```

Today the author writes route names in `about.json` and URL globs beside them, and keeps the two in
sync by hand. The route map already holds both.

## Reading the maps

Route maps are parsed, never run. Plugin and theme code is not trusted enough to evaluate in the
asset processor.

Rollup has already parsed the plugin's own maps. `isEagerModule` keeps every `*-route-map` in the
eager set (`rollup-virtual-imports.js:44`), so each one is a module in the graph. A `moduleParsed`
hook reads `ModuleInfo.ast` off each. Core's two maps are not in the graph, so pass their source to
`this.parse`. Both give the same ESTree `Program`, so one walker covers them.

Two default export shapes are valid:

- `export default function () { ... }`, mounted at the root.
- `export default { resource, map() { ... } }`, mounted under an existing route. `path` is also
  set on some of these. `mapping-router.js` ignores it, so the parser ignores it too.

Inside a map body the parser accepts one statement form: a call to `this.route` with a string name,
an optional object literal of options with literal values, and an optional trailing function. The
function body recurses.

Anything else is unreadable. A computed name, a spread in the options, a `this.route` inside a loop
or a conditional, or a `map` that points at a function defined elsewhere. Raise an error naming the
plugin and the source location, and fail that plugin's compile.

There is no fallback. A map we cannot read means bundles we cannot derive, and the plugin would
ship its routes eagerly with nothing to say so.

Core's two maps are the exception. Their `Site.currentProp` loops are known, and the parser skips
them by name.

## Inputs

`js_manager.rb:109` already puts the plugin's own `*-route-map.js` files in `tree`. Add core's two
maps, read from disk:

- `frontend/discourse/app/routes/app-route-map.js`
- `frontend/discourse/admin/routes/admin-route-map.js`

Core's maps are needed to resolve `resource` mounts. Chat's `admin-chat-route-map.js` mounts on
`admin.adminPlugins.show`, which resolves through `admin-route-map.js:435` to
`/admin/plugins/:plugin_id`. Chat's webhook routes then derive to `admin/plugins/*/hooks`.

Both files join the compile digest, so a core route change rebuilds every plugin. Reading them from
disk keeps `Plugin::JsManager.compile!` independent of core's build output.

## Deriving

For each route:

- **Name.** Parent name, a dot, then the given name. With `resetNamespace` the given name stands
  alone. A name that already contains dots is literal.
- **Path.** `opts.path ?? name`, joined onto the parent path.
- **Glob.** The path with each `:segment` replaced by `*`.
- **Bundle.** `opts.bundleName`, or the nearest ancestor that sets one. No bundle means eager.

Each entrypoint yields two tables in the manifest: route name to bundle name, and bundle name to
the URL globs that reach it.

## Consumers

- `splitBasesFor` and `splitBaseFor` (`rollup-virtual-imports.js:136`, `:143`) become a lookup in
  the name-to-bundle table. Longest-prefix matching goes with them. A bundle is a set of names, not
  a subtree, so siblings can share one.
- `virtual:route:<base>` becomes `virtual:route:<bundleName>` (`rollup-virtual-imports.js:288`).
  `routeBundlesFor` keys by bundle name.
- The `names:` array (`rollup-virtual-imports.js:274`) keeps its shape. It comes from the DSL
  instead of from file paths.
- `asset-processor-rollup.js:163` is unchanged apart from the key.
- `urls_by_route` and `route_bundles_for` (`js_manager.rb:267`, `:256`) read the manifest instead
  of `about.json`.
- `route_bundle_for_path` (`js_manager.rb:71`) keeps `File.fnmatch?`, but sorts globs by literal
  segment count first. `chat/c/*/*` must beat `chat` whatever the emission order.
- `about.json` keeps `staticModules` and `sharedModules`. `splitAtRoutes` is deleted.

## Cross-check

The build has two views of the same routes: the parsed maps, and the file tree that `routeNameFor`
walks (`rollup-virtual-imports.js:113`). Either disagreement fails the compile:

- A `bundleName` on a route with no route, controller or template file.
- A route file whose derived name is in no route map.

Two things the second check has to allow, or it fires on correct code:

- Ember creates `index`, `loading` and `error` routes with no DSL entry. Exempt those suffixes.
- Compare against all of a plugin's maps together. `preferences.chat` is a file under chat's
  `routes/`, and its DSL entry is in `preferences-chat-route-map.js`.

Chat still has four files left over after that: `chat-channel-decorator`, `chat-channel-legacy`,
`chat-draft-channel` and `chat.channel.info.search`. Each is either dead or missing a DSL entry.
They have to be resolved before this check can land.

## Known gaps

- **Generated core routes.** `app-route-map.js` builds its filter and `/top/:period` routes in five
  `Site.currentProp(...).forEach` loops (`:25`, `:38`, `:231`, `:241`, `:271`). The parser cannot
  read them, so they are missing from the derived tree. A plugin mounting under `discovery.filter`
  resolves to nothing.
- **Two plugins on one route.** `RouteNode.route` (`mapping-router.js:45`) merges children and
  accumulates paths at runtime. The build sees one plugin at a time. Derived URLs are per-plugin,
  which is what preloading needs, but the derived tree is not the whole tree.
- **Duplicated rules.** The parser restates the naming and path rules that `mapping-router.js` and
  Ember's router DSL implement. Nothing enforces agreement. The increment 1 test is what catches
  drift, so it needs real breadth.
- **Case.** `BareRouter#lazyRoute` dasherizes before matching (`mapping-router.js:11`). Names
  emitted for `@embroider/router` must agree on case with the DSL.

## Increments

1. **Parser only.** Parse the plugin's own maps, write the tree to the manifest, consume nothing.
   Unreadable maps fail the compile from here on. Test the tree against the runtime one for a
   spread of plugins.
2. **Core maps and `resource` mounts.** Add the two core files to the tree and the digest. Still
   consume nothing.
3. **Bundles.** Route name to bundle drives chunking. `splitAtRoutes` still owns preload URLs, so
   diff the two on chat.
4. **URLs.** Preload globs come from the derived tree. Delete `splitAtRoutes`.
5. **Cross-check.** Both checks as build errors, once chat's leftovers are resolved.
