import { importSync } from "@embroider/macros";
import loaderShim, { defineModules } from "discourse/lib/loader-shim";

// AMD shims for the test bundle, see the comment in loader-shim.js
loaderShim("pretender", () => importSync("pretender"));
loaderShim("qunit", () => importSync("qunit"));
loaderShim("sinon", () => importSync("sinon"));
loaderShim("ember-qunit", () => importSync("ember-qunit"));
loaderShim("@faker-js/faker", () => importSync("@faker-js/faker"));
loaderShim("@ember/test-helpers", () => importSync("@ember/test-helpers"));

const rawModules = import.meta.glob("./{fixtures,helpers}/**/*.{gjs,js}", {
  eager: true,
});

const compatModules = {};
for (let [key, mod] of Object.entries(rawModules)) {
  key = key.replace(/\.(gjs|js)$/, "");
  compatModules[key] = mod;
}

defineModules("discourse/tests", compatModules);
