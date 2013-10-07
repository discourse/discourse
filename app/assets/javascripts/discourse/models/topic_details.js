/**
  A model representing a Topic's details that aren't always present, such as a list of participants.
  When showing topics in lists and such this information should not be required.

  @class TopicDetails
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicDetails = Discourse.Model.extend({
  loaded: false,

  updateFromJson: function(details) {
    if (details.allowed_users) {
      details.allowed_users = details.allowed_users.map(function (u) {
        return Discourse.User.create(u);
      });
    }

    if (details.suggested_topics) {
      details.suggested_topics = details.suggested_topics.map(function (st) {
        return Discourse.Topic.create(st);
      });
    }

    this.setProperties(details);
    this.set('loaded', true);
  },

  fewParticipants: function() {
    if (!this.present('participants')) return null;
    return this.get('participants').slice(0, 3);
  }.property('participants'),


  notificationReasonText: function() {
    var locale_string = "topic.notifications.reasons." + (this.get('notification_level') || 1);
    if (typeof this.get('notifications_reason_id') === 'number') {
      locale_string += "_" + this.get('notifications_reason_id');
    }
    return I18n.t(locale_string, { username: Discourse.User.currentProp('username_lower') });
  }.property('notification_level', 'notifications_reason_id'),


  updateNotifications: function(v) {
    this.set('notification_level', v);
    this.set('notifications_reason_id', null);
    return Discourse.ajax("/t/" + (this.get('topic.id')) + "/notifications", {
      type: 'POST',
      data: { notification_level: v }
    });
  },

  removeAllowedUser: function(username) {
    var users = this.get('allowed_users');
    Discourse.ajax("/t/" + this.get('topic.id') + "/remove-allowed-user", {
      type: 'PUT',
      data: { username: username }
    }).then(function(res) {
      users.removeObject(users.findProperty('username', username));
    });
  }
});
