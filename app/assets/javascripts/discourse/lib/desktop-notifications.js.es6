import DiscourseURL from 'discourse/lib/url';
import PageTracker from 'discourse/lib/page-tracker';

let primaryTab = false;
let liveEnabled = false;
let havePermission = null;
let mbClientId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
let lastAction = -1;

const focusTrackerKey = "focus-tracker";
const idleThresholdTime = 1000 * 10; // 10 seconds

// Called from an initializer
function init(messageBus) {
  liveEnabled = false;
  mbClientId = messageBus.clientId;

  if (!Discourse.User.current()) {
    return;
  }

  try {
    localStorage.getItem(focusTrackerKey);
  } catch (e) {
    Em.Logger.info('Discourse desktop notifications are disabled - localStorage denied.');
    return;
  }

  if (!("Notification" in window)) {
    Em.Logger.info('Discourse desktop notifications are disabled - not supported by browser');
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
    Em.Logger.warn('Unexpected error, Notification is defined on window but not a responding correctly ' + e);
  }

  liveEnabled = true;
  try {
    // Preliminary checks passed, continue with setup
    setupNotifications();
  } catch (e) {
    Em.Logger.error(e);
  }
}

// This function is only called if permission was granted
function setupNotifications() {

  window.addEventListener("storage", function(e) {
    // note: This event only fires when other tabs setItem()
    const key = e.key;
    if (key !== focusTrackerKey) {
      return true;
    }
    primaryTab = false;
  });

  window.addEventListener("focus", function() {
    if (!primaryTab) {
      primaryTab = true;
      localStorage.setItem(focusTrackerKey, mbClientId);
    }
  });

  if (document && (typeof document.hidden !== "undefined") && document["hidden"]) {
    primaryTab = false;
  } else {
    primaryTab = true;
    localStorage.setItem(focusTrackerKey, mbClientId);
  }

  if (document) {
    document.addEventListener("scroll", resetIdle);
  }
  PageTracker.on("change", resetIdle);
}

function resetIdle() {
  lastAction = Date.now();
}
function isIdle() {
  return lastAction + idleThresholdTime < Date.now();
}

// Call-in point from message bus
function onNotification(data) {
  if (!liveEnabled) { return; }
  if (!primaryTab) { return; }
  if (!isIdle()) { return; }
  if (localStorage.getItem('notifications-disabled')) { return; }

  const notificationTitle = I18n.t(i18nKey(data.notification_type), {
     site_title: Discourse.SiteSettings.title,
     topic: data.topic_title,
     username: data.username
  });

  const notificationBody = data.excerpt;
  const notificationIcon = Discourse.SiteSettings.logo_small_url || Discourse.SiteSettings.logo_url;
  const notificationTag = "discourse-notification-" + Discourse.SiteSettings.title + "-" + data.topic_id;

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

    notification.addEventListener('click', clickEventHandler);
    setTimeout(function() {
      notification.close();
      notification.removeEventListener('click', clickEventHandler);
    }, 10 * 1000);
  });
}

// Utility function
// Wraps Notification.requestPermission in a Promise
function requestPermission() {
  if (havePermission === true) {
    return Ember.RSVP.resolve();
  } else if (havePermission === false) {
    return Ember.RSVP.reject();
  } else {
    return new Ember.RSVP.Promise(function(resolve, reject) {
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
  return "notifications.popup." + Discourse.Site.current().get("notificationLookup")[notification_type];
}

// Exported for controllers/notification.js.es6

export { init, onNotification };
