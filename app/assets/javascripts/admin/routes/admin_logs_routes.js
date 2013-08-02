/**
  Index redirects to a default logs index.

  @class AdminLogsIndexRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminLogsIndexRoute = Discourse.Route.extend({
  redirect: function() {
    this.transitionTo('adminLogs.blockedEmails');
  }
});

/**
  The route that lists blocked email addresses.

  @class AdminLogsBlockedEmailsRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminLogsBlockedEmailsRoute = Discourse.Route.extend({
  // model: function() {
  //   return Discourse.BlockedEmail.findAll();
  // },

  renderTemplate: function() {
    this.render('admin/templates/logs/blocked_emails', {into: 'adminLogs'});
  },

  setupController: function() {
    return this.controllerFor('adminLogsBlockedEmails').show();
  }
});