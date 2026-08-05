import markdownit from "markdown-it";
import xss from "xss";
import * as deprecationWorkflow from "discourse/deprecation-workflow";
import * as avatarUtils from "discourse/lib/avatar-utils";
import * as caseConverter from "discourse/lib/case-converter";
import * as deprecated from "discourse/lib/deprecated";
import * as escape from "discourse/lib/escape";
import * as getUrl from "discourse/lib/get-url";
import * as libObject from "discourse/lib/object";
import loadPluginFeatures from "discourse/static/markdown-it/features";
import * as helpersShim from "./shims/helpers.js";
import * as i18nShim from "./shims/i18n.js";

// oneboxer and upload-short-url are browser-only; they were never usable in
// the server-side context.
const ptModules = import.meta.glob(
  [
    "../pretty-text/addon/**/*.js",
    "!../pretty-text/addon/oneboxer.js",
    "!../pretty-text/addon/upload-short-url.js",
  ],
  { eager: true }
);
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

// Registers the core module surface into loader.js so plugins can require() it.
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

  globalThis.I18n = i18nShim.default; // legacy compat for vendored pretty-text blobs
  define("I18n", () => ({ default: i18nShim.default }));
  define("discourse-i18n", () => i18nShim);
  define("discourse/lib/helpers", () => helpersShim);

  // Modules some plugins import into their server-side markdown features
  define("markdown-it", () => ({ default: markdownit }));
  define("xss", () => ({ default: xss }));
  define("@embroider/macros", ["exports", "require"], (exports, req) => {
    exports.importSync = req;
  });
  define("discourse/lib/loader-shim", ["exports", "require"], (
    exports,
    req
  ) => {
    exports.default = (id, callback) => {
      if (!req.has(id)) {
        define(id, callback);
      }
    };
  });
  define("@ember/debug", ["exports"], (exports) => {
    exports.registerDeprecationHandler = () => {};
  });
  define("discourse/lib/environment", ["exports"], (exports) => {
    exports.isRailsTesting = () => false;
  });
  define("discourse/lib/source-identifier", ["exports"], (exports) => {
    exports.default = () => undefined;
    exports.consolePrefix = () => "";
  });
}
