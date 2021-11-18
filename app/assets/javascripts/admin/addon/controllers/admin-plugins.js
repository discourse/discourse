import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend({
  @discourseComputed
  adminRoutes() {
    return this.model
      .map((p) => {
        if (p.get("enabled")) {
          return p.admin_route;
        }
      })
      .compact();
  },

  actions: {
    clearFilter() {
      this.setProperties({ filter: "", onlyOverridden: false });
    },

    toggleMenu() {
      $(".admin-detail").toggleClass("mobile-closed mobile-open");
    },
  },
});
