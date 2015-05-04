import ObjectController from 'discourse/controllers/object';

const INVITED_TYPE = 8;

export default ObjectController.extend({

  notificationUrl: function(it) {
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
  },

  scope: function() {
    return "notifications." + this.site.get("notificationLookup")[this.get("notification_type")];
  }.property("notification_type"),

  username: Em.computed.alias("data.display_username"),

  url: function() {
    return this.notificationUrl(this);
  }.property("data.{badge_id,badge_name}", "slug", "topic_id", "post_number"),

  description: function() {
    const badgeName = this.get("data.badge_name");
    if (badgeName) { return Handlebars.Utils.escapeExpression(badgeName); }
    return this.blank("data.topic_title") ? "" : Handlebars.Utils.escapeExpression(this.get("data.topic_title"));
  }.property("data.{badge_name,topic_title}")

});
