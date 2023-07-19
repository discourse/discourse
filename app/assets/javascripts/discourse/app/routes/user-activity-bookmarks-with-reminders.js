import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default DiscourseRoute.extend({
  router: service(),

  queryParams: {
    q: { replace: true },
  },

  redirect() {
    this.router.transitionTo("userActivity.bookmarks");
  },
});
