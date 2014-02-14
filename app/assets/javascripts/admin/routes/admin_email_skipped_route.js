/**
  Handles routes related to viewing email logs of emails that were NOT sent.

  @class AdminEmailSkippedRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminEmailSkippedRoute = Discourse.Route.extend({
  model: function() {
    return Discourse.EmailLog.findAll('skipped');
  },

  renderTemplate: function() {
    this.render('admin/templates/email_skipped', {into: 'adminEmail'});
  }
});
