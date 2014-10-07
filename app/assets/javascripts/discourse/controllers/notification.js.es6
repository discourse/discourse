import ObjectController from 'discourse/controllers/object';

var INVITED_TYPE= 8;

export default ObjectController.extend({

  scope: function () {
    return "notifications." + Discourse.Site.currentProp("notificationLookup")[this.get("notification_type")];
  }.property("notification_type"),

  username: Em.computed.alias("data.display_username"),

  safe: function (prop) {
    var val = this.get(prop);
    if (val) { val = Handlebars.Utils.escapeExpression(val); }
    return val;
  },

  url: function () {
    var badgeId = this.safe("data.badge_id");
    if (badgeId) {
      var badgeName = this.safe("data.badge_name");
      return '/badges/' + badgeId + '/' + badgeName.replace(/[^A-Za-z0-9_]+/g, '-').toLowerCase();
    }

    var topicId = this.safe('topic_id');
    if (topicId) {
      return Discourse.Utilities.postUrl(this.safe("slug"), topicId, this.safe("post_number"));
    }

    if (this.get('notification_type') === INVITED_TYPE) {
      return '/my/invited';
    }
  }.property("data.{badge_id,badge_name}", "slug", "topic_id", "post_number"),

  description: function () {
    var badgeName = this.safe("data.badge_name");
    if (badgeName) { return badgeName; }
    return this.blank("data.topic_title") ? "" : this.safe("data.topic_title");
  }.property("data.{badge_name,topic_title}")

});
