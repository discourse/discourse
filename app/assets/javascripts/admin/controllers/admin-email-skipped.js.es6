import debounce from 'discourse/lib/debounce';

export default Ember.Controller.extend({
  filterEmailLogs: debounce(function() {
    const EmailLog = require('admin/models/email-log').default;
    EmailLog.findAll(this.get("filter")).then(logs => this.set("model", logs));
  }, 250).observes("filter.user", "filter.address", "filter.type", "filter.skipped_reason")
});
