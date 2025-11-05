import Route from "@ember/routing/route";
import { service } from "@ember/service";
import Wizard from "discourse/static/wizard/models/wizard";

export default class WizardRoute extends Route {
  @service a11y;

  model() {
    return Wizard.load();
  }

  activate() {
    super.activate(...arguments);

    document.body.classList.add("wizard");

    this.controllerFor("application").setProperties({
      showTop: false,
      showSiteHeader: false,
    });

    this.a11y.showSkipLinks = false;
  }

  deactivate() {
    super.deactivate(...arguments);

    document.body.classList.remove("wizard");

    this.controllerFor("application").setProperties({
      showTop: true,
      showSiteHeader: true,
    });

    this.a11y.showSkipLinks = true;
  }
}
