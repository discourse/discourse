import Controller from "@ember/controller";
import { inject as service } from "@ember/service";

export default Controller.extend({
  selectedRoute: "adminBadges.show",
  router: service(),

  actions: {
    showBadge() {
      this.set("selectedRoute", "adminBadges.show");
    },

    massAward() {
      this.set("selectedRoute", "adminBadges.award");
    }
  }
});
