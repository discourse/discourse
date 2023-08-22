import Mixin from "@ember/object/mixin";

export default Mixin.create({
  activate() {
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
