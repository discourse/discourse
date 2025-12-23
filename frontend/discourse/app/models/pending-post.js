import { computed } from "@ember/object";
import { reads } from "@ember/object/computed";
import { cook } from "discourse/lib/text";
import { userPath } from "discourse/lib/url";
import RestModel from "discourse/models/rest";
import Category from "./category";

export default class PendingPost extends RestModel {
  expandedExcerpt = null;

  @reads("topic_url") postUrl;

  truncated = false;

  init() {
    super.init(...arguments);
    cook(this.raw_text).then((cooked) => {
      this.set("expandedExcerpt", cooked);
    });
  }

  @computed("username")
  get userUrl() {
    return userPath(this.username.toLowerCase());
  }

  @computed("category_id")
  get category() {
    return Category.findById(this.category_id);
  }
}
