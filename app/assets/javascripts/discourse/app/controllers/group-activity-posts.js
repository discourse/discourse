import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { fmt } from "discourse/lib/computed";

export default class GroupActivityPostsController extends Controller {
  @controller group;
  @controller groupActivity;
  @controller application;

  @fmt("type", "groups.empty.%@") emptyText;

  canLoadMore = true;
  loading = false;

  @action
  loadMore() {
    if (!this.canLoadMore) {
      return;
    }
    if (this.loading) {
      return;
    }
    this.set("loading", true);
    const posts = this.model;
    if (posts && posts.length) {
      const before = posts[posts.length - 1].get("created_at");
      const group = this.get("group.model");

      let categoryId = this.get("groupActivity.category_id");
      const opts = { before, type: this.type, categoryId };

      group
        .findPosts(opts)
        .then((newPosts) => {
          posts.addObjects(newPosts);
          if (newPosts.length === 0) {
            this.set("canLoadMore", false);
          }
        })
        .finally(() => {
          this.set("loading", false);
        });
    }
  }
}
