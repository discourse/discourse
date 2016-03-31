import EmailLog from 'admin/models/email-log';

export default Ember.Controller.extend({
  loading: false,

  actions: {
    loadMore() {
      if (this.get("loading") || this.get("model.allLoaded")) { return; }

      this.set('loading', true);
      return EmailLog.findAll(this.get("filter"), this.get("model.length"))
                     .then(logs => {
                        if (logs.length < 50) { this.get("model").set("allLoaded", true); }
                        this.get("model").addObjects(logs);
                     }).finally(() => {
                       this.set('loading', false);
                     });
    }
  }
});
