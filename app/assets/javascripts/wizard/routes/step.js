import Route from "@ember/routing/route";
export default Route.extend({
  model(params) {
    const allSteps = this.modelFor("application").steps;
    const step = allSteps.findBy("id", params.step_id);
    return step ? step : allSteps[0];
  },

  setupController(controller, step) {
    this.controllerFor("application").set("currentStepId", step.get("id"));

    controller.setProperties({
      step,
      wizard: this.modelFor("application")
    });
  }
});
