import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  queryParams: {
    q: { replace: true },
  },

  redirect() {
    this.transitionTo("userActivity.bookmarks");
  },
});
