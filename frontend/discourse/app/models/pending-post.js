import { tracked } from "@glimmer/tracking";
import { computed } from "@ember/object";
import { cook } from "discourse/lib/text";
import { userPath } from "discourse/lib/url";
import RestModel from "discourse/models/rest";
import Category from "./category";

export default class PendingPost extends RestModel {
  expandedExcerpt = null;

  truncated = false;

  @tracked _postUrlOverride;

  init() {
    super.init(...arguments);
    cook(this.raw_text).then((cooked) => {
      this.set("expandedExcerpt", cooked);
    });
  }

  @computed("topic_url")
  get postUrl() {
    if (this._postUrlOverride !== undefined) {
      return this._postUrlOverride;
    }
    return this.topic_url;
  }

  set postUrl(value) {
    this._postUrlOverride = value;
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
