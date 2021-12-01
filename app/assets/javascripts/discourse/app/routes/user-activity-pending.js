import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  beforeModel() {
    this.username = this.modelFor("user").username_lower;
  },

  model() {
    return this.store.findAll("pending-post", {
      username: this.username,
    });
  },

  activate() {
    this.appEvents.on(
      `count-updated:${this.username}:pending_posts_count`,
      this,
      "_handleCountChange"
    );
  },

  deactivate() {
    this.appEvents.off(
      `count-updated:${this.username}:pending_posts_count`,
      this,
      "_handleCountChange"
    );
  },

  _handleCountChange(count) {
    this.refresh();
    if (count <= 0) {
      this.transitionTo("userActivity");
    }
  },
});
