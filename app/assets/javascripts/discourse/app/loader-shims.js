import { importSync } from "@embroider/macros";
import loaderShim from "discourse-common/lib/loader-shim";

loaderShim("@ember-compat/tracked-built-ins", () =>
  importSync("@ember-compat/tracked-built-ins")
);
loaderShim("@popperjs/core", () => importSync("@popperjs/core"));
loaderShim("handlebars", () => importSync("handlebars"));
loaderShim("message-bus-client", () => importSync("message-bus-client"));
loaderShim("tippy.js", () => importSync("tippy.js"));
loaderShim("virtual-dom", () => importSync("virtual-dom"));
