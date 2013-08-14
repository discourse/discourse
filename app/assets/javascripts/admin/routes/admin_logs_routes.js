/**
  Index redirects to a default logs index.

  @class AdminLogsIndexRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminLogsIndexRoute = Discourse.Route.extend({
  redirect: function() {
    this.transitionTo('adminLogs.staffActionLogs');
  }
});

/**
  The route that lists blocked email addresses.

  @class AdminLogsScreenedEmailsRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminLogsScreenedEmailsRoute = Discourse.Route.extend({
  renderTemplate: function() {
    this.render('admin/templates/logs/screened_emails', {into: 'adminLogs'});
  },

  setupController: function() {
    return this.controllerFor('adminLogsScreenedEmails').show();
  }
});

/**
  The route that lists staff actions that were logged.

  @class AdminLogsStaffActionLogsRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminLogsStaffActionLogsRoute = Discourse.Route.extend({
  renderTemplate: function() {
    this.render('admin/templates/logs/staff_action_logs', {into: 'adminLogs'});
  },

  setupController: function(controller) {
    var queryParams = Discourse.URL.get('queryParams');
    if (queryParams) {
      controller.set('filters', queryParams);
    }
    return controller.show();
  },

  deactivate: function() {
    this._super();

    // Clear any filters when we leave the route
    Discourse.URL.set('queryParams', null);
  }
});