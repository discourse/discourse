import Controller from "@ember/controller";
import { action } from "@ember/object";

export default Controller.extend({
  sortProperties: ["count:desc", "id"],
  tagsForUser: null,
  sortedByCount: true,
  sortedByName: false,

  @action
  sortByCount(event) {
    event?.preventDefault();
    this.setProperties({
      sortProperties: ["count:desc", "id"],
      sortedByCount: true,
      sortedByName: false,
    });
  },

  @action
  sortById(event) {
    event?.preventDefault();
    this.setProperties({
      sortProperties: ["id"],
      sortedByCount: false,
      sortedByName: true,
    });
  },
});
