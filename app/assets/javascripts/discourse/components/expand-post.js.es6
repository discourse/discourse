import Component from "@ember/component";
import { ajax } from "discourse/lib/ajax";

export default Component.extend({
  tagName: "",
  expanded: null,
  _loading: false,

  actions: {
    toggleItem() {
      if (this._loading) {
        return false;
      }
      const item = this.item;

      if (this.expanded) {
        this.set("expanded", false);
        item.set("expandedExcerpt", null);
        return;
      }

      const topicId = item.get("topic_id");
      const postNumber = item.get("post_number");

      this._loading = true;
      return ajax(`/posts/by_number/${topicId}/${postNumber}.json`)
        .then(result => {
          this.set("expanded", true);
          item.set("expandedExcerpt", result.cooked);
        })
        .finally(() => (this._loading = false));
    }
  }
});
