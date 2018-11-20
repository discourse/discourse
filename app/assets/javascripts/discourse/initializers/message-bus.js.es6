// Initialize the message bus to receive messages.
import pageVisible from "discourse/lib/page-visible";
import { handleLogoff } from "discourse/lib/ajax";

function ajax(opts) {
  if (opts.complete) {
    let oldComplete = opts.complete;
    opts.complete = function(xhr, stat) {
      handleLogoff(xhr);
      oldComplete(xhr, stat);
    };
  } else {
    opts.complete = handleLogoff;
  }

  return $.ajax(opts);
}

export default {
  name: "message-bus",
  after: "inject-objects",

  initialize(container) {
    // We don't use the message bus in testing
    if (Discourse.testing) {
      return;
    }

    const messageBus = container.lookup("message-bus:main"),
      user = container.lookup("current-user:main"),
      siteSettings = container.lookup("site-settings:main");

    messageBus.alwaysLongPoll = Discourse.Environment === "development";

    // we do not want to start anything till document is complete
    messageBus.stop();
    // jQuery ready is called on "interactive" we want "complete"
    // Possibly change to document.addEventListener('readystatechange',...
    // but would only stop a handful of interval, message bus being delayed by
    // 500ms on load is fine. stuff that needs to catch up correctly should
    // pass in a position
    const interval = setInterval(() => {
      if (document.readyState === "complete") {
        clearInterval(interval);
        messageBus.start();
      }
    }, 500);

    messageBus.callbackInterval = siteSettings.anon_polling_interval;
    messageBus.backgroundCallbackInterval =
      siteSettings.background_polling_interval;
    messageBus.baseUrl =
      siteSettings.long_polling_base_url.replace(/\/$/, "") + "/";

    if (messageBus.baseUrl !== "/") {
      // zepto compatible, 1 param only
      messageBus.ajax = function(opts) {
        opts.headers = opts.headers || {};
        opts.headers["X-Shared-Session-Key"] = $(
          "meta[name=shared_session_key]"
        ).attr("content");
        if (pageVisible()) {
          opts.headers["Discourse-Visible"] = "true";
        }
        return ajax(opts);
      };
    } else {
      messageBus.ajax = function(opts) {
        opts.headers = opts.headers || {};
        if (pageVisible()) {
          opts.headers["Discourse-Visible"] = "true";
        }
        return ajax(opts);
      };

      messageBus.baseUrl = Discourse.getURL("/");
    }

    if (user) {
      messageBus.callbackInterval = siteSettings.polling_interval;
      messageBus.enableLongPolling = true;
    }
  }
};
