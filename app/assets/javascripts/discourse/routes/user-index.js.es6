import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  beforeModel() {
    const { currentUser } = this;
    const viewingMe =
      currentUser &&
      currentUser.get("username") === this.modelFor("user").get("username");
    const destination = viewingMe ? "userActivity" : "user.summary";

    // HACK: Something with the way the user card intercepts clicks seems to break how the
    // transition into a user's activity works. This makes the back button work on mobile
    // where there is no user card as well as desktop where there is.
    if (this.site.mobileView) {
      this.replaceWith(destination);
    } else {
      this.transitionTo(destination);
    }
  }
});
