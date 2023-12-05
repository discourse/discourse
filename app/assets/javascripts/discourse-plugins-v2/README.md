# discourse-plugins-v2

This is the build pipeline that aggregates v2 plugins and exposes them to the
discourse app.

Specifically – for every item in the plugin folder:

* If it does not have a `plugin.rb`, it is not a plugin
* If it has a `package.json` _and_ that it contains the `discourse-plugin`
  keyword, then it is considered a v2 plugin
* Otherwise, it is a v1 plugin

v1 plugins are handled by [discourse-plugins](../discourse-plugins/) in a
broccoli and AMD based build pipeline, whereas here we handle the v2 plugins
using a Rollup pipeline in the Ember v2 addon format.

## Plugin Features

Here we defined the concept of "plugin features", essentially extension points
in discourse.

### Connectors

In the v2 architecture, connectors are just regular components that accept the
proper arguments for that type of plugin outlet (could be none). We simply
invoke them as regular components on the discourse side.

See [chat-lite](../../../../plugins/chat-lite/src/connectors/) for how plugins
defines these, and the new [plugin-outlets](../../app/assets/javascripts/discourse/app/components/plugin-outlets/)
folder for how these are invoked from the discourse side.

### Events

Currently, this is made to migrate the `api.decorateCookedElement()` call, and
the `decorate-cooked-element`/`decorate-non-stream-cooked-element` "handlers"
are essentially the callbacks that you would previously register with that
imperative API.

See [checklist](../../../../plugins/checklist/assets/javascripts/events/) for
how plugins define these, and [post-cooked.js](../discourse/app/widgets/post-cooked.js)
for how these are consumed from the discourse side.

There are probably more cases where this design would work. In general, we want
to avoid imperative registrations using initializers, since that would force
the code to be loaded eagerly.

An alternative design to consider is to still keep around the imperative APIs
for registration, but break up the concept of initializers to more granular
life cycle events, so one would typically do the `decorateCookedElement` call
in, say, `initializers/topic`. A mix of these approaches may also work well.

### Markdown Features

These are features for `discourse-markdown`.

See [checklist](../../../../plugins/checklist/assets/javascripts/markdown-features/)
for how plugins define these, and [features.js](../../app/assets/javascripts/discourse/app/static/markdown-it/features.js)
for how we load them from the discourse side.

### Route Maps

These are the route maps for frontend routing.

It's not a very complete design at the moment, but should have enough substance
to show the vision. It mostly retains the same API as the existing route maps,
for better and for worse, but any route components would have to be imported.

See [chat-lite](../../../../plugins/chat-lite/src/route-maps/) for how plugins
define these.

It is currently integrated into discourse in two places:

1. [From within the router](../discourse/app/mapping-router.js)
2. [In this initializer](../discourse/app/instance-initializers/register-plugin-routes.js)

## Rollup Build

We use a custom [rollup plugin](./lib/compile-plugin-features.cjs) to walk the
`plugins` folder, find any v2 plugins, look at their `package.json` for any
exported plugin features, and then generate corresponding manifest files into
`src`, which gets compiled by rollup into `dist`, and export the built versions
of these aggregated features from our `package.json`.

The build can be run as a once-off task via `yarn build`, or in watch mode via
`yarn start`. Either way, the build will output the built modules under `dist`
and point the `exports` section to those built modules.
