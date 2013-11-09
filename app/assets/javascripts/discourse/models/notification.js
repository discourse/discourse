/**
  A data model representing a notification a user receives

  @class Notification
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.Notification = Discourse.Model.extend({

  readClass: (function() {
    if (this.read) return 'read';
    return '';
  }).property('read'),

  url: function() {
    if (this.blank('data.topic_title')) return "";
    return Discourse.Utilities.postUrl(this.get('slug'), this.get('topic_id'), this.get('post_number'));
  }.property(),

  rendered: function() {
    var notificationName = Discourse.Site.currentProp('notificationLookup')[this.notification_type];
    return I18n.t("notifications." + notificationName, {
      username: this.data.display_username,
      link: "<a href='" + (this.get('url')) + "'>" + this.data.topic_title + "</a>"
    });
  }.property()

});

Discourse.Notification.reopenClass({
  create: function(obj) {
    obj = obj || {};

    if (obj.data) {
      obj.data = Em.Object.create(obj.data);
    }
    return this._super(obj);
  }
});


