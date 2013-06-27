/**
  This route handles shows a user's activity

  @class UserActivityRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserActivityRoute = Discourse.Route.extend({

  model: function() {
    return this.modelFor('user').findStream();
  },

  renderTemplate: function() {
    this.render({ into: 'user', outlet: 'userOutlet' });
  }

});


