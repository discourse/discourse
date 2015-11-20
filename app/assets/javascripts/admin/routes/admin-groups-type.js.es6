export default Discourse.Route.extend({
  model(params) {
    this.set("type", params.type);
    return Discourse.Group.findAll().then(function(groups) {
      return groups.filterBy("type", params.type);
    });
  },

  setupController(controller, model){
    controller.set("type", this.get("type"));
    controller.set("model", model);
  }
});
