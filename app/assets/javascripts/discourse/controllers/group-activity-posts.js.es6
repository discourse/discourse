import { observes } from "ember-addons/ember-computed-decorators";
import { fmt } from "discourse/lib/computed";

export default Ember.Controller.extend({
  group: Ember.inject.controller(),
  groupActivity: Ember.inject.controller(),
  application: Ember.inject.controller(),
  canLoadMore: true,
  loading: false,
  emptyText: fmt("type", "groups.empty.%@"),

  actions: {
    loadMore() {
      if (!this.get("canLoadMore")) {
        return;
      }
      if (this.get("loading")) {
        return;
      }
      this.set("loading", true);
      const posts = this.get("model");
      if (posts && posts.length) {
        const beforePostId = posts[posts.length - 1].get("id");
        const group = this.get("group.model");

        let categoryId = this.get("groupActivity.category_id");
        const opts = { beforePostId, type: this.get("type"), categoryId };

        group
          .findPosts(opts)
          .then(newPosts => {
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
  },

  @observes("canLoadMore")
  _showFooter() {
    this.set("application.showFooter", !this.get("canLoadMore"));
  }
});
