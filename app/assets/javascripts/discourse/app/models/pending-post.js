import discourseComputed from "discourse-common/utils/decorators";
import RestModel from "discourse/models/rest";
import categoryFromId from "discourse-common/utils/category-macro";
import { userPath } from "discourse/lib/url";
import { reads } from "@ember/object/computed";
import { cookAsync } from "discourse/lib/text";

const PendingPost = RestModel.extend({
  expandedExcerpt: null,
  postUrl: reads("topic_url"),
  truncated: false,

  init() {
    this._super(...arguments);
    cookAsync(this.raw_text).then((cooked) => {
      this.set("expandedExcerpt", cooked);
    });
  },

  @discourseComputed("username")
  userUrl(username) {
    return userPath(username.toLowerCase());
  },

  category: categoryFromId("category_id"),
});

export default PendingPost;
