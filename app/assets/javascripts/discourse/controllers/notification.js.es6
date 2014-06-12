export default Discourse.ObjectController.extend({
  scope: function() {
    return "notifications." + Discourse.Site.currentProp("notificationLookup")[this.get("notification_type")];
  }.property(),

  username: function() {
    return this.get("data.display_username");
  }.property(),

  safe: function(prop){
    var val = this.get(prop);
    if(val) {
      val = Handlebars.Utils.escapeExpression(val);
    }
    return val;
  },

  link: function() {

    var badgeId = this.safe('data.badge_id');
    if (badgeId) {
      var badgeName = this.safe('data.badge_name');
      return '<a href="/badges/' + badgeId + '/' + badgeName.replace(/[^A-Za-z0-9_]+/g, '-').toLowerCase() + '">' + badgeName + '</a>';
    }

    if (this.blank("data.topic_title")) {
      return "";
    }

    var url = Discourse.Utilities.postUrl(this.safe("slug"), this.safe("topic_id"), this.safe("post_number"));
    return '<a href="' + url + '">' + this.safe("data.topic_title") + '</a>';
  }.property()
});
