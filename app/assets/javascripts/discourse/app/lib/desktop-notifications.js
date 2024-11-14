import { Promise } from "rsvp";
import KeyValueStore from "discourse/lib/key-value-store";
import DiscourseURL from "discourse/lib/url";
import { formatUsername } from "discourse/lib/utilities";
import Site from "discourse/models/site";
import User from "discourse/models/user";
import discourseLater from "discourse-common/lib/later";
import I18n from "discourse-i18n";

let primaryTab = false;
let liveEnabled = false;
let havePermission = null;
let mbClientId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";

const focusTrackerKey = "focus-tracker";
const context = "discourse_desktop_notifications_";
const keyValueStore = new KeyValueStore(context);

let desktopNotificationHandlers = [];
export function registerDesktopNotificationHandler(handler) {
  desktopNotificationHandlers.push(handler);
}
export function clearDesktopNotificationHandlers() {
  desktopNotificationHandlers = [];
}

// Called from an initializer
function init(messageBus) {
  liveEnabled = false;
  mbClientId = messageBus.clientId;

  if (!User.current()) {
    return;
  }

  try {
    keyValueStore.getItem(focusTrackerKey);
  } catch {
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
      "Notification is defined on window but is not responding correctly " + e
    );
  }

  liveEnabled = true;
  try {
    // Preliminary checks passed, continue with setup
    setupNotifications();
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error(e);
  }
}

function confirmNotification(siteSettings) {
  const notification = new Notification(
    I18n.t("notifications.popup.confirm_title", {
      site_title: siteSettings.title,
    }),
    {
      body: I18n.t("notifications.popup.confirm_body"),
      icon: siteSettings.site_logo_small_url || siteSettings.site_logo_url,
      tag: "confirm-subscription",
    }
  );

  const clickEventHandler = () => notification.close();

  notification.addEventListener("click", clickEventHandler);
  discourseLater(() => {
    notification.close();
    notification.removeEventListener("click", clickEventHandler);
  }, 10 * 1000);
}

// This function is only called if permission was granted
function setupNotifications() {
  window.addEventListener("storage", function (e) {
    // note: This event only fires when other tabs setItem()
    const key = e.key;
    if (key !== `${context}${focusTrackerKey}`) {
      return true;
    }
    primaryTab = false;
  });

  window.addEventListener("focus", function () {
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
}

function canUserReceiveNotifications(user) {
  if (!primaryTab) {
    return false;
  }

  if (user.isInDoNotDisturb()) {
    return false;
  }

  if (keyValueStore.getItem("notifications-disabled") === "disabled") {
    return false;
  }

  return true;
}

// Call-in point from message bus
async function onNotification(data, siteSettings, user, appEvents) {
  const showNotifications = canUserReceiveNotifications(user) && liveEnabled;

  if (showNotifications) {
    const notificationTitle =
      data.translated_title ||
      I18n.t(i18nKey(data.notification_type), {
        site_title: siteSettings.title,
        topic: data.topic_title,
        username: formatUsername(data.username),
        group_name: data.group_name,
      });

    const notificationIcon =
      siteSettings.site_logo_small_url || siteSettings.site_logo_url;
    const notificationTag =
      "discourse-notification-" +
      siteSettings.title +
      "-" +
      (data.topic_id || 0);

    await requestPermission();

    const notification = new Notification(notificationTitle, {
      body: data.excerpt,
      icon: notificationIcon,
      tag: notificationTag,
    });

    notification.addEventListener(
      "click",
      () => {
        DiscourseURL.routeTo(data.post_url);
        appEvents.trigger("desktop-notification-opened", {
          url: data.post_url,
        });
        notification.close();
      },
      { once: true }
    );
  }

  desktopNotificationHandlers.forEach((handler) =>
    handler(data, siteSettings, user)
  );
}

// Utility function
// Wraps Notification.requestPermission in a Promise
function requestPermission() {
  if (havePermission === true) {
    return Promise.resolve();
  } else if (havePermission === false) {
    return Promise.reject();
  } else {
    return new Promise(function (resolve, reject) {
      Notification.requestPermission(function (status) {
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
  disable,
  canUserReceiveNotifications,
};
