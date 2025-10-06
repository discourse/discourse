import $ from "jquery";
import { isRailsTesting } from "discourse/lib/environment";

export default {
  after: ["discourse-bootstrap"],

  initialize() {
    if (isRailsTesting()) {
      const setupDataElement = document.getElementById("data-discourse-setup");
      const isSettledDebugEnabled =
        setupDataElement?.dataset.capybaraPlaywrightDebugClientSettled ===
        "true";

      const logSettledDebug = (...args) => {
        if (!isSettledDebugEnabled) {
          return;
        }

        // eslint-disable-next-line no-console
        console.log(`[${Date.now() / 1000}]`, ...args);
      };

      const deferEventCycles = ({ callback, numberOfEventCycles = 1 }) => {
        if (numberOfEventCycles > 0) {
          return setTimeout(() => {
            deferEventCycles({
              callback,
              numberOfEventCycles: numberOfEventCycles - 1,
            });
          }, 0);
        } else {
          return callback();
        }
      };

      const pendingRequests = [];
      const pendingDomEvents = [];

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
            break;
          }
        }
      };

      const trackJQueryAjax = () => {
        $(document)
          .on("ajaxSend", incrementAjaxPendingRequests)
          .on("ajaxComplete ajaxError", decrementAjaxPendingRequests);
      };

      const trackDomEvents = ({ eventNames, numberOfEventCyclesToDefer }) => {
        eventNames.forEach((eventName) => {
          document.addEventListener(
            eventName,
            (event) => {
              logSettledDebug(`${eventName} event detected`, event);
              pendingDomEvents.push(event);

              deferEventCycles({
                callback: () => {
                  const index = pendingDomEvents.indexOf(event);

                  if (index !== -1) {
                    pendingDomEvents.splice(index, 1);
                  }

                  logSettledDebug(`${eventName} event settled`, event);
                },
                numberOfEventCycles: numberOfEventCyclesToDefer,
              });
            },
            true
          );
        });
      };

      // Tracking jQuery AJAX requests and DOM events for now. Can be expanded in the future if needed.
      const track = () => {
        trackJQueryAjax();

        trackDomEvents({
          eventNames: [
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
          ],
          numberOfEventCyclesToDefer: 2,
        });
      };

      track();

      const settled = () => {
        return pendingRequests.length === 0 && pendingDomEvents.length === 0;
      };

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

            // can't I print something like `div.some-class.other-class`?
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

        return errorMessage;
      };

      window.clientSettled = async (timeoutMs) => {
        const startTime = Date.now();

        while (!settled()) {
          if (Date.now() - startTime > timeoutMs) {
            throw new Error(timeoutErrorMessage(timeoutMs));
          }

          logSettledDebug("Waiting for client to settle...", {
            pendingRequests,
            pendingDomEvents,
          });

          await new Promise((resolve) =>
            deferEventCycles({ callback: resolve, numberOfEventCycles: 1 })
          );
        }

        logSettledDebug("Client Settled!");

        return true;
      };
    }
  },
};
