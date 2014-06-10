/**
  This route shows a user's badges.

  @class UserBadgesRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.UserBadgesRoute = Discourse.Route.extend({
  model: function() {
    return Discourse.UserBadge.findByUsername(this.modelFor('user').get('username_lower'), {grouped: true});
  },

  setupController: function(controller, model) {
    this.controllerFor('user').set('indexStream', false);
    if (this.controllerFor('user_activity').get('content')) {
      this.controllerFor('user_activity').set('userActionType', -1);
    }
    controller.set('model', model);
  },

  renderTemplate: function() {
    this.render('user/badges', {into: 'user', outlet: 'userOutlet'});
  }
});
