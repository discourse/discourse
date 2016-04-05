import IncomingEmail from 'admin/models/incoming-email';

export default Ember.Controller.extend({
  loading: false,

  actions: {

    loadMore() {
      if (this.get("loading") || this.get("model.allLoaded")) { return; }
      this.set('loading', true);

      IncomingEmail.findAll(this.get("filter"), this.get("model.length"))
                     .then(incoming => {
                        if (incoming.length < 50) { this.get("model").set("allLoaded", true); }
                        this.get("model").addObjects(incoming);
                     }).finally(() => {
                       this.set('loading', false);
                     });
    }
  }
});
