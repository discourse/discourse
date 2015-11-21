import debounce from 'discourse/lib/debounce';
import EmailLog from 'admin/models/email-log';

export default Ember.Controller.extend({

  filterEmailLogs: debounce(function() {
    var self = this;
    EmailLog.findAll(this.get("filter")).then(function(logs) {
      self.set("model", logs);
    });
  }, 250).observes("filter.user", "filter.address", "filter.type", "filter.reply_key")
});
