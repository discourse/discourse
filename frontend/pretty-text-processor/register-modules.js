import markdownit from "markdown-it";
import discourseModules from "virtual:discourse-modules";
import xss from "xss";
import * as deprecated from "discourse/lib/deprecated";
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

function defineMultiple(prefix, base, mods) {
  for (const [key, mod] of Object.entries(mods)) {
    define(
      `${prefix}/${key.slice(base.length).replace(/\.js$/, "")}`,
      () => mod
    );
  }
}

// Registers the core module surface into loader.js so plugins can require() it.
export function registerCoreModules() {
  defineMultiple("pretty-text", "../pretty-text/addon/", ptModules);
  defineMultiple(
    "discourse-markdown-it",
    "../discourse-markdown-it/src/",
    mdModules
  );

  defineMultiple("discourse", "../discourse/app/", discourseModules);
  define("discourse/lib/deprecated", () => deprecated);

  globalThis.I18n = i18nShim.default;
  define("I18n", () => ({ default: i18nShim.default }));
  define("discourse-i18n", () => i18nShim);
  define("discourse/lib/helpers", () => helpersShim);

  define("markdown-it", () => ({ default: markdownit }));
  define("xss", () => ({ default: xss }));
}
