import Application from "@ember/application";
import { buildResolver } from "discourse-common/resolver";
import { isTesting } from "discourse-common/config/environment";

const _pluginCallbacks = [];
let _themeErrors = [];

const Discourse = Application.extend({
  rootElement: "#main",

  customEvents: {
    paste: "paste",
  },

  Resolver: buildResolver("discourse"),

  _prepareInitializer(moduleName) {
    const themeId = moduleThemeId(moduleName);
    let module = null;

    try {
      module = requirejs(moduleName, null, null, true);

      if (!module) {
        throw new Error(moduleName + " must export an initializer.");
      }
    } catch (err) {
      if (!themeId || isTesting()) {
        throw err;
      }
      _themeErrors.push([themeId, err]);
      fireThemeErrorEvent();
      return;
    }

    const init = module.default;
    const oldInitialize = init.initialize;
    init.initialize = (app) => {
      try {
        return oldInitialize.call(init, app.__container__, app);
      } catch (err) {
        if (!themeId || isTesting()) {
          throw err;
        }
        _themeErrors.push([themeId, err]);
        fireThemeErrorEvent();
      }
    };

    return init;
  },

  // Start up the Discourse application by running all the initializers we've defined.
  start() {
    document.querySelector("noscript")?.remove();

    Object.keys(requirejs._eak_seen).forEach((key) => {
      if (/\/pre\-initializers\//.test(key)) {
        const initializer = this._prepareInitializer(key);
        if (initializer) {
          this.initializer(initializer);
        }
      } else if (/\/(api\-)?initializers\//.test(key)) {
        const initializer = this._prepareInitializer(key);
        if (initializer) {
          this.instanceInitializer(initializer);
        }
      }
    });

    // Plugins that are registered via `<script>` tags.
    const withPluginApi = requirejs("discourse/lib/plugin-api").withPluginApi;
    let initCount = 0;
    _pluginCallbacks.forEach((cb) => {
      this.instanceInitializer({
        name: `_discourse_plugin_${++initCount}`,
        after: "inject-objects",
        initialize: () => withPluginApi(cb.version, cb.code),
      });
    });
  },

  _registerPluginCode(version, code) {
    _pluginCallbacks.push({ version, code });
  },
});

function moduleThemeId(moduleName) {
  const match = moduleName.match(/^discourse\/theme\-(\d+)\//);
  if (match) {
    return parseInt(match[1], 10);
  }
}

function fireThemeErrorEvent() {
  const event = new CustomEvent("discourse-theme-error");
  document.dispatchEvent(event);
}

export function getAndClearThemeErrors() {
  const copy = _themeErrors;
  _themeErrors = [];
  return copy;
}

export default Discourse;
