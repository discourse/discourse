import { DEBUG } from "@glimmer/env";
import { isTesting } from "discourse-common/config/environment";

const KEY = "discourse__dev_tools";

let defaultEnabled = false;

if (DEBUG && !isTesting()) {
  defaultEnabled = true;
}

function parseStoredValue() {
  const val = window.localStorage.getItem(KEY);
  if (val === "true") {
    return true;
  } else if (val === "false") {
    return false;
  } else {
    return null;
  }
}

function storeValue(value) {
  if (value === defaultEnabled) {
    window.localStorage.removeItem(KEY);
  } else {
    window.localStorage.setItem(KEY, value);
  }
}

export default {
  initialize(app) {
    window.enableDevTools = () => {
      storeValue(true);
      window.location.reload();
    };

    window.disableDevTools = () => {
      storeValue(false);
      window.location.reload();
    };

    if (parseStoredValue() ?? defaultEnabled) {
      // eslint-disable-next-line no-console
      console.log("Loading Discourse dev tools...");

      app.deferReadiness();

      import("discourse/static/dev-tools/entrypoint").then((devTools) => {
        devTools.init();

        // eslint-disable-next-line no-console
        console.log(
          "Loaded Discourse dev tools. Run `disableDevTools()` in console to disable."
        );

        app.advanceReadiness();
      });
    } else if (DEBUG && !isTesting()) {
      // eslint-disable-next-line no-console
      console.log(
        "Discourse dev tools are disabled. Run `enableDevTools()` in console to enable."
      );
    }
  },
};
