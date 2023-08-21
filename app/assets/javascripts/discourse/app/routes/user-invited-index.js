import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default DiscourseRoute.extend({
  router: service(),

  beforeModel() {
    this.router.replaceWith("userInvited.show", "pending");
  },
});
