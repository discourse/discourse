import DiscourseRoute from "discourse/routes/discourse";

export default class WizardStepRoute extends DiscourseRoute {
  model(params) {
    const wizard = this.modelFor("wizard");
    let step = wizard.findStep(params.step_id);

    // should this be a redirect?
    if (!step) {
      step = wizard.steps[0];
    }

    return { wizard, step };
  }
}
