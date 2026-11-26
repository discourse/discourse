/* eslint-disable ember/no-jquery */
import { DEBUG } from "@glimmer/env";
import $ from "jquery";
import { hasPendingBeaconRequests } from "discourse/lib/beacon-pageview";
import { isRailsTesting } from "discourse/lib/environment";

export function createClientSettled(doc, logSettledDebug = () => {}) {
  const pendingRequests = [];
  const pendingDomEvents = [];
  const waiters = new Set();
  let checkTimer;

  const hasPendingTrackedWork = () =>
    pendingRequests.length > 0 || pendingDomEvents.length > 0;

  const settled = () => !hasPendingTrackedWork() && !hasPendingBeaconRequests();

  const scheduleCheck = () => {
    if (!waiters.size || hasPendingTrackedWork() || checkTimer !== undefined) {
      return;
    }

    // Let completion handlers and their promise continuations enqueue more work.
    checkTimer = setTimeout(() => {
      checkTimer = undefined;
      if (settled()) {
        for (const finish of waiters) {
          finish();
        }
      } else {
        // Beacon pageviews only expose pending state, not a completion event.
        scheduleCheck();
      }
    }, 0);
  };

  const incrementAjaxPendingRequests = (_event, xhr, settings) => {
    if (
      // Ignore MessageBus and Presence requests as they are long-running and continuous respectively
      settings.url.includes("/message-bus") ||
      settings.url.includes("/presence/")
    ) {
      return;
    }

    logSettledDebug("AJAX request initiated", settings.url);
    pendingRequests.push({ xhr, url: settings.url });
  };

  const decrementAjaxPendingRequests = (_event, xhr, settings) => {
    for (let i = 0; i < pendingRequests.length; i++) {
      if (xhr === pendingRequests[i].xhr) {
        logSettledDebug("AJAX request completed", settings.url);
        pendingRequests.splice(i, 1);
        scheduleCheck();
        break;
      }
    }
  };

  $(doc)
    .on("ajaxSend", incrementAjaxPendingRequests)
    .on("ajaxComplete ajaxError", decrementAjaxPendingRequests);

  for (const eventName of [
    "click",
    "input",
    "mousedown",
    "keydown",
    "focusin",
    "focusout",
    "touchstart",
    "change",
    "resize",
    "scroll",
  ]) {
    doc.addEventListener(
      eventName,
      (event) => {
        logSettledDebug(`${eventName} event detected`, event);
        pendingDomEvents.push(event);

        // Keep both timer turns so work deferred by the event handler is observed.
        setTimeout(() => {
          setTimeout(() => {
            const index = pendingDomEvents.indexOf(event);
            pendingDomEvents.splice(index, 1);
            logSettledDebug(`${eventName} event settled`, event);
            scheduleCheck();
          }, 0);
        }, 0);
      },
      true
    );
  }

  const timeoutErrorMessage = (timeoutMs) => {
    let errorMessage = `Timeout waiting for client to settle after ${timeoutMs}ms.`;
    const pendingRequestURLs = pendingRequests.map((req) => req.url);

    if (pendingRequestURLs.length > 0) {
      errorMessage += `\n  Pending requests: ${pendingRequestURLs.join(", ")}`;
    }

    const pendingDOMEventsText = pendingDomEvents.map((event) => {
      let message = event.type;
      const element = event.target;
      const tagName = element?.tagName?.toLowerCase();

      if (tagName) {
        message += ` on ${tagName}`;
        const classes = Array.from(element.classList).join(".");

        if (classes.length > 0) {
          message += `.${classes}`;
        }
      }

      return message;
    });

    if (pendingDOMEventsText.length > 0) {
      errorMessage += `\n  Pending DOM events: ${pendingDOMEventsText.join(", ")}`;
    }

    if (hasPendingBeaconRequests()) {
      errorMessage += `\n  Pending beacon pageview requests`;
    }

    return errorMessage;
  };

  return async (timeoutMs) => {
    if (!settled()) {
      logSettledDebug("Waiting for client to settle...", {
        pendingRequests,
        pendingDomEvents,
      });

      await new Promise((resolve, reject) => {
        const finish = (error) => {
          clearTimeout(deadline);
          waiters.delete(finish);
          if (!waiters.size && checkTimer !== undefined) {
            clearTimeout(checkTimer);
            checkTimer = undefined;
          }
          if (error) {
            reject(error);
          } else {
            resolve();
          }
        };
        const deadline = setTimeout(() => {
          finish(
            settled() ? undefined : new Error(timeoutErrorMessage(timeoutMs))
          );
        }, timeoutMs);
        waiters.add(finish);
        scheduleCheck();
      });
    }

    logSettledDebug("Client Settled!");
    return true;
  };
}

export default {
  after: ["discourse-bootstrap"],

  initialize() {
    if (DEBUG && isRailsTesting()) {
      const setupDataElement = document.getElementById("data-discourse-setup");
      const isSettledDebugEnabled =
        setupDataElement?.dataset.systemTestDebugClientSettled === "true";

      const logSettledDebug = (...args) => {
        if (isSettledDebugEnabled) {
          // eslint-disable-next-line no-console
          console.log(`[${Date.now() / 1000}]`, ...args);
        }
      };

      window.clientSettled = createClientSettled(document, logSettledDebug);
    }
  },
};
