import { computed, get } from "@ember/object";
import { withPluginApi } from "discourse/lib/plugin-api";
import Category from "discourse/models/category";

function extendCategory(api) {
  Category.reopen({
    enable_topic_voting: computed("custom_fields.enable_topic_voting", {
      get() {
        return get(this.custom_fields, "enable_topic_voting") === true;
      },
    }),
  });
  api.addPostClassesCallback((post) => {
    if (post.post_number === 1 && post.can_vote) {
      return ["voting-post"];
    }
  });
  api.addTrackedPostProperties("can_vote");
  api.addModelField("topic", "vote_count");
  api.addModelField("topic", "user_voted");
  api.addModelField("user", "votes_exceeded");
  api.addModelField("user", "vote_limit");
  api.addModelField("user", "votes_left");
}

export default {
  name: "extend-category-for-voting",

  before: "inject-discourse-objects",

  initialize() {
    withPluginApi((api) => {
      extendCategory(api);
      api.addCategorySortCriteria("votes");
    });
  },
};
