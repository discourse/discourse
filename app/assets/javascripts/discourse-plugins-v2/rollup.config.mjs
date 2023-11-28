import { Addon } from "@embroider/addon-dev/rollup";
import { babel } from "@rollup/plugin-babel";
import commonjs from "@rollup/plugin-commonjs";
import { nodeResolve } from "@rollup/plugin-node-resolve";
import { resolve } from "path";
import { compilePluginFeatures } from "./lib/compile-plugin-features.cjs";

const addon = new Addon({
  srcDir: "src",
  destDir: "dist",
});

const Plugins = resolve("../../../../plugins");

export default {
  // This provides defaults that work well alongside `publicEntrypoints` below.
  // You can augment this if you need to.
  output: addon.output(),

  plugins: [
    // Follow the V2 Addon rules about dependencies. Your code can import from
    // `dependencies` and `peerDependencies` as well as standard Ember-provided
    // package names.
    addon.dependencies(),

    nodeResolve({
      modulePaths: [Plugins],
      jail: Plugins,
    }),

    commonjs(),

    compilePluginFeatures(Plugins, {
      connectors: ["extra-header-icons"],
      events: ["decorate-cooked-element", "decorate-non-stream-cooked-element"],
      markdownFeatures: true,
    }),

    // These are the modules that users should be able to import from your
    // addon. Anything not listed here may get optimized away.
    // By default all your JavaScript modules (**/*.js) will be importable.
    // But you are encouraged to tweak this to only cover the modules that make
    // up your addon's public API. Also make sure your package.json#exports
    // is aligned to the config here.
    // See https://github.com/embroider-build/embroider/blob/main/docs/v2-faq.md#how-can-i-define-the-public-exports-of-my-addon
    addon.publicEntrypoints(["**/*.js"]),

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

    // Remove leftover build artifacts when starting a new build.
    addon.clean(),
  ],
};
