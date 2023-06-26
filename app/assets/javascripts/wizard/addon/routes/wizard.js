import Route from "@ember/routing/route";
import { findWizard } from "wizard/models/wizard";
import DisableSidebar from "discourse/mixins/disable-sidebar";

export default Route.extend(DisableSidebar, {
  model() {
    return findWizard();
  },

  activate() {
    this._super(...arguments);

    document.body.classList.add("wizard");

    this.controllerFor("application").setProperties({
      showTop: false,
      showFooter: false,
      showSiteHeader: false,
    });
  },

  deactivate() {
    this._super(...arguments);

    document.body.classList.remove("wizard");

    this.controllerFor("application").setProperties({
      showTop: true,
      showSiteHeader: true,
    });
  },
});
