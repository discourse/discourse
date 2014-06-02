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

    if (details.participants) {
      var topic = this.get('topic');
      details.participants = details.participants.map(function (p) {
        p.topic = topic;
        return Em.Object.create(p);
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
    var level = this.get('notification_level');
    if(typeof level !== 'number'){
      level = 1;
    }

    var localeString = "topic.notifications.reasons." + level;
    if (typeof this.get('notifications_reason_id') === 'number') {
      var tmp = localeString +  "_" + this.get('notifications_reason_id');
      // some sane protection for missing translations of edge cases
      if(I18n.lookup(tmp)){
        localeString = tmp;
      }
    }
    return I18n.t(localeString, { username: Discourse.User.currentProp('username_lower') });
  }.property('notification_level', 'notifications_reason_id'),


  updateNotifications: function(v) {
    this.set('notification_level', v);
    this.set('notifications_reason_id', null);
    return Discourse.ajax("/t/" + (this.get('topic.id')) + "/notifications", {
      type: 'POST',
      data: { notification_level: v }
    });
  },

  removeAllowedUser: function(user) {
    var users = this.get('allowed_users'),
        username = user.get('username');

    Discourse.ajax("/t/" + this.get('topic.id') + "/remove-allowed-user", {
      type: 'PUT',
      data: { username: username }
    }).then(function() {
      users.removeObject(users.findProperty('username', username));
    });
  }
});
