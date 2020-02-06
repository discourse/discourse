import { none } from "@ember/object/computed";
import { computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { Promise } from "rsvp";
import RestModel from "discourse/models/rest";

const Bookmark = RestModel.extend({
  newBookmark: none("id"),

  @computed
  get url() {
    return Discourse.getURL(`/bookmarks/${this.id}`);
  },

  destroy() {
    if (this.newBookmark) return Promise.resolve();

    return ajax(this.url, {
      type: "DELETE"
    });
  }
});

export default Bookmark;
