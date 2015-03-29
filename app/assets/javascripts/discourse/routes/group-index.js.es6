import ShowFooter from "discourse/mixins/show-footer";

export default Discourse.Route.extend(ShowFooter, {
  actions: {
    didTransition: function() {
      return true;
    }
  },

  model: function() {
    return this.modelFor('group').findPosts();
  },

  setupController: function(controller, model) {
    controller.set('model', model);
    this.controllerFor('group').set('showing', 'index');
  }
});
