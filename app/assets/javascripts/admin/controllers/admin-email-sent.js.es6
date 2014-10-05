import DiscourseController from 'discourse/controllers/controller';

export default DiscourseController.extend({

  filterEmailLogs: Discourse.debounce(function() {
    var self = this;
    Discourse.EmailLog.findAll(this.get("filter")).then(function(logs) {
      self.set("model", logs);
    });
  }, 250).observes("filter.user", "filter.address", "filter.type", "filter.reply_key")
});
