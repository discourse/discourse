export default Discourse.Route.extend({
  model() {
    return this.modelFor("user").summary();
  }
});
