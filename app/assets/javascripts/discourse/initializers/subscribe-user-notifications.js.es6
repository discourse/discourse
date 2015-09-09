// Subscribes to user events on the message bus
import { init as initDesktopNotifications, onNotification } from 'discourse/lib/desktop-notifications';

export default {
  name: 'subscribe-user-notifications',
  after: 'message-bus',
  initialize(container) {
    const user = container.lookup('current-user:main'),
          site = container.lookup('site:main'),
          siteSettings = container.lookup('site-settings:main'),
          bus = container.lookup('message-bus:main'),
          keyValueStore = container.lookup('key-value-store:main');

    // clear old cached notifications
    // they could be a week old for all we know
    keyValueStore.remove('recent-notifications');

    if (user) {

      if (user.get('staff')) {
        bus.subscribe('/flagged_counts', (data) => {
          user.set('site_flagged_posts_count', data.total);
        });
        bus.subscribe('/queue_counts', (data) => {
          user.set('post_queue_new_count', data.post_queue_new_count);
          if (data.post_queue_new_count > 0) {
            user.set('show_queued_posts', 1);
          }
        });
      }

      bus.subscribe("/notification-alert/" + user.get('id'), function(data){
        onNotification(data, user);
      });

      bus.subscribe("/notification/" + user.get('id'), function(data) {
        const oldUnread = user.get('unread_notifications');
        const oldPM = user.get('unread_private_messages');

        user.set('unread_notifications', data.unread_notifications);
        user.set('unread_private_messages', data.unread_private_messages);

        if (oldUnread !== data.unread_notifications || oldPM !== data.unread_private_messages) {
          user.set('lastNotificationChange', new Date());
        }

        var stale = keyValueStore.getObject('recent-notifications');
        const lastNotification = data.last_notification && data.last_notification.notification;

        if (stale && stale.notifications && lastNotification) {

          const oldNotifications = stale.notifications;
          const staleIndex = _.findIndex(oldNotifications, {id: lastNotification.id});

          if (staleIndex > -1) {
            oldNotifications.splice(staleIndex, 1);
          }

          // this gets a bit tricky, uread pms are bumped to front
          var insertPosition = 0;
          if (lastNotification.notification_type !== 6) {
            insertPosition = _.findIndex(oldNotifications, function(n){
              return n.notification_type !== 6 || n.read;
            });
            insertPosition = insertPosition === -1 ? oldNotifications.length - 1 : insertPosition;
          }

          oldNotifications.splice(insertPosition, 0, lastNotification);
          keyValueStore.setItem('recent-notifications', JSON.stringify(stale));

        }
      }, user.notification_channel_position);

      bus.subscribe("/categories", function(data) {
        _.each(data.categories, function(c) {
          site.updateCategory(c);
        });
        _.each(data.deleted_categories,function(id) {
          site.removeCategory(id);
        });
      });

      bus.subscribe("/client_settings", function(data) {
        siteSettings[data.name] = data.value;
      });

      if (!Ember.testing) {
        initDesktopNotifications(bus);
      }
    }
  }
};
