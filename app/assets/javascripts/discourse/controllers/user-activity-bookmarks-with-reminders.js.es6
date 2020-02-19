import Controller from "@ember/controller";
import { inject } from "@ember/controller";

export default Controller.extend({
  application: inject(),
  user: inject(),

  actions: {
    removeBookmark(bookmark) {
      return bookmark.destroy().then(() => this.model.loadItems());
    }
  }
});
