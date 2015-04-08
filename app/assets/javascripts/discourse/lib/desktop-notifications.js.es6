
let primaryTab;
let liveEnabled;
let notificationTagName;
let mbClientId;
let lastAction;

const focusTrackerKey = "focus-tracker";
const seenDataKey = "seen-notifications";
const recentUpdateThreshold = 1000 * 60 * 2; // 2 minutes
const idleThresholdTime = 1000 * 10; // 10 seconds

function init(container) {
  liveEnabled = false;
  requestPermission().then(function() {
    try {
      localStorage.getItem(focusTrackerKey);
    } catch (e) {
      Em.Logger.info('Discourse desktop notifications are disabled - localStorage denied.');
      return false;
    }
    liveEnabled = true;
    Em.Logger.info('Discourse desktop notifications are enabled.');
    return true;
  }).then(function(c) {
    if (c) {
      try {
        init2(container);
      } catch (e) {
        console.error(e);
      }
    }
  }).catch(function(e) {
    liveEnabled = false;
    Em.Logger.info('Discourse desktop notifications are disabled - permission denied.');
  });
}

function init2(container) {
  // Load up the current state of the notifications
  const seenData = JSON.parse(localStorage.getItem(seenDataKey));
  let markAllSeen = true;
  if (seenData) {
    const lastUpdatedAt = new Date(seenData.updated_at);
    if (lastUpdatedAt.getTime() + recentUpdateThreshold > new Date().getTime()) {
      // The following conditions are met:
      //  - This is a new Discourse tab
      //  - The seen notification data was updated in the last 2 minutes
      // Therefore, there is no need to reset the data.
      markAllSeen = false;
    }
  }
  if (markAllSeen) {
    Discourse.ajax("/notifications.json?silent=true").then(function(result) {
      updateSeenNotificationDatesFrom(result);
    });
  }

  notificationTagName = "discourse-notification-popup-" + Discourse.SiteSettings.title;

  const messageBus = container.lookup('message-bus:main');
  mbClientId = messageBus.clientId;

  window.addEventListener("storage", function(e) {
    // note: This event only fires when other tabs setItem()
    const key = e.key;
    if (key !== focusTrackerKey) {
      return true;
    }
    if (primaryTab) {
      primaryTab = false;
    }
  });
  window.addEventListener("focus", function() {
    if (!primaryTab) {
      primaryTab = true;
      localStorage.setItem(focusTrackerKey, mbClientId);
    }
  });

  if (document.hidden) {
    primaryTab = false;
  } else {
    primaryTab = true;
    localStorage.setItem(focusTrackerKey, mbClientId);
  }

  document.addEventListener("scroll", resetIdle);
  window.addEventListener("mouseover", resetIdle);
  Discourse.PageTracker.on("change", resetIdle);
}

function resetIdle() {
  lastAction = Date.now();
}
function isIdle() {
  return lastAction + idleThresholdTime < Date.now();
}

// Call-in point from message bus
function onNotification(currentUser) {
  if (!liveEnabled) { return; }
  if (!primaryTab) { return; }

  const blueNotifications = currentUser.get('unread_notifications');
  const greenNotifications = currentUser.get('unread_private_messages');

  if (blueNotifications > 0 || greenNotifications > 0) {
    Discourse.ajax("/notifications.json?silent=true").then(function(result) {

      const unread = result.filter(n => !n.read);
      const unseen = updateSeenNotificationDatesFrom(result);
      const unreadCount = unread.length;
      const unseenCount = unseen.length;


      // If all notifications are seen, don't display
      if (unreadCount === 0 || unseenCount === 0) {
        return;
      }
      // If active in last 10 seconds, don't display
      if (!isIdle()) {
        return;
      }

      let bodyParts = [];

      unread.forEach(function(n) {
        const i18nOpts = {
          username: n.data['display_username'],
          topic: n.data['topic_title'],
          badge: n.data['badge_name']
        };

        bodyParts.push(I18n.t(i18nKey(n), i18nOpts));
      });

      const notificationTitle = I18n.t('notifications.popup_title', { count: unreadCount, site_title: Discourse.SiteSettings.title });
      const notificationBody = bodyParts.join("\n");
      const notificationIcon = Discourse.SiteSettings.logo_small_url || Discourse.SiteSettings.logo_url;

      // This shows the notification!
      const notification = new Notification(notificationTitle, {
        body: notificationBody,
        icon: notificationIcon,
        tag: notificationTagName
      });

      // if (enableSound) {
      //   soundElement.play();
      // }

      const firstUnseen = unseen[0];

      function clickEventHandler() {
        Discourse.URL.routeTo(_notificationUrl(firstUnseen));
        // Cannot delay this until the page renders :(
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
}

const DATA_VERSION = 2;
function updateSeenNotificationDatesFrom(notifications) {
  const oldSeenData = JSON.parse(localStorage.getItem(seenDataKey));
  const oldSeenNotificationDates = (oldSeenData && oldSeenData.v === DATA_VERSION) ? oldSeenData.data : [];
  let newSeenNotificationDates = [];
  let previouslyUnseenNotifications = [];

  notifications.forEach(function(notification) {
    const dateString = new Date(notification.created_at).toUTCString();

    if (oldSeenNotificationDates.indexOf(dateString) === -1) {
      previouslyUnseenNotifications.push(notification);
    }
    newSeenNotificationDates.push(dateString);
  });

  localStorage.setItem(seenDataKey, JSON.stringify({
    data: newSeenNotificationDates,
    updated_at: new Date(),
    v: DATA_VERSION
  }));
  return previouslyUnseenNotifications;
}

// Utility function
// Wraps Notification.requestPermission in a Promise
function requestPermission() {
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

function i18nKey(notification) {
  let key = "notifications.popup." + Discourse.Site.current().get("notificationLookup")[notification.notification_type];
  if (notification.data.display_username && notification.data.original_username &&
    notification.data.display_username !== notification.data.original_username) {
    key += "_mul";
  }
  return key;
}

// Exported for controllers/notification.js.es6
function notificationUrl(it) {
  var badgeId = it.get("data.badge_id");
  if (badgeId) {
    var badgeName = it.get("data.badge_name");
    return Discourse.getURL('/badges/' + badgeId + '/' + badgeName.replace(/[^A-Za-z0-9_]+/g, '-').toLowerCase());
  }

  var topicId = it.get('topic_id');
  if (topicId) {
    return Discourse.Utilities.postUrl(it.get("slug"), topicId, it.get("post_number"));
  }

  if (it.get('notification_type') === INVITED_TYPE) {
    return Discourse.getURL('/my/invited');
  }
}

function _notificationUrl(notificationJson) {
  const it = Em.Object.create(notificationJson);
  return notificationUrl(it);
}

export { init, notificationUrl, onNotification };
