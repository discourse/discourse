/**
  A model representing a Topic's details that aren't always present, such as a list of participants.
  When showing topics in lists and such this information should not be required.
**/
import RestModel from 'discourse/models/rest';

const TopicDetails = RestModel.extend({
  loaded: false,

  updateFromJson(details) {
    const topic = this.get('topic');

    if (details.allowed_users) {
      details.allowed_users = details.allowed_users.map(function (u) {
        return Discourse.User.create(u);
      });
    }

    if (details.suggested_topics) {
      const store = this.store;
      details.suggested_topics = details.suggested_topics.map(function (st) {
        return store.createRecord('topic', st);
      });
    }

    if (details.participants) {
      details.participants = details.participants.map(function (p) {
        p.topic = topic;
        return Ember.Object.create(p);
      });
    }

    this.setProperties(details);
    this.set('loaded', true);
  },

  fewParticipants: function() {
    if (!!Ember.isEmpty(this.get('participants'))) return null;
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


  updateNotifications(v) {
    this.set('notification_level', v);
    this.set('notifications_reason_id', null);
    return Discourse.ajax("/t/" + (this.get('topic.id')) + "/notifications", {
      type: 'POST',
      data: { notification_level: v }
    });
  },

  removeAllowedUser(user) {
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

export default TopicDetails;
