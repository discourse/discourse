/**
  A base admin controller that has access to the Discourse properties.

  @class AdminController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminController = Discourse.Controller.extend({
  showBadges: function() {
    return this.get('currentUser.admin') && Discourse.SiteSettings.enable_badges;
  }.property()
});
