const LIKED_TYPE = 5;
const INVITED_TYPE = 8;
const GROUP_SUMMARY_TYPE = 16;

export default Ember.Component.extend({
  tagName: 'li',
  classNameBindings: ['notification.read', 'notification.is_warning'],

  name: function() {
    var notificationType = this.get("notification.notification_type");
    var lookup = this.site.get("notificationLookup");
    return lookup[notificationType];
  }.property("notification.notification_type"),

  scope: function() {
    if (this.get("name") === "custom") {
      return this.get("notification.data.message");
    } else {
      return "notifications." + this.get("name");
    }
  }.property("name"),

  url: function() {
    const it = this.get('notification');
    const badgeId = it.get("data.badge_id");
    if (badgeId) {
      var badgeSlug = it.get("data.badge_slug");

      if (!badgeSlug) {
        const badgeName = it.get("data.badge_name");
        badgeSlug = badgeName.replace(/[^A-Za-z0-9_]+/g, '-').toLowerCase();
      }

      var username = it.get('data.username');
      username = username ? "?username=" + username.toLowerCase() : "";
      return Discourse.getURL('/badges/' + badgeId + '/' + badgeSlug + username);
    }

    const topicId = it.get('topic_id');
    if (topicId) {
      return Discourse.Utilities.postUrl(it.get("slug"), topicId, it.get("post_number"));
    }

    if (it.get('notification_type') === INVITED_TYPE) {
      return Discourse.getURL('/users/' + it.get('data.display_username'));
    }

    if (it.get('data.group_id')) {
      return Discourse.getURL('/users/' + it.get('data.username') + '/messages/group/' + it.get('data.group_name'));
    }

  }.property("notification.data.{badge_id,badge_name,display_username}", "model.slug", "model.topic_id", "model.post_number"),

  description: function() {
    const badgeName = this.get("notification.data.badge_name");
    if (badgeName) { return Discourse.Utilities.escapeExpression(badgeName); }

    const title = this.get('notification.data.topic_title');
    return Ember.isEmpty(title) ? "" : Discourse.Utilities.escapeExpression(title);
  }.property("notification.data.{badge_name,topic_title}"),

  _markRead: function(){
    this.$('a').click(() => {
      this.set('notification.read', true);
      Discourse.setTransientHeader("Discourse-Clear-Notifications", this.get('notification.id'));
      if (document && document.cookie) {
        document.cookie = `cn=${this.get('notification.id')}; expires=Fri, 31 Dec 9999 23:59:59 GMT`;
      }
      return true;
    });
  }.on('didInsertElement'),

  render(buffer) {
    const notification = this.get('notification');
    // since we are reusing views now sometimes this can be unset
    if (!notification) { return; }
    const description = this.get('description');
    const username = notification.get('data.display_username');
    var text;
    if (notification.get('notification_type') === GROUP_SUMMARY_TYPE) {
      const count = notification.get('data.inbox_count');
      const group_name = notification.get('data.group_name');
      text = I18n.t(this.get('scope'), {count, group_name});
    } else if (notification.get('notification_type') === LIKED_TYPE && notification.get("data.count") > 1)  {
      const count = notification.get('data.count') - 2;
      const username2 = notification.get('data.username2');
      if (count===0) {
        text = I18n.t('notifications.liked_2', {description, username, username2});
      } else {
        text = I18n.t('notifications.liked_many', {description, username, username2, count});
      }
    }
    else {
      text = I18n.t(this.get('scope'), {description, username});
    }
    text = Discourse.Emoji.unescape(text);

    const url = this.get('url');
    if (url) {
      buffer.push('<a href="' + url + '" alt="' + I18n.t('notifications.alt.' + this.get("name")) + '">' + text + '</a>');
    } else {
      buffer.push(text);
    }
  }
});
