/**
  This controller supports all actions on a user's activity stream

  @class UserActivityController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.UserActivityController = Discourse.ObjectController.extend({
  needs: ['composer']
});
