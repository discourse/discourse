import Route from "@ember/routing/route";
import DisableSidebar from "discourse/mixins/disable-sidebar";
import Wizard from "wizard/models/wizard";

export default Route.extend(DisableSidebar, {
  model() {
    return Wizard.load();
  },

  activate() {
    this._super(...arguments);

    document.body.classList.add("wizard");

    this.controllerFor("application").setProperties({
      showTop: false,
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
