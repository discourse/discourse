import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class WizardStepRoute extends DiscourseRoute {
  @service router;

  model(params) {
    const wizard = this.modelFor("wizard");
    const step = wizard.findStep(params.step_id);

    if (!step) {
      this.router.transitionTo("wizard.step", wizard.start);
    }

    return { wizard, step };
  }
}
