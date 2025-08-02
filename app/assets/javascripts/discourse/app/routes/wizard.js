import Route from "@ember/routing/route";
import Wizard from "discourse/static/wizard/models/wizard";

export default class WizardRoute extends Route {
  model() {
    return Wizard.load();
  }

  activate() {
    super.activate(...arguments);

    document.body.classList.add("wizard");

    this.controllerFor("application").setProperties({
      showTop: false,
      showSiteHeader: false,
      showSkipToContent: false,
    });
  }

  deactivate() {
    super.deactivate(...arguments);

    document.body.classList.remove("wizard");

    this.controllerFor("application").setProperties({
      showTop: true,
      showSiteHeader: true,
      showSkipToContent: true,
    });
  }
}
