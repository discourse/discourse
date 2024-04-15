import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

// A base route that allows us to redirect when access is restricted
export default DiscourseRoute.extend({
  router: service(),

  afterModel() {
    if (!this.modelFor("user").get("can_edit")) {
      this.router.replaceWith("userActivity");
    }
  },
});
