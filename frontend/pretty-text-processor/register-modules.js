import * as deprecationWorkflow from "discourse/deprecation-workflow";
import * as avatarUtils from "discourse/lib/avatar-utils";
import * as caseConverter from "discourse/lib/case-converter";
import * as deprecated from "discourse/lib/deprecated";
import * as escape from "discourse/lib/escape";
import * as getUrl from "discourse/lib/get-url";
import * as libObject from "discourse/lib/object";
import loadPluginFeatures from "discourse/static/markdown-it/features";
import { runtime } from "./runtime-state.js";

const ptModules = import.meta.glob("../pretty-text/addon/**/*.js", {
  eager: true,
});
const mdModules = import.meta.glob("../discourse-markdown-it/src/**/*.js", {
  eager: true,
});

function register(prefix, base, mods) {
  for (const [key, mod] of Object.entries(mods)) {
    define(
      `${prefix}/${key.slice(base.length).replace(/\.js$/, "")}`,
      () => mod
    );
  }
}

// Registers the core module surface into loader.js so plugins keep working
// (`require("pretty-text/…")`, `require("discourse-markdown-it/…")`), plus the
// small I18n / helpers shims that back a few core imports server-side.
export function registerCoreModules() {
  register("pretty-text", "../pretty-text/addon/", ptModules);
  register("discourse-markdown-it", "../discourse-markdown-it/src/", mdModules);

  define("discourse/lib/avatar-utils", () => avatarUtils);
  define("discourse/deprecation-workflow", () => deprecationWorkflow);
  define("discourse/lib/get-url", () => getUrl);
  define("discourse/lib/object", () => libObject);
  define("discourse/lib/deprecated", () => deprecated);
  define("discourse/lib/escape", () => escape);
  define("discourse/lib/case-converter", () => caseConverter);
  define("discourse/static/markdown-it/features", () => ({
    default: loadPluginFeatures,
  }));

  const I18n = { t: (a, b) => globalThis.__Ruby.t(a, b) };
  globalThis.I18n = I18n; // legacy compat for vendored pretty-text blobs
  define("I18n", ["exports"], (exports) => (exports.default = I18n));
  define("discourse-i18n", ["exports"], (exports) => {
    exports.default = I18n;
    exports.i18n = I18n.t;
  });
  define("discourse/lib/helpers", ["exports"], (exports) => {
    exports.helperContext = () => ({
      siteSettings: { avatar_sizes: runtime.avatarSizes },
    });
  });
}
