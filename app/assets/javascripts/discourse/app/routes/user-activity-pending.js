import DiscourseRoute from "discourse/routes/discourse";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { inject as service } from "@ember/service";

export default DiscourseRoute.extend({
  router: service(),

  beforeModel() {
    this.username = this.modelFor("user").username_lower;
  },

  model() {
    return this.store
      .findAll("pending-post", {
        username: this.username,
      })
      .then((pendingPosts) => {
        for (let pendingPost of pendingPosts.content) {
          pendingPost.title = emojiUnescape(
            escapeExpression(pendingPost.title)
          );
        }

        return pendingPosts;
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
      this.router.transitionTo("userActivity");
    }
  },
});
