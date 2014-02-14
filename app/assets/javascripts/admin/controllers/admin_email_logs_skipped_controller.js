  /**
  This controller supports email logs functionality.

  @class AdminEmailSkippedController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminEmailSkippedController = Discourse.Controller.extend({

  filterEmailLogs: Discourse.debounce(function() {
    var self = this;
    this.set("loading", true);
    Discourse.EmailLog.findAll(this.get("filter")).then(function(logs) {
      self.set("model", false);
      self.set("model", logs);
    });
  }, 250).observes("filter.user", "filter.address", "filter.type", "filter.reason"),

});
