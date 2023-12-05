# discourse-plugin-dev

A rollup build pipeline for v2 plugins.

To see it in action, see [chat-lite](../chat-lite/).

Most plugins will likely want to use this, however, it is not required. As an
alternative, the [checklist](../checklist/) v2 plugin demonstrates how that can
be set up manually without a build.

Here are the various features of the rollup plugin. It is loosely based on the
v2 addon build (`@embroider/addon-dev`) and internally shares some code. Note
that there is no requirement that (and no utility in) a v2 plugin is a valid
Ember addon.

* `plugin.exportPluginFeatures()`: this watches the files in the `srcDir` (in
  this case, `./src/`, but it can be customized), emit ("admit") any plugin
  features into the build, and ignore the rest (unless they are subsequently
  imported into the build by one of the plugin features). Essentially this is
  the logical entrypoint of the build. It is also in charge of keeping the
  `exports` map up-to-date after each build. If there are existing entries in
  the `exports` map that aren't plugin features, the plugin will take care to
  keep them around.

* `plugin.dependencies()`: this is inherited from `@embroider/addon-dev`. Its
  purpose is to flag any declared `dependencies`, `peerDependencies` and the
  "standard Ember packages" as `external`, so you don't get a warning from
  rollup if you try to import them. Note that the default behavior of rollup
  is to implicitly mark any resolvable modules as external with a warning, so
  things would have "worked" with or without this. We could choose to be
  stricter about that and emit build errors instead.

* `plugin.gjs()`: also inherited from `@embroider/addon-dev`, it takes `.gjs`
  modules and compiles them into regular `.js` modules.

* `plugin.clean()`: also inherited from `@embroider/addon-dev`, it empties out
  the `dist` folder at the beginning of each build.

* Not included in here directly, like v2 Ember addons, v2 plugins will also
  want to use the babel plugin to compile away any non-standard/unstable JS
  features.
