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
      _backburner.DEBUG = true;

      window.emberGetSettledState = getSettledState;

      const pendingRequests = [];

      const incrementAjaxPendingRequests = (_event, xhr, settings) => {
        if (
          settings.url.includes("/message-bus") ||
          settings.url.includes("/presence/")
        ) {
          return;
        }

        // console.log(`[${Date.now() / 1000}] added`, settings.url);

        pendingRequests.push(xhr);
      };

      const decrementAjaxPendingRequests = (_event, xhr) => {
        for (let i = 0; i < pendingRequests.length; i++) {
          if (xhr === pendingRequests[i]) {
            // console.log(`[${Date.now() / 1000}] removed`, settings.url);
            pendingRequests.splice(i, 1);
            break;
          }
        }
      };

      $(document)
        .on("ajaxSend", incrementAjaxPendingRequests)
        .on("ajaxComplete ajaxError", decrementAjaxPendingRequests);

      let backburnerBeginCount = 0;

      _backburner.on("begin", () => {
        backburnerBeginCount++;
      });

      window.emberGetBackburnerBeginCount = () => backburnerBeginCount;

      window.emberBackburnerBegan = (previousCount) => {
        return waitUntil(() => backburnerBeginCount > previousCount, {
          timeout: Infinity,
        });
      };

      window.emberSettled = () => {
        return waitUntil(
          () => {
            const state = getSettledState();

            // console.log(`[${Date.now() / 1000}]`, {
            //   hasRunLoop: state.hasRunLoop,
            //   hasPendingTransitions: state.hasPendingTransitions,
            //   isRenderPending: state.isRenderPending,
            //   pendingRequests: pendingRequests.length,
            // });

            const settled =
              !state.hasRunLoop &&
              !state.hasPendingTransitions &&
              !state.isRenderPending &&
              !state.hasPendingWaiters &&
              pendingRequests.length === 0;

            // if (settled) {
            //   console.log(`[${Date.now() / 1000}] SETTLED!`);
            // }

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
