import EmailLog from 'admin/models/email-log';

export default Ember.Controller.extend({
  loadMore() {
    return EmailLog.findAll(this.get("filter"), this.get("model.length"))
                   .then(logs => {
                      if (logs.length < 50) { this.get("model").set("allLoaded", true); }
                      this.get("model").addObjects(logs);
                   });
  }
});
