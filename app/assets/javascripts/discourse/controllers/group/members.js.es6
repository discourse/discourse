/**
 Handles displaying members within a group

 @class GroupIndexController
 @extends Ember.ArrayController
 @namespace Discourse
 @module Discourse
 **/
export default Ember.ArrayController.extend({
  needs: ['group'],

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
    addMember: function() {
      var self = this;
      var usernames = this.get('emailOrUsername').split(',');
      console.log("Ask the group to add members", usernames);

      var group = this.get('controllers.group').model;

      group.addMembers(usernames).then(function(results) {
        var users = results.map(function(u) { return Discourse.User.create(u) });
        return self.unshiftObjects(users);
      });
    },
  }
});
