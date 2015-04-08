import ObjectController from 'discourse/controllers/object';
import { notificationUrl } from 'discourse/lib/desktop-notifications';

var INVITED_TYPE= 8;

const NotificationController = ObjectController.extend({

  scope: function() {
    return "notifications." + this.site.get("notificationLookup")[this.get("notification_type")];
  }.property("notification_type"),

  username: Em.computed.alias("data.display_username"),

  // This is model logic
  // It belongs in a model
  // TODO deduplicate controllers/background-notifications.js
  url: function() {
    return notificationUrl(this);
  }.property("data.{badge_id,badge_name}", "slug", "topic_id", "post_number"),

  description: function() {
    const badgeName = this.get("data.badge_name");
    if (badgeName) { return Handlebars.Utils.escapeExpression(badgeName); }
    return this.blank("data.topic_title") ? "" : Handlebars.Utils.escapeExpression(this.get("data.topic_title"));
  }.property("data.{badge_name,topic_title}")

});

export default NotificationController;
