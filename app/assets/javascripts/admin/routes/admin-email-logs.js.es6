import EmailLog from 'admin/models/email-log';

/**
  Handles routes related to viewing email logs.

  @class AdminEmailSentRoute
  @extends Discourse.Route
  @namespace Discourse
  @module Discourse
**/
export default Discourse.Route.extend({

  model: function() {
    return EmailLog.findAll({ status: this.get("status") });
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
