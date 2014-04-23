/**
  Handles routes for admin groups

  @class AdminGroupsRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminGroupsRoute = Discourse.Route.extend({
  model: function() {
    return Discourse.Group.findAll();
  },

  actions: {
    showGroup: function(g) {
      // This hack is needed because the autocomplete plugin does not
      // refresh properly when the underlying data changes. TODO should
      // be to update the plugin so it works properly and remove this hack.
      var self = this;
      this.transitionTo('adminGroups.index').then(function() {
        self.transitionTo('adminGroup', g);
      });
    },

    newGroup: function(){
      var group = Discourse.Group.create({ visible: true });
      this.send('showGroup', group);
    }
  }
});

