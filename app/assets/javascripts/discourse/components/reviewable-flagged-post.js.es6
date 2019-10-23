import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";
import { longDate } from "discourse/lib/formatter";
import { historyHeat } from "discourse/widgets/post-edits-indicator";
import showModal from "discourse/lib/show-modal";

export default Component.extend({
  hasEdits: Ember.computed.gt("reviewable.post_version", 1),

  @computed("reviewable.post_updated_at")
  historyClass(updatedAt) {
    return historyHeat(this.siteSettings, new Date(updatedAt));
  },

  @computed("reviewable.post_updated_at")
  editedDate(updatedAt) {
    return longDate(updatedAt);
  },

  actions: {
    showEditHistory() {
      let postId = this.get("reviewable.post_id");
      this.store.find("post", postId).then(post => {
        let historyController = showModal("history", {
          model: post,
          modalClass: "history-modal"
        });
        historyController.refresh(postId, "latest");
        historyController.set("post", post);
        historyController.set("topicController", null);
      });
    }
  }
});
