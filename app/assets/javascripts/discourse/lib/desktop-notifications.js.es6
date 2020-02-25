import { later } from "@ember/runloop";
import DiscourseURL from "discourse/lib/url";
import KeyValueStore from "discourse/lib/key-value-store";
import { formatUsername } from "discourse/lib/utilities";
import { Promise } from "rsvp";
import Site from "discourse/models/site";
import User from "discourse/models/user";

let primaryTab = false;
let liveEnabled = false;
let havePermission = null;
let mbClientId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
let lastAction = -1;

const focusTrackerKey = "focus-tracker";
const idleThresholdTime = 1000 * 10; // 10 seconds

const context = "discourse_desktop_notifications_";
const keyValueStore = new KeyValueStore(context);

// Called from an initializer
function init(messageBus, appEvents) {
  liveEnabled = false;
  mbClientId = messageBus.clientId;

  if (!User.current()) {
    return;
  }

  try {
    keyValueStore.getItem(focusTrackerKey);
  } catch (e) {
    // eslint-disable-next-line no-console
    console.info(
      "Discourse desktop notifications are disabled - localStorage denied."
    );
    return;
  }

  if (!("Notification" in window)) {
    // eslint-disable-next-line no-console
    console.info(
      "Discourse desktop notifications are disabled - not supported by browser"
    );
    return;
  }

  try {
    if (Notification.permission === "granted") {
      havePermission = true;
    } else if (Notification.permission === "denied") {
      havePermission = false;
      return;
    }
  } catch (e) {
    // eslint-disable-next-line no-console
    console.warn(
      "Unexpected error, Notification is defined on window but not a responding correctly " +
        e
    );
  }

  liveEnabled = true;
  try {
    // Preliminary checks passed, continue with setup
    setupNotifications(appEvents);
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
  }
}

function confirmNotification() {
  const notification = new Notification(
    I18n.t("notifications.popup.confirm_title", {
      site_title: Discourse.SiteSettings.title
    }),
    {
      body: I18n.t("notifications.popup.confirm_body"),
      icon:
        Discourse.SiteSettings.site_logo_small_url ||
        Discourse.SiteSettings.site_logo_url,
      tag: "confirm-subscription"
    }
  );

  const clickEventHandler = () => notification.close();

  notification.addEventListener("click", clickEventHandler);
  later(() => {
    notification.close();
    notification.removeEventListener("click", clickEventHandler);
  }, 10 * 1000);
}

// This function is only called if permission was granted
function setupNotifications(appEvents) {
  window.addEventListener("storage", function(e) {
    // note: This event only fires when other tabs setItem()
    const key = e.key;
    if (key !== `${context}${focusTrackerKey}`) {
      return true;
    }
    primaryTab = false;
  });

  window.addEventListener("focus", function() {
    if (!primaryTab) {
      primaryTab = true;
      keyValueStore.setItem(focusTrackerKey, mbClientId);
    }
  });

  if (
    document &&
    typeof document.hidden !== "undefined" &&
    document["hidden"]
  ) {
    primaryTab = false;
  } else {
    primaryTab = true;
    keyValueStore.setItem(focusTrackerKey, mbClientId);
  }

  if (document) {
    document.addEventListener("scroll", resetIdle);
  }

  appEvents.on("page:changed", resetIdle);
}

function resetIdle() {
  lastAction = Date.now();
}
function isIdle() {
  return lastAction + idleThresholdTime < Date.now();
}

// Call-in point from message bus
function onNotification(data) {
  if (!liveEnabled) {
    return;
  }
  if (!primaryTab) {
    return;
  }
  if (!isIdle()) {
    return;
  }
  if (keyValueStore.getItem("notifications-disabled")) {
    return;
  }

  const notificationTitle = I18n.t(i18nKey(data.notification_type), {
    site_title: Discourse.SiteSettings.title,
    topic: data.topic_title,
    username: formatUsername(data.username)
  });

  const notificationBody = data.excerpt;

  const notificationIcon =
    Discourse.SiteSettings.site_logo_small_url ||
    Discourse.SiteSettings.site_logo_url;

  const notificationTag =
    "discourse-notification-" +
    Discourse.SiteSettings.title +
    "-" +
    data.topic_id;

  requestPermission().then(function() {
    // This shows the notification!
    const notification = new Notification(notificationTitle, {
      body: notificationBody,
      icon: notificationIcon,
      tag: notificationTag
    });

    function clickEventHandler() {
      DiscourseURL.routeTo(data.post_url);
      // Cannot delay this until the page renders
      // due to trigger-based permissions
      window.focus();
    }

    notification.addEventListener("click", clickEventHandler);
    later(() => {
      notification.close();
      notification.removeEventListener("click", clickEventHandler);
    }, 10 * 1000);
  });
}

// Utility function
// Wraps Notification.requestPermission in a Promise
function requestPermission() {
  if (havePermission === true) {
    return Promise.resolve();
  } else if (havePermission === false) {
    return Promise.reject();
  } else {
    return new Promise(function(resolve, reject) {
      Notification.requestPermission(function(status) {
        if (status === "granted") {
          resolve();
        } else {
          reject();
        }
      });
    });
  }
}

function i18nKey(notification_type) {
  return (
    "notifications.popup." +
    Site.current().get("notificationLookup")[notification_type]
  );
}

function alertChannel(user) {
  return `/notification-alert/${user.get("id")}`;
}

function unsubscribe(bus, user) {
  bus.unsubscribe(alertChannel(user));
}

function disable() {
  keyValueStore.setItem("notifications-disabled", "disabled");
}

export {
  context,
  init,
  onNotification,
  unsubscribe,
  alertChannel,
  confirmNotification,
  disable
};
