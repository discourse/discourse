import DiscourseRoute from "discourse/routes/discourse";

export default class WizardStepRoute extends DiscourseRoute {
  model(params) {
    const wizard = this.modelFor("wizard");
    const step = wizard.findStep(params.step_id);
    // should the latter be a redirect?
    return step || wizard.steps[0];
  }

  setupController(controller, step) {
    const wizard = this.modelFor("wizard");
    this.controllerFor("wizard").set("currentStepId", step.id);

    controller.setProperties({ step, wizard });
  }
}
