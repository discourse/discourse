import ShowFooter from "discourse/mixins/show-footer";

export default Discourse.Route.extend(ShowFooter, {
  model() {
    return this.modelFor('group');
  },

  setupController(controller, model) {
    this.controllerFor('group').set('showing', 'members');
    controller.set("model", model);
    model.findMembers();
  }

});
