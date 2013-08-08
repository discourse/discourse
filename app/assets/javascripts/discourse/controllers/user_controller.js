/**
  This controller handles general user actions

  @class UserController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.UserController = Discourse.ObjectController.extend({

  viewingSelf: function() {
    return this.get('content.username') === Discourse.User.currentProp('username');
  }.property('content.username'),

  canSeePrivateMessages: function() {
    return this.get('viewingSelf') || Discourse.User.currentProp('staff');
  }.property('viewingSelf')

});


