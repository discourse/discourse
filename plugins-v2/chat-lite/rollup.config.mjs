import { babel } from "@rollup/plugin-babel";
import Plugin from "discourse-plugin-dev/rollup";

const plugin = new Plugin({
  srcDir: "src",
  destDir: "dist",
});

export default {
  // This provides defaults that work well alongside `publicEntrypoints` below.
  // You can augment this if you need to.
  output: plugin.output(),

  watch: "src/**/*",

  plugins: [
    // These are the modules that users should be able to import from your
    // addon. Anything not listed here may get optimized away.
    // By default all your JavaScript modules (**/*.js) will be importable.
    // But you are encouraged to tweak this to only cover the modules that make
    // up your addon's public API. Also make sure your package.json#exports
    // is aligned to the config here.
    // See https://github.com/embroider-build/embroider/blob/main/docs/v2-faq.md#how-can-i-define-the-public-exports-of-my-addon
    plugin.publicEntrypoints(["**/*.js", "index.js"]),

    // Ensure that any plugin features are exported from package.json.
    plugin.exportPluginFeatures(),

    // Follow the V2 Addon rules about dependencies. Your code can import from
    // `dependencies` and `peerDependencies` as well as standard Ember-provided
    // package names.
    plugin.dependencies(),

    // This babel config should *not* apply presets or compile away ES modules.
    // It exists only to provide development niceties for you, like automatic
    // template colocation.
    //
    // By default, this will load the actual babel config from the file
    // babel.config.json.
    babel({
      extensions: [".js", ".gjs"],
      babelHelpers: "bundled",
    }),

    // Ensure that .gjs files are properly integrated as Javascript
    plugin.gjs(),

    // Remove leftover build artifacts when starting a new build.
    plugin.clean(),
  ],
};
