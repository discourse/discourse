export default Discourse.Route.extend({
  model() {
    return this.modelFor("User").summary();
  }
});
