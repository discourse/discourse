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
          keyValueStore = container.lookup('key-value-store:main'),
          store = container.lookup('store:main'),
          appEvents = container.lookup('app-events:main');

    // clear old cached notifications, we used to store in local storage
    // TODO 2017 delete this line
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

      bus.subscribe(`/notification/${user.get('id')}`, function(data) {
        const oldUnread = user.get('unread_notifications');
        const oldPM = user.get('unread_private_messages');

        user.set('unread_notifications', data.unread_notifications);
        user.set('unread_private_messages', data.unread_private_messages);

        if (oldUnread !== data.unread_notifications || oldPM !== data.unread_private_messages) {
          appEvents.trigger('notifications:changed');
        }

        const stale = store.findStale('notification', {}, {cacheKey: 'recent-notifications'});
        const lastNotification = data.last_notification && data.last_notification.notification;

        if (stale && stale.hasResults && lastNotification) {

          const oldNotifications = stale.results.get('content');
          const staleIndex = _.findIndex(oldNotifications, {id: lastNotification.id});

          if (staleIndex === -1) {
            // this gets a bit tricky, uread pms are bumped to front
            var insertPosition = 0;
            if (lastNotification.notification_type !== 6) {
              insertPosition = _.findIndex(oldNotifications, function(n){
                return n.notification_type !== 6 || n.read;
              });
              insertPosition = insertPosition === -1 ? oldNotifications.length - 1 : insertPosition;
            }

            oldNotifications.insertAt(insertPosition, Em.Object.create(lastNotification));
          }

          for (var idx=0; idx < data.recent.length; idx++) {
            var old;
            while(old = oldNotifications[idx]) {
              var info = data.recent[idx];

              if (old.get('id') !== info[0]) {
                oldNotifications.removeAt(idx);
              } else {
                if (old.get('read') !== info[1]) {
                  old.set('read', info[1]);
                }
                break;
              }
            }
            if ( !old ) { break; }
          }

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
        if (!site.mobileView) {
          bus.subscribe("/notification-alert/" + user.get('id'), function(data){
            onNotification(data, user);
          });

          initDesktopNotifications(bus);
        }
      }
    }
  }
};
