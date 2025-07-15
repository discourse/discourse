performance.mark("discourse-init");
const initEvent = new CustomEvent("discourse-init");
document.dispatchEvent(initEvent);

import "./setup-deprecation-workflow";
import "decorator-transforms/globals";
import "./loader"; // todo, loader.js from npm?
import "./loader-shims";
import "./discourse-common-loader-shims";
import "./global-compat";
import "./compat-modules";
import { importSync } from "@embroider/macros";
import compatModules from "@embroider/virtual/compat-modules";
import { registerDiscourseImplicitInjections } from "discourse/lib/implicit-injections";

// Register Discourse's standard implicit injections on common framework classes.
registerDiscourseImplicitInjections();

import Application from "@ember/application";
import { VERSION } from "@ember/version";
import "discourse/lib/theme-settings-store";
// import require from "require";
import { normalizeEmberEventHandling } from "discourse/lib/ember-events";
import { isTesting } from "discourse/lib/environment";
import { withPluginApi } from "discourse/lib/plugin-api";
import PreloadStore from "discourse/lib/preload-store";
import { buildResolver } from "discourse/resolver";

function populatePreloadStore() {
  let setupData;
  const setupDataElement = document.getElementById("data-discourse-setup");
  if (setupDataElement) {
    setupData = setupDataElement.dataset;
  }

  let preloaded;
  const preloadedDataElement = document.getElementById("data-preloaded");
  if (preloadedDataElement) {
    preloaded = JSON.parse(preloadedDataElement.dataset.preloaded);
  }

  const keys = Object.keys(preloaded);
  if (keys.length === 0) {
    throw "No preload data found in #data-preloaded. Unable to boot Discourse.";
  }

  keys.forEach(function (key) {
    PreloadStore.store(key, JSON.parse(preloaded[key]));

    if (setupData.debugPreloadedAppData === "true") {
      // eslint-disable-next-line no-console
      console.log(key, PreloadStore.get(key));
    }
  });
}

populatePreloadStore();

let adminCompatModules = {};
if (PreloadStore.get("currentUser")?.staff) {
  adminCompatModules = (await import("admin/compat-modules")).default;
}

const _pluginCallbacks = [];
let _unhandledThemeErrors = [];

window.moduleBroker = {
  lookup: function (moduleName) {
    return require(moduleName);
  },
};

for (const link of document.querySelectorAll("link[rel=modulepreload]")) {
  const themeId = link.dataset.themeId;
  const compatModules = (await import(/* @vite-ignore */ link.href)).default;
  for (const [key, mod] of Object.entries(compatModules)) {
    define(`discourse/theme-${themeId}/${key}`, () => mod);
  }
}

class Discourse extends Application {
  modulePrefix = "discourse";
  rootElement = "#main";

  customEvents = {
    paste: "paste",
  };

  Resolver = buildResolver("discourse").withModules({
    ...compatModules,

    "discourse/templates/discovery/list": importSync(
      "discourse/templates/discovery/list"
    ),
    "discourse/controllers/discovery/list": importSync(
      "discourse/controllers/discovery/list"
    ),
    ...adminCompatModules,
  });

  // Start up the Discourse application by running all the initializers we've defined.
  start() {
    printDebugInfo();

    document.querySelectorAll("noscript").forEach((el) => el.remove());

    // Rewire event handling to eliminate event delegation for better compat
    // between Glimmer and Classic components.
    normalizeEmberEventHandling(this);

    if (Error.stackTraceLimit) {
      // We need Errors to have full stack traces for `lib/source-identifier`
      Error.stackTraceLimit = Infinity;
    }

    // Our scroll-manager service takes care of storing and restoring scroll position.
    // Disable browser handling:
    window.history.scrollRestoration = "manual";

    loadInitializers(this);
  }

  _registerPluginCode(version, code) {
    _pluginCallbacks.push({ version, code });
  }

  ready() {
    performance.mark("discourse-ready");
    document.querySelector("#d-splash")?.remove();
  }
}

