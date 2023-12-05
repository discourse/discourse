# chat-lite

This package exists as a minimal demo of a frontend-only v2 plugin.

## package.json

A v2 plugin is a valid, well-behaved NPM package.

For starter, this means it has a valid pacakge.json with, at minimum, a unique
package `name` and `version`, optionally `private: true` (if not meant to be
published on NPM).

Under `keywords`, it should also have `discourse-plugin` to opt-into the v2
pipeline and to distinguish it from existing v1/legacy plugins.

It should declare its NPM dependencies normally. For example, chat-lite depends
on `lodash`. These are regular runtime `dependencies` (not `devDependencies`).

If there are packages that it expects discourse to provide, it may list them in
`peerDependencies` instead. These could be something like `jquery` or `moment`.
However, discourse would have to explicitly choose to make them available to v2
plugins as a public API. Specifically they will have to be listed as peer deps
of [discourse-plugins-v2](../../app/assets/javascripts/discourse-plugins-v2/)
for this to work.

If it needs access to the v2 plugin API, which it most likely will, then it
should have [discourse-plugin](../../app/assets/javascripts/discourse-plugin/)
under `peerDependencies` as well.

As an exception to the above, v2 plugins automatically have access to the
[standard ember packages](https://github.com/embroider-build/embroider/blob/ba9fd29a52f7d4791a859a5add40fd394cc9c51c/packages/shared-internals/src/ember-standard-modules.ts),
so it can, for example, import from `@glimmer/component`.

Finally, a v2 plugin is expected to declare any "plugin features" under the
`exports` section of its `package.json`. As long as the exported plugin
features follow the expected naming convention (the keys of the map), we don't
really care how the files are internally structured (the values of the map).

## Rollup build (discourse-plugin-dev)

chat-lite uses [rollup](https://rollupjs.org) to compile its plugin features,
using the [discourse-plugin-dev](../discourse-plugin-dev/) package to automate
some of the common functionalities required in the build.

The build can be run as a once-off task via `yarn build`, or in watch mode via
`yarn start`. Either way, the build will output the built modules under `dist`
and point the `exports` section to those built modules.

## Structure

Some of the files under `./src` are "plugin features" – specifically:

* `./src/connectors/*.gjs`
* `./src/markdown-features/*.js`
* `./src/route-maps/*.js`

See [discourse-plugins-v2](../../app/assets/javascripts/discourse-plugins-v2/)
for detailed descriptions of which each of these does.

Everything else that wasn't listed above isn't itself a plugin feature (i.e.
isn't a public interface of the v2 plugin), but are things that are potentially
used by one or more of the plugin features (or, if unused, then it's dead code
that gets dropped by the build).

They get pulled into the build via imports, so the structure here are merely a
naming convention (technically that can be true for the plugin features too,
but `discourse-plugin-dev` does not currently offer a way to customize the
locations other than the root `srcDir`):

* `./components/*.gjs` - these are regular components that we invoked within
  connectors and routes.
* `./routes/*.gjs` – these are "route components" that uses the [v2 route API](../../app/assets/javascripts/discourse-plugin/src/routing/route.js);
  see the [discourse-plugin](../../app/assets/javascripts/discourse-plugin/)
  README for more details.
* `./services/*.js` – these are services we use internally in the plugin, based
  on [ember-polaris-service](https://github.com/chancancode/ember-polaris-service).

Of course, plugins can have additional code like utils, helpers, etc, as they
wish. Everything will be private to the plugin by default unless explicitly
exported from `package.json`.
