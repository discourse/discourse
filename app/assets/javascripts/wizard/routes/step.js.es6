export default Ember.Route.extend({
  model(params) {
    return {
      id: params.step_id,
      title: "You're a wizard harry!"
    };
  },

  setupController(controller, model) {
    controller.set('step', model);
  }
});
