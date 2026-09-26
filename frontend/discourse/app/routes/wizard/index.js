import { service } from "discourse/lib/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class WizardIndexRoute extends DiscourseRoute {
  @service router;

  beforeModel() {
    const wizard = this.modelFor("wizard");
    this.router.replaceWith("wizard.step", wizard.start);
  }
}
