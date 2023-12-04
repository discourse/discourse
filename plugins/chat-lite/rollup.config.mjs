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

  plugins: [
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
