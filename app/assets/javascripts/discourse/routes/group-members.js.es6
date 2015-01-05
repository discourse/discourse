import ShowFooter from "discourse/mixins/show-footer";

export default Discourse.Route.extend(ShowFooter, {
  model: function() {
    return this.modelFor('group');
  },

  setupController: function(controller, model) {
    this.controllerFor('group').set('showing', 'members');
    controller.set("model", model);
    model.findMembers();
  }

});
