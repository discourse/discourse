import { importSync } from "@embroider/macros";

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

export default function loaderShim(pkg, callback) {
  if (!require.has(pkg)) {
    define(pkg, function () {
      return esShim(callback());
    });
  }
}

loaderShim("@ember-compat/tracked-built-ins", () =>
  importSync("@ember-compat/tracked-built-ins")
);
loaderShim("@popperjs/core", () => importSync("@popperjs/core"));
loaderShim("handlebars", () => importSync("handlebars"));
loaderShim("message-bus-client", () => importSync("message-bus-client"));
loaderShim("tippy.js", () => importSync("tippy.js"));
loaderShim("virtual-dom", () => importSync("virtual-dom"));
