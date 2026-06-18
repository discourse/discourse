# frozen_string_literal: true

require "capybara/playwright"

# A build-independent reimplementation of the `window.clientSettled` test
# bridge from `frontend/discourse/app/initializers/rails-testing.js`. That
# initializer is wrapped in `if (DEBUG && isRailsTesting())`, so a
# `production` Ember build dead-code-eliminates it and every `clientSettled`
# settle-wait silently no-ops — leaving system specs racing ajax responses
# and re-renders. Injecting the same tracking logic via a Playwright init
# script restores identical settle semantics for production builds. For
# development builds this is inert: the script runs at document start, and
# the app's own initializer overwrites `window.clientSettled` during boot.
module ClientSettledBridge
  JS = <<~JS
    (() => {
      if (window.__discourseClientSettledBridge) {
        return;
      }
      window.__discourseClientSettledBridge = true;

      const pendingRequests = [];
      const pendingDomEvents = [];
      let pendingBeaconRequests = 0;

      // Parity with `discourse/lib/beacon-pageview`'s own in-flight counter,
      // tracked here by wrapping fetch since the module's counter is
      // unreachable from outside the app bundle.
      const originalFetch = window.fetch;
      window.fetch = function (resource, options) {
        const url =
          typeof resource === "string" ? resource : (resource && resource.url) || "";
        const isBeacon = url.includes("/srv/pv");
        if (isBeacon) {
          pendingBeaconRequests++;
        }
        const promise = originalFetch.apply(this, arguments);
        if (isBeacon) {
          promise.then(
            () => pendingBeaconRequests--,
            () => pendingBeaconRequests--
          );
        }
        return promise;
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

      const incrementAjaxPendingRequests = (_event, xhr, settings) => {
        if (
          settings.url.includes("/message-bus") ||
          settings.url.includes("/presence/")
        ) {
          return;
        }
        pendingRequests.push({ xhr, url: settings.url });
      };

      const decrementAjaxPendingRequests = (_event, xhr) => {
        for (let i = 0; i < pendingRequests.length; i++) {
          if (xhr === pendingRequests[i].xhr) {
            pendingRequests.splice(i, 1);
            break;
          }
        }
      };

      // jQuery is bundled with the app and loads after this init script, so
      // poll until the bundle's instance is reachable, then attach the same
      // global ajax handlers the dev-build initializer attaches.
      const resolveJQuery = () => {
        try {
          if (window.require) {
            const mod = window.require("jquery");
            if (mod && mod.default) {
              return mod.default;
            }
          }
        } catch {}
        return window.jQuery;
      };

      let jqueryPollCount = 0;
      const jqueryPoll = setInterval(() => {
        const $ = resolveJQuery();
        if ($) {
          clearInterval(jqueryPoll);
          $(document)
            .on("ajaxSend", incrementAjaxPendingRequests)
            .on("ajaxComplete ajaxError", decrementAjaxPendingRequests);
        } else if (++jqueryPollCount > 3000) {
          clearInterval(jqueryPoll);
        }
      }, 10);

      [
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
      ].forEach((eventName) => {
        document.addEventListener(
          eventName,
          (event) => {
            pendingDomEvents.push(event);

            deferEventCycles({
              callback: () => {
                const index = pendingDomEvents.indexOf(event);

                if (index !== -1) {
                  pendingDomEvents.splice(index, 1);
                }
              },
              numberOfEventCycles: 2,
            });
          },
          true
        );
      });

      const settled = () => {
        return (
          pendingRequests.length === 0 &&
          pendingDomEvents.length === 0 &&
          pendingBeaconRequests === 0
        );
      };

      const timeoutErrorMessage = (timeoutMs) => {
        let errorMessage = `Timeout waiting for client to settle after ${timeoutMs}ms.`;
        const pendingRequestURLs = pendingRequests.map((req) => req.url);

        if (pendingRequestURLs.length > 0) {
          errorMessage += `\\n  Pending requests: ${pendingRequestURLs.join(", ")}`;
        }

        if (pendingDomEvents.length > 0) {
          const pendingDomEventsText = pendingDomEvents.map(
            (event) => `${event.type} on ${event.target?.tagName?.toLowerCase()}`
          );
          errorMessage += `\\n  Pending DOM events: ${pendingDomEventsText.join(", ")}`;
        }

        if (pendingBeaconRequests > 0) {
          errorMessage += `\\n  Pending beacon pageview requests`;
        }

        return errorMessage;
      };

      window.clientSettled = async (timeoutMs) => {
        const startTime = Date.now();

        while (!settled()) {
          if (Date.now() - startTime > timeoutMs) {
            throw new Error(timeoutErrorMessage(timeoutMs));
          }

          await new Promise((resolve) =>
            deferEventCycles({ callback: resolve, numberOfEventCycles: 1 })
          );
        }

        return true;
      };
    })();
  JS

  # `create_browser_context` adds the init script to a context before any page
  # exists in it. A soft reset keeps the context alive across examples, so the
  # script stays registered without re-running this; a hard reset disposes the
  # context and re-runs `create_browser_context`, which re-registers the script.
  module InjectInitScript
    private

    def create_browser_context
      super.tap { |context| context.add_init_script(script: ClientSettledBridge::JS) }
    end
  end
end

Capybara::Playwright::Browser.prepend(ClientSettledBridge::InjectInitScript)
