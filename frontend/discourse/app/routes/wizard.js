import Route from "@ember/routing/route";
import { service } from "discourse/lib/service";
import Wizard from "discourse/static/wizard/models/wizard";
import A11yService from "discourse/services/a11y";
import KeyboardShortcutsService from "discourse/services/keyboard-shortcuts";

export default class WizardRoute extends Route {
  @service(() => A11yService) a11y;
  @service(() => KeyboardShortcutsService) keyboardShortcuts;

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
    this.keyboardShortcuts.pause();
  }

  deactivate() {
    super.deactivate(...arguments);

    document.body.classList.remove("wizard");

    this.controllerFor("application").setProperties({
      showTop: true,
      showSiteHeader: true,
    });

    this.a11y.showSkipLinks = true;
    this.keyboardShortcuts.unpause();
  }
}
