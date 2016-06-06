export default Discourse.Route.extend({
  model(params) {
    return this.store.find('tagGroup', params.id);
  }
});
