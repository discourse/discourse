Discourse.NotificationController = Discourse.ObjectController.extend({
  scope: function() {
    return "notifications." + Discourse.Site.currentProp("notificationLookup")[this.get("notification_type")];
  }.property(),

  username: function() {
    return this.get("data.display_username");
  }.property(),

  link: function() {
    if (this.blank("data.topic_title")) {
      return "";
    }
    var url = Discourse.Utilities.postUrl(this.get("slug"), this.get("topic_id"), this.get("post_number"));
    return '<a href="' + url + '">' + this.get("data.topic_title") + '</a>';
  }.property()
});
