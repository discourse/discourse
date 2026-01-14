import { service } from "@ember/service";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import DiscourseRoute from "discourse/routes/discourse";

export default class UserActivityPending extends DiscourseRoute {
  @service router;

  beforeModel() {
    this.username = this.modelFor("user").username_lower;
  }

  async model() {
    const pendingPosts = await this.store.findAll("pending-post", {
      username: this.username,
    });

    for (let pendingPost of pendingPosts.content) {
      pendingPost.title = emojiUnescape(escapeExpression(pendingPost.title));
    }

    return pendingPosts;
  }

  activate() {
    this.appEvents.on(
      `count-updated:${this.username}:pending_posts_count`,
      this,
      "_handleCountChange"
    );
  }

  deactivate() {
    this.appEvents.off(
      `count-updated:${this.username}:pending_posts_count`,
      this,
      "_handleCountChange"
    );
  }

  _handleCountChange(count) {
    this.refresh();
    if (count <= 0) {
      this.router.transitionTo("userActivity");
    }
  }
}
