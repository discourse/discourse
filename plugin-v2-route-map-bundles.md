# Route bundles from the route map

A plugin declares its lazy bundles inline in its route map, with a `bundleName` option. The build
parses the map and derives both the route names in each bundle and the urls that reach them.
`splitAtRoutes` in `about.json` goes away.

Under `staticModules`, no route is eager. Everything a route map names goes in a bundle, and
`routes`, `controllers` and route `templates` are no longer registered by name at all.

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

Only plugins that opt into `staticModules` get parsed. Everything else imports its routes eagerly
and needs no bundles, so a map the parser cannot read is none of its business. This matters:
`discourse-docs` builds its path from a site setting, and `discourse-doc-categories` reads a
service and returns early. Both are perfectly good route maps, neither is readable, and neither
wants a bundle.

`discourse-route-maps` parses every map in a `buildStart` hook, with the `this.parse` rollup gives
every plugin. It cannot wait for `moduleParsed`: the entrypoint's own source is generated from the
derived tables, and the maps only enter the module graph because that entrypoint imports them.
`buildStart` runs before any module loads, which is early enough.

Themes reach the same rollup config through `ThemeJavascriptCompiler`, which supplies no core
maps, so a `resource` mount could not be resolved for them. Themes derive no bundles at all, which
is what they do today.

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

There is no fallback. Under `staticModules` a map we cannot read means bundles we cannot derive,
and nothing would load those routes at all.

`Plugin::JsCompiler` turns a compile error into a module that throws when the bundle is evaluated
(`js_compiler.rb:37`), so this fails the plugin in the browser rather than the Ruby process. That
is what CI reports.

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
- **Bundle.** `opts.bundleName`, or the nearest ancestor that sets one, or `default`. Only core's
  own routes can end up with no bundle.

Ember creates `index`, `loading` and `error` routes with no `this.route` call, so no route map
names them. A route file with one of those suffixes takes the bundle of the route it hangs off,
or it drops out of the bundle its siblings are in.

Each entrypoint yields two tables in the manifest: route name to bundle name, and bundle name to
the URL globs that reach it.

## Eagerness

`EAGER_DIRECTORIES` exists because Discourse looks these modules up by name at runtime. `routes`,
`controllers` and `templates` come out of it. `@embroider/router` asks for a bundle, and the bundle
carries the route, its controller and its template, so registering them by name as well would
defeat the split. What is left is `connectors`, `services`, `models`, `adapters` and
`discourse-markdown`.

Dropping `templates` also drops `templates/connectors` and `templates/components`, the pre-`.gjs`
spellings of a connector and a component template. `staticModules` is opt-in and a plugin taking it
up writes neither. Chat has none.

A module that merely lives under `routes/` is unaffected. Chat's `routes/chat-channel-decorator` is
a mixin imported by two route files, and it reaches the bundle through that import, the way
components and lib already do.

What no route map names, and nothing imports, is in no chunk at all. That is the intent: it is
unreachable at runtime either way, and it used to be carried anyway.

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
- `route_bundle_for_path` (`js_manager.rb:64`) is unchanged. It matches first-one-wins, so the
  build emits urls sorted by literal segment count: `u/*/preferences/chat/*` must beat `chat/*`
  whatever order the routes were declared in.
- `about.json` keeps `staticModules` and `sharedModules`. `splitAtRoutes` is deleted.

## Cross-check

The build has two views of the same routes: the parsed maps, and the file tree that `routeNameFor`
walks (`rollup-virtual-imports.js:113`). Either disagreement fails the compile:

- A `bundleName` on a route with no route, controller or template file.
- A route file whose derived name is in no route map.

The implicit `index`, `loading` and `error` routes are already handled when deriving, so they do
not need exempting again. The check does have to compare against all of a plugin's maps together:
`preferences.chat` is a file under chat's `routes/`, and its DSL entry is in
`preferences-chat-route-map.js`.

Chat has four files no route map names. `chat-channel-decorator` is a false positive: it is a
mixin, imported rather than resolved. The check has to allow that, which means it cannot run on
file paths alone — it needs to know what the bundle actually pulled in.

The other three — `chat-channel-legacy`, `chat-draft-channel` and `chat.channel.info.search` — are
unreachable, and are now absent from the build entirely.

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

1. **Parser only.** Done. Unreadable maps fail the compile.
2. **Core maps and `resource` mounts.** Done. All 28 resource maps across the 50 installed plugins
   mount, so an unmounted `resource` is a build error.
3. **Bundles.** Done. Chat's three bundles come out one for one against `splitAtRoutes`.
4. **URLs.** Done. `splitAtRoutes` deleted.
4b. **No eager routes.** Done. `routes`, `controllers` and `templates` leave `EAGER_DIRECTORIES`,
   and every plugin route falls into `default` if its map names no bundle.
5. **Cross-check.** Not started, and still blocked on chat's four leftovers.

Still owed from increment 1: a test comparing the derived tree against the runtime one from
`mapRoutes()`. Nothing but that test will catch the naming rules drifting apart.
