import Mixin from "@ember/object/mixin";
import deprecated from "discourse-common/lib/deprecated";

export default Mixin.create({
  activate() {
    deprecated(
      "The DisableSidebar mixin is deprecated. Instead, please add the {{hide-application-sidebar}} helper to an Ember template.",
      { id: "discourse.hide-application-sidebar" }
    );

    this.controllerFor("application").setProperties({
      sidebarDisabledRouteOverride: true,
    });
  },

  deactivate() {
    this.controllerFor("application").setProperties({
      sidebarDisabledRouteOverride: false,
    });
  },
});
