/**
  This controller handles general user actions

  @class UserController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.UserController = Discourse.ObjectController.extend({

  viewingSelf: function() {
    return this.get('content.username') === this.get('currentUser.username');
  }.property('content.username', 'currentUser.username'),

  canSeePrivateMessages: Ember.computed.or('viewingSelf', 'currentUser.staff')

});
