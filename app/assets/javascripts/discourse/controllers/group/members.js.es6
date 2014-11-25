/**
 Handles displaying members within a group

 @class GroupIndexController
 @extends Ember.ArrayController
 @namespace Discourse
 @module Discourse
 **/
export default Ember.ArrayController.extend({
  needs: ['group'],
  loading: false,

  groupName: function() {
    this.get('controllers.group.name');
  }.property('name'),

  removeMember: function(user) {
    var self = this;
    var group = this.get('controllers.group').model;

    group.removeMember(user.get('username')).then(function () {
      self.removeObject(user);
    });
  },

  canManageGroup: function() {
    return this.get('controllers.group.model.can_manage');
  }.property(),

  actions: {
    addMembers: function() {
      var self = this;
      var group = this.get('controllers.group').model;
      var add_usernames = this.get('add_usernames').split(',');

      group.addMembers(add_usernames).then(function(results) {
        return results.map(function(userdata) {
          self.unshiftObject(Discourse.User.create(userdata));
        });
      });
    },

    loadMore: function() {
      if (this.get('loading')) { return; }
      this.set('loading', true);

      var members = this.get('model');
      if (members && members.length) {
        var self = this;
        var group = this.get('controllers.group.model');

        group.findMembers({offset: members.length}).then(function(newMembers) {
          members.addObjects(newMembers);
          self.set('loading', false);
        });
      }
    }

  }
});
