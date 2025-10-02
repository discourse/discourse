import { DEBUG } from "@glimmer/env";
import { _backburner } from "@ember/runloop";
import { getSettledState, waitUntil } from "@ember/test-helpers";
import $ from "jquery";
import { isDevelopment, isRailsTesting } from "discourse/lib/environment";

const KEY = "discourse__dev_tools";

function parseStoredValue() {
  const val = window.localStorage?.getItem(KEY);
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

  initialize(app) {
    let defaultEnabled = false;

    if (DEBUG && isDevelopment()) {
      defaultEnabled = true;
    }

    function storeValue(value) {
      if (value === defaultEnabled) {
        window.localStorage?.removeItem(KEY);
      } else {
        window.localStorage?.setItem(KEY, value);
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

    if (isRailsTesting()) {
      const setupDataElement = document.getElementById("data-discourse-setup");
      const isSettledDebugEnabled =
        setupDataElement?.dataset.capybaraPlaywrightDebugEmberSettled ===
        "true";

      if (isSettledDebugEnabled) {
        _backburner.DEBUG = true;
      }

      const logSettledDebug = (...args) => {
        if (!isSettledDebugEnabled) {
          return;
        }

        // eslint-disable-next-line no-console
        console.log(`[${Date.now() / 1000}]`, ...args);
      };

      const pendingRequests = [];

      const incrementAjaxPendingRequests = (_event, xhr, settings) => {
        if (
          // Ignore MessageBus and Presence requests as they are long-running and continuous respectively
          settings.url.includes("/message-bus") ||
          settings.url.includes("/presence/")
        ) {
          return;
        }

        logSettledDebug("AJAX request initiated", settings.url);
        pendingRequests.push(xhr);
      };

      const decrementAjaxPendingRequests = (_event, xhr, settings) => {
        for (let i = 0; i < pendingRequests.length; i++) {
          if (xhr === pendingRequests[i]) {
            logSettledDebug("AJAX request completed", settings.url);
            pendingRequests.splice(i, 1);
            break;
          }
        }
      };

      $(document)
        .on("ajaxSend", incrementAjaxPendingRequests)
        .on("ajaxComplete ajaxError", decrementAjaxPendingRequests);

      window.emberSettled = async (timeoutSeconds) => {
        // Wait for two request animation frames to workaround the limitation where we can't exactly determine
        // when Ember's event dispatcher has dispatched an event as a result of a browser interaction.
        await new Promise((r) =>
          requestAnimationFrame(() => requestAnimationFrame(r))
        );

        timeoutSeconds = timeoutSeconds || 10;
        const start = Date.now();

        return waitUntil(
          () => {
            if ((Date.now() - start) / 1000 > timeoutSeconds) {
              // eslint-disable-next-line no-console
              console.error("Timed out waiting for Ember to settle");
              return true;
            }

            const state = getSettledState();

            logSettledDebug({
              hasRunLoop: state.hasRunLoop,
              hasPendingTransitions: state.hasPendingTransitions,
              isRenderPending: state.isRenderPending,
              pendingRequests: pendingRequests.length,
              hasPendingWaiters: state.hasPendingWaiters,
            });

            logSettledDebug(_backburner.getDebugInfo());

            const settled =
              !state.hasRunLoop &&
              !state.hasPendingTransitions &&
              !state.isRenderPending &&
              !state.hasPendingWaiters &&
              pendingRequests.length === 0;

            if (settled) {
              logSettledDebug("SETTLED!");
            }

            return settled;
          },
          { timeout: Infinity }
        ).then(() => {});
      };
    }

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
    } else if (DEBUG && isDevelopment()) {
      // eslint-disable-next-line no-console
      console.log(
        "Discourse dev tools are disabled. Run `enableDevTools()` in console to enable."
      );
    }
  },
};
