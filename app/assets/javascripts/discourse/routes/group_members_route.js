/**
  Set things up to display the members of a group

  @class GroupMembersRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.GroupMembersRoute = Discourse.Route.extend({
  model: function() {
    return this.modelFor('group');
  },

  afterModel: function(model) {
    var self = this;
    return model.findMembers().then(function(result) {
      self.set('_members', result);
    });
  },

  setupController: function(controller) {
    controller.set('model', this.get('_members'));
    this.controllerFor('group').set('showing', 'members');
  }

});

