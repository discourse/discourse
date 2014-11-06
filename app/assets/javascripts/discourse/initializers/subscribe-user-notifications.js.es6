/**
   Subscribes to user events on the message bus
**/
export default {
  name: 'subscribe-user-notifications',
  after: 'message-bus',
  initialize: function(container) {
    var user = Discourse.User.current();

    var site = container.lookup('site:main'),
        siteSettings = container.lookup('site-settings:main');

    var bus = Discourse.MessageBus;
    bus.callbackInterval = siteSettings.anon_polling_interval;
    bus.backgroundCallbackInterval = siteSettings.background_polling_interval;
    bus.baseUrl = siteSettings.long_polling_base_url;

    if (bus.baseUrl !== '/') {
      // zepto compatible, 1 param only
      bus.ajax = function(opts){
        opts.headers = opts.headers || {};
        opts.headers['X-Shared-Session-Key'] = $('meta[name=shared_session_key]').attr('content');
        return $.ajax(opts);
      };
    } else {
      bus.baseUrl = Discourse.getURL('/');
    }

    if (user) {
      bus.callbackInterval = siteSettings.polling_interval;
      bus.enableLongPolling = true;

      if (user.admin || user.moderator) {
        bus.subscribe('/flagged_counts', function(data) {
          user.set('site_flagged_posts_count', data.total);
        });
      }
      bus.subscribe("/notification/" + user.get('id'), (function(data) {
        var oldUnread = user.get('unread_notifications');
        var oldPM = user.get('unread_private_messages');

        user.set('unread_notifications', data.unread_notifications);
        user.set('unread_private_messages', data.unread_private_messages);

        if(oldUnread !== data.unread_notifications || oldPM !== data.unread_private_messages) {
          user.set('lastNotificationChange', new Date());
        }
      }), user.notification_channel_position);

      bus.subscribe("/categories", function(data){
        _.each(data.categories,function(c){
          site.updateCategory(c);
        });
      });
    }
  }
};
