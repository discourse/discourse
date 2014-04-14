  /**
  This controller supports email logs functionality.

  @class AdminEmailSentController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminEmailSentController = Discourse.Controller.extend({

  filterEmailLogs: Discourse.debounce(function() {
    var self = this;
    Discourse.EmailLog.findAll(this.get("filter")).then(function(logs) {
      self.set("model", logs);
    });
  }, 250).observes("filter.user", "filter.address", "filter.type", "filter.reply_key")
});

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
    Discourse.EmailLog.findAll(this.get("filter")).then(function(logs) {
      self.set("model", logs);
    });
  }, 250).observes("filter.user", "filter.address", "filter.type", "filter.skipped_reason")
});


Discourse.AdminEmailAllController = Discourse.AdminEmailSkippedController.extend({});
