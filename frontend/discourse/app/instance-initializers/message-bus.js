import $ from "jquery";
import { handleLogoff } from "discourse/lib/ajax";
import { isProduction, isTesting } from "discourse/lib/environment";
// Initialize the message bus to receive messages.
import getURL from "discourse/lib/get-url";
import userPresent, { onPresenceChange } from "discourse/lib/user-presence";

const LONG_POLL_AFTER_UNSEEN_TIME = 1200000; // 20 minutes

let _sendDeferredPageview = false;
let _deferredViewTopicId = null;
let _deferredViewPath = null;
let _deferredViewQueryString = null;
let _deferredViewReferrer = null;
let _deferredViewRouteName = null;

export function sendDeferredPageview(routeName = null) {
  _sendDeferredPageview = true;
  _deferredViewPath = window.location.pathname.slice(0, 1024);
  _deferredViewRouteName = routeName?.toString().slice(0, 256) || null;

  const search = window.location.search;
  if (search && search.length > 1) {
    _deferredViewQueryString = search.slice(1, 1025).replace(/[\r\n]/g, "");
  } else {
    _deferredViewQueryString = null;
  }

  _deferredViewReferrer = document.referrer
    ? document.referrer.slice(0, 1024).replace(/[\r\n]/g, "")
    : null;
}

function mbAjax(messageBus, opts) {
  opts.headers ||= {};

  if (messageBus.baseUrl !== "/") {
    const key = document.querySelector(
      "meta[name=shared_session_key]"
    )?.content;

    opts.headers["X-Shared-Session-Key"] = key;
  }

  if (userPresent()) {
    opts.headers["Discourse-Present"] = "true";
  }

  if (_sendDeferredPageview) {
    opts.headers["Discourse-Deferred-Track-View"] = "true";

    if (_deferredViewTopicId) {
      opts.headers["Discourse-Deferred-Track-View-Topic-Id"] =
        _deferredViewTopicId;
    }

    if (_deferredViewPath) {
      opts.headers["Discourse-Deferred-Track-View-Path"] = _deferredViewPath;
    }

    if (_deferredViewQueryString) {
      opts.headers["Discourse-Deferred-Track-View-Query-String"] =
        _deferredViewQueryString;
    }

    if (_deferredViewReferrer) {
      opts.headers["Discourse-Deferred-Track-View-Referrer"] =
        _deferredViewReferrer;
    }

    if (_deferredViewRouteName) {
      opts.headers["Discourse-Deferred-Track-View-Route-Name"] =
        _deferredViewRouteName;
    }

    _sendDeferredPageview = false;
    _deferredViewTopicId = null;
    _deferredViewPath = null;
    _deferredViewQueryString = null;
    _deferredViewReferrer = null;
    _deferredViewRouteName = null;
  }

  const oldComplete = opts.complete;
  opts.complete = function (xhr, stat) {
    handleLogoff(xhr);
    oldComplete?.(xhr, stat);
  };

  return $.ajax(opts);
}

export default {
  after: "inject-objects",

  initialize(owner) {
    // We don't use the message bus in testing
    if (isTesting()) {
      return;
    }

    const messageBus = owner.lookup("service:message-bus"),
      user = owner.lookup("service:current-user"),
      siteSettings = owner.lookup("service:site-settings"),
      router = owner.lookup("service:router");

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
        if (
          router.currentRouteName === "topic.fromParams" ||
          router.currentRouteName === "topic.fromParamsNear"
        ) {
          _deferredViewTopicId = router.currentRoute.parent.params.id;
        }

        // Set the route name for deferred page view tracking
        if (router.currentRouteName) {
          _deferredViewRouteName = router.currentRouteName;
        }

        clearInterval(interval);
        messageBus.start();
      }
    }, 500);

    messageBus.callbackInterval = siteSettings.anon_polling_interval;
    messageBus.backgroundCallbackInterval =
      siteSettings.background_polling_interval;

    if (
      siteSettings.long_polling_base_url &&
      siteSettings.long_polling_base_url !== "/"
    ) {
      messageBus.baseUrl =
        siteSettings.long_polling_base_url.replace(/\/$/, "") + "/";
    } else {
      messageBus.baseUrl = getURL("/");
    }

    messageBus.enableChunkedEncoding = siteSettings.enable_chunked_encoding;

    messageBus.ajax = (opts) => mbAjax(messageBus, opts);

    if (user) {
      messageBus.callbackInterval = siteSettings.polling_interval;
    }
  },
};