function moduleThemeId(moduleName) {
  const match = moduleName.match(/^discourse\/theme\-(-?\d+)\//);
  if (match) {
    return parseInt(match[1], 10);
  }
}

function fireThemeErrorEvent({ themeId, error }) {
  const event = new CustomEvent("discourse-error", {
    cancelable: true,
    detail: { themeId, error },
  });

  const unhandled = document.dispatchEvent(event);

  if (unhandled) {
    _unhandledThemeErrors.push(event);
  }
}

export function getAndClearUnhandledThemeErrors() {
  const copy = _unhandledThemeErrors;
  _unhandledThemeErrors = [];
  return copy;
}

/**
 * Logic for loading initializers. Similar to ember-cli-load-initializers, but
 * has some discourse-specific logic to handle loading initializers from
 * plugins and themes.
 */
function loadInitializers(app) {
  let initializers = [];
  let instanceInitializers = [];

  let discourseInitializers = [];
  let discourseInstanceInitializers = [];

  for (let moduleName of Object.keys(requirejs.entries)) {
    if (moduleName.startsWith("discourse/") && !moduleName.endsWith("-test")) {
      // In discourse core, initializers follow standard Ember conventions
      if (moduleName.startsWith("discourse/initializers/")) {
        initializers.push(moduleName);
      } else if (moduleName.startsWith("discourse/instance-initializers/")) {
        instanceInitializers.push(moduleName);
      } else {
        // https://meta.discourse.org/t/updating-our-initializer-naming-patterns/241919
        //
        // For historical reasons, the naming conventions in plugins and themes
        // differs from Ember:
        //
        // | Ember                 | Discourse          |                        |
        // | initializers          | pre-initializers   | runs once per app load |
        // | instance-initializers | (api-)initializers | runs once per app boot |
        //
        // In addition, the arguments to the initialize function is different –
        // Ember initializers get either the `Application` or `ApplicationInstance`
        // as the only argument, but the "discourse style" gets an extra container
        // argument preceding that.

        const themeId = moduleThemeId(moduleName);

        if (
          themeId !== undefined ||
          moduleName.startsWith("discourse/plugins/")
        ) {
          if (moduleName.includes("/pre-initializers/")) {
            discourseInitializers.push([moduleName, themeId]);
          } else if (
            moduleName.includes("/initializers/") ||
            moduleName.includes("/api-initializers/")
          ) {
            discourseInstanceInitializers.push([moduleName, themeId]);
          }
        }
      }
    }
  }

  for (let moduleName of initializers) {
    app.initializer(resolveInitializer(moduleName));
  }

  for (let moduleName of instanceInitializers) {
    app.instanceInitializer(resolveInitializer(moduleName));
  }

  for (let [moduleName, themeId] of discourseInitializers) {
    app.initializer(resolveDiscourseInitializer(moduleName, themeId));
  }

  for (let [moduleName, themeId] of discourseInstanceInitializers) {
    app.instanceInitializer(resolveDiscourseInitializer(moduleName, themeId));
  }

  // Plugins that are registered via `<script>` tags.
  for (let [i, callback] of _pluginCallbacks.entries()) {
    app.instanceInitializer({
      name: `_discourse_plugin_${i}`,
      after: "inject-objects",
      initialize: () => withPluginApi(callback.version, callback.code),
    });
  }
}

function resolveInitializer(moduleName) {
  const module = require(moduleName, null, null, true);

  if (!module) {
    throw new Error(moduleName + " must export an initializer.");
  }

  const initializer = module["default"];

  if (!initializer) {
    throw new Error(moduleName + " must have a default export");
  }

  if (!initializer.name) {
    initializer.name = moduleName.slice(moduleName.lastIndexOf("/") + 1);
  }

  return initializer;
}

function resolveDiscourseInitializer(moduleName, themeId) {
  let initializer;

  try {
    initializer = resolveInitializer(moduleName);
  } catch (error) {
    if (!themeId || isTesting()) {
      throw error;
    } else {
      fireThemeErrorEvent({ themeId, error });
      return;
    }
  }

  const oldInitialize = initializer.initialize;

  initializer.initialize = (app) => {
    try {
      return oldInitialize.call(initializer, app.__container__, app);
    } catch (error) {
      if (!themeId || isTesting()) {
        throw error;
      } else {
        fireThemeErrorEvent({ themeId, error });
      }
    }
  };

  return initializer;
}

let printedDebugInfo = false;
function printDebugInfo() {
  if (printedDebugInfo) {
    return;
  }

  let str = "ℹ️ ";

  const generator = document.querySelector("meta[name=generator]")?.content;
  const parts = generator?.split(" ");
  if (parts) {
    const discourseVersion = parts[1];
    const gitVersion = parts[5]?.substr(0, 10);
    str += `Discourse v${discourseVersion} — https://github.com/discourse/discourse/commits/${gitVersion} — `;
  }

  str += `Ember v${VERSION}`;

  // eslint-disable-next-line no-console
  console.log(str);

  printedDebugInfo = true;
}

export default Discourse;

/**
 * @typedef {import('ember-source/types')} EmberTypes
 */
