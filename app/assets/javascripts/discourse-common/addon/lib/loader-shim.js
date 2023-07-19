// This can be removed once these are released
// https://github.com/embroider-build/embroider/issues/1530
// https://github.com/embroider-build/embroider/pull/1531
function esShim(m) {
  if (m.__esModule) {
    return m;
  } else {
    m = m.default;
    return { default: m, ...m };
  }
}

// Webpack has bugs, using globalThis is the safest
// https://github.com/embroider-build/embroider/issues/1545
let { define: __define__, require: __require__ } = globalThis;

// Ensure a package is in the runtime loader.js registry, therefore
// runtime-require()-able. Generally this is needed for anything used
// by admin/wizard/markdown-it/plugins/etc, as loader.js is the main
// way the "external" bundles interfaces with the main bundle.
//
// The general way to use it is:
//
//   import { importSync } from "@embroider/macros";
//
//   loaderShim("some-npm-pkg", () => importSync("some-npm-pkg"));
//
// Note that `importSync` is a macro which must be passed a string
// literal, therefore cannot be abstracted away here.
export default function loaderShim(pkg, callback) {
  if (!__require__.has(pkg)) {
    __define__(pkg, function () {
      return esShim(callback());
    });
  }
}
