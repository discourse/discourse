(function() {

  window.Discourse.Notification = Discourse.Model.extend(Discourse.Presence, {
    readClass: (function() {
      if (this.read) {
        return 'read';
      } else {
        return '';
      }
    }).property('read'),
    url: (function() {
      var slug;
      if (this.blank('data.topic_title')) {
        return "";
      }
      slug = this.get('slug');
      return "/t/" + slug + "/" + (this.get('topic_id')) + "/" + (this.get('post_number'));
    }).property(),
    rendered: (function() {
      var notificationName;
      notificationName = Discourse.get('site.notificationLookup')[this.notification_type];
      return Em.String.i18n("notifications." + notificationName, {
        username: this.data.display_username,
        link: "<a href='" + (this.get('url')) + "'>" + this.data.topic_title + "</a>"
      });
    }).property()
  });

  window.Discourse.Notification.reopenClass({
    create: function(obj) {
      var result;
      result = this._super(obj);
      if (obj.data) {
        result.set('data', Em.Object.create(obj.data));
      }
      return result;
    }
  });

}).call(this);
