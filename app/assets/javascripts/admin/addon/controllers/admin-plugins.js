import { action } from "@ember/object";
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

  @action
  toggleMenu() {
    const adminDetail = document.querySelector(".admin-detail");
    ["mobile-closed", "mobile-open"].forEach((state) => {
      adminDetail.classList.toggle(state);
    });
  },
});
