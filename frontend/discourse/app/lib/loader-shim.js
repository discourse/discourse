// Webpack has bugs, using globalThis is the safest
// https://github.com/embroider-build/embroider/issues/1545
let { define: __define__, require: __require__ } = globalThis;

// Traditionally, Ember compiled ES modules into AMD modules, which are then
// made usable in the browser at runtime via loader.js. In a classic build, all
// the modules, including any external ember-auto-imported dependencies, are
// added to the loader.js registry and therefore require()-able at runtime.
//
// Overtime, the AMD-ness of the modules, the ability to define arbitrarily
// named modules and the ability to require any modules and even enumerate the
// known modules at runtime (require.entries/_eak_seen) became heavily relied
// upon, which is problematic. For one thing, these features don't align well
// with ES modules semantics, and it is also impossible to perform tree-shaking
// as the presence of a particular module could end up being important even if
// it appears to be unused in the static analysis.
//
// For Discourse, the AMD/loader.js mechanism is an important glue. It is what
// allows Discourse core/admin/plugins to all be separate .js bundlers
// and be "glued back together" as full module graph in the browser.
//
// For instance, a plugin module can `import Post from "discourse/models/post";
// because the babel plugin compiled discourse/models/post.js into an AMD
// module into app.js (`define("discourse/models/post", ...)`), which makes
// it available in the runtime loader.js registry, and the plugin module itself
// is also compiled into AMD with a dependency on the core module.
//
// This has similar drawbacks as the general problem in the ecosystem, but in
// addition, it has a particular bad side-effect that any external dependencies
// (NPM packages) we use in core will automatically become a defacto public API
// for plugins to use as well, making it difficult for core to upgrade/remove
// dependencies (and thus so as introducing them in the first place).
//
// Ember is aggressively moving away from AMD modules and there are active RFCs
// to explore the path to deprecating AMD/loader.js. While it would still be
// fine (in the medium term at least) for us to use AMD/loader.js as an interop
// mechanism between our bundles, we will have to be more conscious about what
// to make available to plugins via this mechanism.
//
// In the meantime Embroider no longer automatically add AMD shims for external
// dependencies. In order to preserve compatibility for plugins, this utility
// allows us to manually force a particular module to be included in loader.js
// and available to plugins. Overtime we should review this list and start
// deprecating any accidental leakages.
//
// The general way to use it is:
//
//   import { importSync } from "@embroider/macros";
//
//   loaderShim("some-npm-pkg", () => importSync("some-npm-pkg"));
//
// Note that `importSync` is a macro which must be passed a string
// literal, therefore cannot be abstracted away.
export default function loaderShim(pkg, callback) {
  if (!__require__.has(pkg)) {
    __define__(pkg, callback);
  }
}
