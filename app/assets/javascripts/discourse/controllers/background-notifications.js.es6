
// TODO deduplicate controllers/notification.js
function notificationUrl(n) {
  const it = Em.Object.create(n);

  var badgeId = it.get("data.badge_id");
  if (badgeId) {
    var badgeName = it.get("data.badge_name");
    return '/badges/' + badgeId + '/' + badgeName.replace(/[^A-Za-z0-9_]+/g, '-').toLowerCase();
  }

  var topicId = it.get('topic_id');
  if (topicId) {
    return Discourse.Utilities.postUrl(it.get("slug"), topicId, it.get("post_number"));
  }

  if (it.get('notification_type') === INVITED_TYPE) {
    return '/my/invited';
  }
}

export default Discourse.Controller.extend({

  initSeenNotifications: function() {
    const self = this;

    // TODO make protocol to elect a tab responsible for desktop notifications
    // and choose a new one when a tab is closed
    // apparently needs to use localStorage !?
    // https://github.com/diy/intercom.js

    // Just causes a bit of a visual glitch as multiple are created and
    // instantly replaced as is
    self.set('primaryTab', true);

    self.set('liveEnabled', false);
    this.requestPermission().then(function() {
      self.set('liveEnabled', true);
    }).catch(function() {
      self.set('liveEnabled', false);
    });

    self.set('seenNotificationDates', {});
    Discourse.ajax("/notifications.json?silent=true").then(function(result) {
      self.updateSeenNotificationDatesFrom(result);
    });
  }.on('init'),

  // Call-in point from message bus
  notificationsChanged(currentUser) {
    if (!this.get('liveEnabled')) { return; }
    if (!this.get('primaryTab')) { return; }

    const blueNotifications = currentUser.get('unread_notifications');
    const greenNotifications = currentUser.get('unread_private_messages');
    const self = this;

    if (blueNotifications > 0 || greenNotifications > 0) {
      Discourse.ajax("/notifications.json?silent=true").then(function(result) {

        const unread = result.filter(n => !n.read);
        const unseen = self.updateSeenNotificationDatesFrom(result);
        const unreadCount = unread.length;
        const unseenCount = unseen.length;

        if (unreadCount === 0 || unseenCount === 0) {
          return;
        }
        if (typeof document.hidden !== "undefined" && !document.hidden) {
          return;
        }

        let bodyParts = [];

        unread.forEach(function(n) {
          const i18nOpts = {
            username: n.data['display_username'],
            topic: n.data['topic_title'],
            badge: n.data['badge_name']
          };

          bodyParts.push(I18n.t(self.i18nKey(n), i18nOpts));
        });

        const notificationTitle = I18n.t('notifications.popup_title', { count: unreadCount, site_title: Discourse.SiteSettings.title });
        const notificationBody = bodyParts.join("\n");
        const notificationIcon = Discourse.SiteSettings.logo_small_url || Discourse.SiteSettings.logo_url;
        const notificationTag = self.get('notificationTagName');

        // This shows the notification!
        const notification = new Notification(notificationTitle, {
          body: notificationBody,
          icon: notificationIcon,
          tag: notificationTag
        });

        const firstUnseen = unseen[0];

        function clickEventHandler() {
          Discourse.URL.routeTo(notificationUrl(firstUnseen));
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
  },

  // Utility function
  // Wraps Notification.requestPermission in a Promise
  requestPermission() {
    return new Ember.RSVP.Promise(function(resolve, reject) {
      Notification.requestPermission(function(status) {
        if (status === "granted") {
          Em.Logger.info('Discourse desktop notifications are enabled.');
          resolve();
        } else {
          Em.Logger.info('Discourse desktop notifications are disabled.');
          reject();
        }
      });
    });
  },

  i18nKey(notification) {
    let key = "notifications.popup." + this.site.get("notificationLookup")[notification.notification_type];
    if (notification.data.display_username && notification.data.original_username &&
      notification.data.display_username !== notification.data.original_username) {
      key += "_mul";
    }
    return key;
  },

  notificationTagName: function() {
    return "discourse-notification-popup-" + Discourse.SiteSettings.title;
  }.property(),

  // Utility function
  updateSeenNotificationDatesFrom(notifications) {
    const oldSeenNotificationDates = this.get('seenNotificationDates');
    let newSeenNotificationDates = {};
    let previouslyUnseenNotifications = [];

    notifications.forEach(function(notification) {
      const dateString = new Date(notification.created_at).toUTCString();

      if (!oldSeenNotificationDates[dateString]) {
        previouslyUnseenNotifications.push(notification);
      }
      newSeenNotificationDates[dateString] = true;
    });

    this.set('seenNotificationDates', newSeenNotificationDates);
    return previouslyUnseenNotifications;
  }
})
