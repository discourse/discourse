import "./setup-deprecation-workflow";
import "./array-shim";
import "decorator-transforms/globals";
import "./loader-shims";
import "./discourse-common-loader-shims";
import "./global-compat";
import dialogHolderCompatModules from "discourse/dialog-holder/dialog-holder-compat-modules";
import floatKitCompatModules from "discourse/float-kit/float-kit-compat-modules";
import selectKitCompatModules from "discourse/select-kit/select-kit-compat-modules";
import truthHelperCompatModules from "discourse/truth-helpers/truth-helpers-compat-modules";
defineModules("select-kit", selectKitCompatModules);
defineModules("float-kit", floatKitCompatModules);
defineModules("truth-helpers", truthHelperCompatModules);
defineModules("dialog-holder", dialogHolderCompatModules);

import { registerDiscourseImplicitInjections } from "discourse/lib/implicit-injections";

// Register Discourse's standard implicit injections on common framework classes.
registerDiscourseImplicitInjections();

import { DEBUG } from "@glimmer/env";
import Application from "@ember/application";
import { VERSION } from "@ember/version";
import require from "require";
import { normalizeEmberEventHandling } from "discourse/lib/ember-events";
import { isTesting } from "discourse/lib/environment";
import { withPluginApi } from "discourse/lib/plugin-api";
import { buildResolver } from "discourse/resolver";

const _pluginCallbacks = [];
let _unhandledThemeErrors = [];

window.moduleBroker = {
  async lookup(moduleName) {
    return require(moduleName);
  },
};

async function loadThemeFromModulePreload(link) {
  const themeId = link.dataset.themeId;
  try {
    const compatModules = (await import(/* webpackIgnore: true */ link.href))
      .default;
    for (const [key, mod] of Object.entries(compatModules)) {
      define(`discourse/theme-${themeId}/${key}`, () => mod);
    }
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error(
      `Failed to load theme ${link.dataset.themeId} from ${link.href}`,
      String(error)
    );
    fireThemeErrorEvent({ themeId: link.dataset.themeId, error });
  }
}

let dialogContent;

async function loadPluginFromModulePreload(link) {
  const pluginName = link.dataset.pluginName;
  try {
    const compatModules = (await import(/* webpackIgnore: true */ link.href))
      .default;
    for (const [key, mod] of Object.entries(compatModules)) {
      define(`discourse/plugins/${pluginName}/${key}`, () => mod);
    }
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error(
      `Failed to load plugin ${link.dataset.pluginName} from ${link.href}`,
      error
    );

    if (DEBUG) {
      if (!dialogContent) {
        const style = document.createElement("style");
        style.innerText = `
          #discourse-error-dialog {
            --color: #e04e39;

            background: light-dark(var(--color), #141414);
            border-radius: 16px;
            border: 1px solid light-dark(var(--color), #242424);
            box-shadow: 0 8px 16px 8px light-dark(#aaa, #111);
            color: light-dark(#fff, var(--color));
            font-family: monospace;
            font-size: 13px;
            padding: 0;

            &::before {
              background: #111 linear-gradient(-45deg, transparent 6px, var(--color) 6px, var(--color) 12px, transparent 12px);
              background-position: 6px;
              background-repeat: repeat-x;
              background-size: 18px 8px;
              content: "";
              display: block;
              height: 8px;
              width: 100%;
            }

            model-viewer {
              display: inline-block;
              height: 128px;
              margin-left: auto;
              vertical-align: middle;
              width: 96px;
            }

            h1 {
              display: inline-block;
              font-family: system-ui, sans-serif;
              font-size: 28px;
              margin: 0 0 0 16px;
              vertical-align: middle;
              width: calc(100% - 96px - 16px * 2);
            }

            ul {
              margin: 0;
            }

            li {
              background: #0003;
              border-radius: 8px;
              list-style: none;
              margin: 0 16px 16px;
              padding: 16px 16px 32px;
            }
          }
        `;
        document.body.append(style);

        const script = document.createElement("script");
        script.type = "module";
        script.src =
          "https://ajax.googleapis.com/ajax/libs/model-viewer/4.1.0/model-viewer.min.js";
        document.body.append(script);

        const dialog = document.createElement("dialog");
        dialog.id = "discourse-error-dialog";

        const heading = document.createElement("h1");
        heading.innerText = "Plugin Error";
        dialog.append(heading);

        const tomster = document.createElement("model-viewer");
        tomster.src = "tomster-compressed.glb";
        tomster.setAttribute("camera-controls", true);
        tomster.setAttribute("touch-action", "pan-y");
        tomster.setAttribute("interaction-prompt", "none");
        tomster.setAttribute("auto-rotate", "true");
        tomster.setAttribute("auto-rotate-delay", 1500);
        tomster.setAttribute("rotation-per-second", "400%");
        tomster.setAttribute("camera-orbit", "60deg 75deg 105%");
        dialog.append(tomster);

        dialogContent = document.createElement("ul");
        dialog.append(dialogContent);

        document.body.append(dialog);
        dialog.showModal();
      }

      const errorElement = document.createElement("li");
      errorElement.innerText += `❌ Failed to load plugin ${link.dataset.pluginName} from ${link.href}\n${error.message}`;
      dialogContent.append(errorElement);
    }
  }
}

export async function loadThemesAndPlugins() {
  const promises = [
    ...[
      ...document.querySelectorAll("link[rel=modulepreload][data-theme-id]"),
    ].map(loadThemeFromModulePreload),
    ...[
      ...document.querySelectorAll("link[rel=modulepreload][data-plugin-name]"),
    ].map(loadPluginFromModulePreload),
  ];

  await Promise.all(promises);
}

function defineModules(name, compatModules) {
  for (const [key, mod] of Object.entries(compatModules)) {
    define(`discourse/${name}/${key.slice(2)}`, () => mod);
  }
}

export async function loadAdmin() {
  defineModules(
    "admin",
    (
      await import(
        /* webpackChunkName: "admin" */ "discourse/admin/admin-compat-modules"
      )
    ).default
  );
}

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
  if (printedDebugInfo || isTesting()) {
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
