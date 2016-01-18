import IncomingEmail from 'admin/models/incoming-email';

export default Ember.Controller.extend({
  loadMore() {
    return IncomingEmail.findAll(this.get("filter"), this.get("model.length"))
                   .then(incoming => {
                      if (incoming.length < 50) { this.get("model").set("allLoaded", true); }
                      this.get("model").addObjects(incoming);
                   });
  }
});
