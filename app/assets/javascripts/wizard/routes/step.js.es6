export default Ember.Route.extend({
  model(params) {
    const allSteps = this.modelFor('application').steps;
    const step = allSteps.findProperty('id', params.step_id);
    return step ? step : allSteps[0];
  },

  setupController(controller, step) {
    controller.setProperties({
      step, wizard: this.modelFor('application')
    });
  }
});
