import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  router: service(),

  queryParams: {
    q: { replace: true },
  },

  redirect() {
    this.router.transitionTo("userActivity.bookmarks");
  },
});
