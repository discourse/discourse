import "./deprecation-workflow";
import "decorator-transforms/globals";
import "./loader-shims";
import "./discourse-common-loader-shims";
import "./global-compat";
import { registerDiscourseImplicitInjections } from "discourse/lib/implicit-injections";

// Register Discourse's standard implicit injections on common framework classes.
registerDiscourseImplicitInjections();

import Application from "@ember/application";
import { VERSION } from "@ember/version";
import require from "require";
import { normalizeEmberEventHandling } from "discourse/lib/ember-events";
import { withPluginApi } from "discourse/lib/plugin-api";
import { isTesting } from "discourse-common/config/environment";
import { buildResolver } from "discourse-common/resolver";

const _pluginCallbacks = [];
let _unhandledThemeErrors = [];

class Discourse extends Application {
  modulePrefix = "discourse";
  rootElement = "#main";

  customEvents = {
    paste: "paste",
  };

  Resolver = buildResolver("discourse");

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
  const match = moduleName.match(/^discourse\/theme\-(\d+)\//);
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
