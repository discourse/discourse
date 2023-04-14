import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  model(params) {
    const allSteps = this.modelFor("wizard").steps;
    const step = allSteps.findBy("id", params.step_id);

    return step || allSteps[0];
  },

  setupController(controller, step) {
    const wizard = this.modelFor("wizard");
    this.controllerFor("wizard").set("currentStepId", step.id);

    controller.setProperties({ step, wizard });
  },
});
