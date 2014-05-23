/**
   Subscribes to user events on the message bus
**/
export default {
  name: "subscribe-user-notifications",
  after: 'message-bus',
  initialize: function() {
    var user = Discourse.User.current();
    if (user) {
      var bus = Discourse.MessageBus;
      bus.callbackInterval = Discourse.SiteSettings.polling_interval;
      bus.enableLongPolling = true;
      bus.baseUrl = Discourse.getURL("/");

      if (user.admin || user.moderator) {
        bus.subscribe("/flagged_counts", function(data) {
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
        var site = Discourse.Site.current();
        _.each(data.categories,function(c){
          site.updateCategory(c);
        });
      });
    }
  }
};
