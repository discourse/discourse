export default Discourse.Route.extend({
  showFooter: true,

  model(params) {
    return this.store.find("tagGroup", params.id);
  }
});
