import { _backburner } from "@ember/runloop";
import { getSettledState, waitUntil } from "@ember/test-helpers";
import { getPendingWaiterState } from "@ember/test-waiters";
import $ from "jquery";
import { isRailsTesting } from "discourse/lib/environment";

export default {
  after: ["discourse-bootstrap"],

  initialize() {
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
              pendingWaiters: getPendingWaiterState().waiters,
              backBurnerDebugInfo: _backburner.getDebugInfo(),
            });

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
  },
};
