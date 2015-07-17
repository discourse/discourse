const INVITED_TYPE = 8;

export default Ember.Component.extend({
  tagName: 'li',
  classNameBindings: ['notification.read', 'notification.is_warning'],

  scope: function() {
    var notificationType = this.get("notification.notification_type");
    var lookup = this.site.get("notificationLookup");
    var name = lookup[notificationType];

    if (name === "custom") {
      return this.get("notification.data.message");
    } else {
      return "notifications." + name;
    }
  }.property("notification.notification_type"),

  url: function() {
    const it = this.get('notification');
    const badgeId = it.get("data.badge_id");
    if (badgeId) {
      const badgeName = it.get("data.badge_name");
      return Discourse.getURL('/badges/' + badgeId + '/' + badgeName.replace(/[^A-Za-z0-9_]+/g, '-').toLowerCase());
    }

    const topicId = it.get('topic_id');
    if (topicId) {
      return Discourse.Utilities.postUrl(it.get("slug"), topicId, it.get("post_number"));
    }

    if (it.get('notification_type') === INVITED_TYPE) {
      return Discourse.getURL('/my/invited');
    }
  }.property("notification.data.{badge_id,badge_name}", "model.slug", "model.topic_id", "model.post_number"),

  description: function() {
    const badgeName = this.get("notification.data.badge_name");
    if (badgeName) { return Handlebars.Utils.escapeExpression(badgeName); }

    const title = this.get('notification.data.topic_title');
    return Ember.isEmpty(title) ? "" : Handlebars.Utils.escapeExpression(title);
  }.property("notification.data.{badge_name,topic_title}"),

  _markRead: function(){
    this.$('a').click(() => {
      this.set('notification.read', true);
      return true;
    });
  }.on('didInsertElement'),

  render(buffer) {
    const notification = this.get('notification');
    const description = this.get('description');
    const username = notification.get('data.display_username');
    const text = Discourse.Emoji.unescape(I18n.t(this.get('scope'), {description, username}));

    const url = this.get('url');
    if (url) {
      buffer.push('<a href="' + url + '">' + text + '</a>');
    } else {
      buffer.push(text);
    }
  }
});
