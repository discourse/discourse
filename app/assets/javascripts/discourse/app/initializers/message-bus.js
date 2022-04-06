import { isProduction, isTesting } from "discourse-common/config/environment";
// Initialize the message bus to receive messages.
import getURL from "discourse-common/lib/get-url";
import { handleLogoff } from "discourse/lib/ajax";
import userPresent, { onPresenceChange } from "discourse/lib/user-presence";

const LONG_POLL_AFTER_UNSEEN_TIME = 1200000; // 20 minutes
const CONNECTIVITY_ERROR_CLASS = "message-bus-offline";

function updateConnectivityIndicator(stat) {
  if (stat === "error") {
    document.documentElement.classList.add(CONNECTIVITY_ERROR_CLASS);
  } else {
    document.documentElement.classList.remove(CONNECTIVITY_ERROR_CLASS);
  }
}

function ajax(opts) {
  if (opts.complete) {
    const oldComplete = opts.complete;
    opts.complete = function (xhr, stat) {
      handleLogoff(xhr);
      oldComplete(xhr, stat);
      updateConnectivityIndicator(stat);
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
    if (isTesting()) {
      return;
    }

    const messageBus = container.lookup("message-bus:main"),
      user = container.lookup("current-user:main"),
      siteSettings = container.lookup("site-settings:main");

    messageBus.alwaysLongPoll = !isProduction();
    messageBus.shouldLongPollCallback = () =>
      userPresent({ userUnseenTime: LONG_POLL_AFTER_UNSEEN_TIME });

    // we do not want to start anything till document is complete
    messageBus.stop();

    // This will notify MessageBus to force a long poll after user becomes
    // present
    // When 20 minutes pass we stop long polling due to "shouldLongPollCallback".
    onPresenceChange({
      unseenTime: LONG_POLL_AFTER_UNSEEN_TIME,
      callback: (present) => {
        if (present && messageBus.onVisibilityChange) {
          messageBus.onVisibilityChange();
        }
      },
    });

    if (siteSettings.login_required && !user) {
      // Endpoint is not available in this case, so don't try
      return;
    }

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

    messageBus.enableChunkedEncoding =
      isProduction() && siteSettings.enable_chunked_encoding;

    if (messageBus.baseUrl !== "/") {
      messageBus.ajax = function (opts) {
        opts.headers = opts.headers || {};
        opts.headers["X-Shared-Session-Key"] = $(
          "meta[name=shared_session_key]"
        ).attr("content");
        if (userPresent()) {
          opts.headers["Discourse-Present"] = "true";
        }
        return ajax(opts);
      };
    } else {
      messageBus.ajax = function (opts) {
        opts.headers = opts.headers || {};
        if (userPresent()) {
          opts.headers["Discourse-Present"] = "true";
        }
        return ajax(opts);
      };

      messageBus.baseUrl = getURL("/");
    }

    if (user) {
      messageBus.callbackInterval = siteSettings.polling_interval;
    }
  },
};
