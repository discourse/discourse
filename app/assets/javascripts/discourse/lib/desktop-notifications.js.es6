
let primaryTab;
let liveEnabled;
let seenNotificationDates = {};
let notificationTagName;
let mbClientId;

const focusTrackerKey = "focus-tracker";

function init(container) {
  liveEnabled = false;
  requestPermission().then(function () {
    try {
      localStorage.getItem(focusTrackerKey);
    } catch (e) {
      liveEnabled = false;
      Em.Logger.info('Discourse desktop notifications are disabled - localStorage denied.');
      return;
    }
    liveEnabled = true;
    Em.Logger.info('Discourse desktop notifications are enabled.');

    init2(container);

  }).catch(function () {
    liveEnabled = false;
    Em.Logger.info('Discourse desktop notifications are disabled - permission denied.');
  });
}

function init2(container) {
  // Load up the current state of the notifications
  seenNotificationDates = {};
  Discourse.ajax("/notifications.json?silent=true").then(function(result) {
    updateSeenNotificationDatesFrom(result);
  });

  notificationTagName = "discourse-notification-popup-" + Discourse.SiteSettings.title;

  const messageBus = container.lookup('message-bus:main');
  mbClientId = messageBus.clientId;

  console.info("My client ID is", mbClientId);

  window.addEventListener("storage", function(e) {
    // note: This event only fires when other tabs setItem()
    const key = e.key;
    if (key !== focusTrackerKey) {
      return true;
    }
    if (primaryTab) {
      primaryTab = false;
      console.debug("Releasing focus to", e.oldValue);
    }
  });
  window.addEventListener("focus", function() {
    if (!primaryTab) {
      console.debug("Grabbing focus from", localStorage.getItem(focusTrackerKey));
      primaryTab = true;
      localStorage.setItem(focusTrackerKey, mbClientId);
    }
  });

  if (document.hidden) {
    primaryTab = false;
  } else {
    primaryTab = true;
    localStorage.setItem(focusTrackerKey, mbClientId);
    console.debug("Grabbing focus");
  }
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

      if (unreadCount === 0 || unseenCount === 0) {
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

// Utility function
function updateSeenNotificationDatesFrom(notifications) {
  const oldSeenNotificationDates = seenNotificationDates;
  let newSeenNotificationDates = {};
  let previouslyUnseenNotifications = [];

  notifications.forEach(function(notification) {
    const dateString = new Date(notification.created_at).toUTCString();

    if (!oldSeenNotificationDates[dateString]) {
      previouslyUnseenNotifications.push(notification);
    }
    newSeenNotificationDates[dateString] = true;
  });

  seenNotificationDates = newSeenNotificationDates;
  return previouslyUnseenNotifications;
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
