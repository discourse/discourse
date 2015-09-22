export default Discourse.Route.extend({
  model(params) {
    return this.store.find('site-text', params.text_type);
  }
});
