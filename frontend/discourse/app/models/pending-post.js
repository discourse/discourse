import { tracked } from "@glimmer/tracking";
import { dependentKeyCompat } from "@ember/object/compat";
import discourseComputed from "discourse/lib/decorators";
import { cook } from "discourse/lib/text";
import { userPath } from "discourse/lib/url";
import RestModel from "discourse/models/rest";
import Category from "./category";

export default class PendingPost extends RestModel {
  @tracked topic_url;
  expandedExcerpt = null;
  truncated = false;

  init() {
    super.init(...arguments);
    cook(this.raw_text).then((cooked) => {
      this.set("expandedExcerpt", cooked);
    });
  }

  @dependentKeyCompat
  get postUrl() {
    return this.topic_url;
  }

  @discourseComputed("username")
  userUrl(username) {
    return userPath(username.toLowerCase());
  }

  @discourseComputed("category_id")
  category() {
    return Category.findById(this.category_id);
  }
}
