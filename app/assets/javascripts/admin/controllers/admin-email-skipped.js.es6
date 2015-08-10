import debounce from 'discourse/lib/debounce';
import DiscourseController from 'discourse/controllers/controller';

export default DiscourseController.extend({
  filterEmailLogs: debounce(function() {
    var self = this;
    Discourse.EmailLog.findAll(this.get("filter")).then(function(logs) {
      self.set("model", logs);
    });
  }, 250).observes("filter.user", "filter.address", "filter.type", "filter.skipped_reason")
});
