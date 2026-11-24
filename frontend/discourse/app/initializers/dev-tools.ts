import { DEBUG } from "@glimmer/env";
import type Application from "@ember/application";
import { isDevelopment } from "discourse/lib/environment";

declare global {
  interface Window {
    enableDevTools(): void;
    disableDevTools(): void;
  }
}

const KEY = "discourse__dev_tools";

function parseStoredValue(val: string | null | undefined) {
  if (val === "true") {
    return true;
  } else if (val === "false") {
    return false;
  } else {
    return null;
  }
}

export default {
  after: ["discourse-bootstrap"],

  initialize(app: Application) {
    let defaultEnabled = false;

    if (DEBUG && isDevelopment()) {
      defaultEnabled = true;
    }

    function storeValue(value: boolean) {
      for (const storage of [window.localStorage, window.sessionStorage]) {
        if (value === defaultEnabled) {
          storage?.removeItem(KEY);
        } else {
          storage?.setItem(KEY, String(value));
        }
      }
    }

    window.enableDevTools = () => {
      storeValue(true);
      window.location.reload();
    };

    window.disableDevTools = () => {
      storeValue(false);
      window.location.reload();
    };

    const persistentPreference = parseStoredValue(
      window.localStorage?.getItem(KEY)
    );
    if (persistentPreference !== null) {
      // Once the preference survives a reload, let persistent storage own it.
      window.sessionStorage?.removeItem(KEY);
    }
    const enabled =
      persistentPreference ??
      parseStoredValue(window.sessionStorage?.getItem(KEY)) ??
      defaultEnabled;

    if (enabled) {
      // eslint-disable-next-line no-console
      console.log("Loading Discourse dev tools...");

      app.deferReadiness();

      import(
        /* dynamicChunkName: "dev-tools" */ "discourse/static/dev-tools/entrypoint"
      ).then((devTools) => {
        devTools.init();

        // eslint-disable-next-line no-console
        console.log(
          "Loaded Discourse dev tools. Run `disableDevTools()` in console to disable."
        );

        app.advanceReadiness();
      });
    } else if (DEBUG && isDevelopment()) {
      // eslint-disable-next-line no-console
      console.log(
        "Discourse dev tools are disabled. Run `enableDevTools()` in console to enable."
      );
    }
  },
};
