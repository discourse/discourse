import { withPluginApi } from "discourse/lib/core-api";
import CategoryHashtagType from "discourse/lib/hashtag-types/category";
import TagHashtagType from "discourse/lib/hashtag-types/tag";

export default {
  before: "hashtag-css-generator",

  initialize(owner) {
    withPluginApi((api) => {
      api.registerHashtagType("category", new CategoryHashtagType(owner));
      api.registerHashtagType("tag", new TagHashtagType(owner));
    });
  },
};
