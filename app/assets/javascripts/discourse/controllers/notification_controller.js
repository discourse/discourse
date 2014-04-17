Discourse.NotificationController = Discourse.ObjectController.extend({
  scope: function() {
    return "notifications." + Discourse.Site.currentProp("notificationLookup")[this.get("notification_type")];
  }.property(),

  username: function() {
    return this.get("data.display_username");
  }.property(),

  link: function() {
    if (this.get('data.badge_id')) {
      return '<a href="/badges/' + this.get('data.badge_id') + '/' + this.get('data.badge_name').replace(/[^A-Za-z0-9_]+/g, '-').toLowerCase() + '">' + this.get('data.badge_name') + '</a>';
    }
    if (this.blank("data.topic_title")) {
      return "";
    }
    var url = Discourse.Utilities.postUrl(this.get("slug"), this.get("topic_id"), this.get("post_number"));
    return '<a href="' + url + '">' + this.get("data.topic_title") + '</a>';
  }.property()
});
