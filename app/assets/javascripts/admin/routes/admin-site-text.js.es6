export default Discourse.Route.extend({
  model() {
    return this.store.findAll('site-text-type');
  }
});
