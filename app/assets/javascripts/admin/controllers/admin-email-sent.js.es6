import DiscourseController from 'discourse/controllers/controller';
import debounce from 'discourse/lib/debounce';

export default DiscourseController.extend({

  filterEmailLogs: debounce(function() {
    var self = this;
    Discourse.EmailLog.findAll(this.get("filter")).then(function(logs) {
      self.set("model", logs);
    });
  }, 250).observes("filter.user", "filter.address", "filter.type", "filter.reply_key")
});
