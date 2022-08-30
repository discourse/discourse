import Route from "@ember/routing/route";
import { findWizard } from "wizard/models/wizard";

export default Route.extend({
  model() {
    return findWizard();
  },

  activate() {
    document.body.classList.add("wizard");
    this.controllerFor("application").setProperties({
      showTop: false,
      showFooter: false,
    });
  },

  deactivate() {
    document.body.classList.remove("wizard");
    this.controllerFor("application").set("showTop", true);
  },
});
