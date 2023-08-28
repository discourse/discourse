import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default DiscourseRoute.extend({
  router: service(),
  site: service(),
  currentUser: service(),

  beforeModel() {
    const viewingMe =
      this.currentUser?.get("username") ===
      this.modelFor("user").get("username");
    const destination = viewingMe ? "userActivity" : "user.summary";

    // HACK: Something with the way the user card intercepts clicks seems to break how the
    // transition into a user's activity works. This makes the back button work on mobile
    // where there is no user card as well as desktop where there is.
    if (this.site.mobileView) {
      this.router.replaceWith(destination);
    } else {
      this.router.transitionTo(destination);
    }
  },
});
