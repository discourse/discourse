/**
  Handles routes related to viewing email logs.

  @class AdminEmailSentRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminEmailLogsRoute = Discourse.Route.extend({

  model: function() {
    return Discourse.EmailLog.findAll({ status: this.get("status") });
  },

  setupController: function(controller, model) {
    controller.set("model", model);
    // resets the filters
    controller.set("filter", { status: this.get("status") });
  },

  renderTemplate: function() {
    this.render("admin/templates/email_" + this.get("status"), { into: "adminEmail" });
  }

});

Discourse.AdminEmailAllRoute = Discourse.AdminEmailLogsRoute.extend({ status: "all" });
Discourse.AdminEmailSentRoute = Discourse.AdminEmailLogsRoute.extend({ status: "sent" });
Discourse.AdminEmailSkippedRoute = Discourse.AdminEmailLogsRoute.extend({ status: "skipped" });
