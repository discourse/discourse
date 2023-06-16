import { withPluginApi } from "discourse/lib/plugin-api";
import CategoryHashtagType from "discourse/lib/hashtag-types/category";
import TagHashtagType from "discourse/lib/hashtag-types/tag";

export default {
  before: "hashtag-css-generator",

  initialize(owner) {
    withPluginApi("0.8.7", (api) => {
      api.registerHashtagType("category", new CategoryHashtagType(owner));
      api.registerHashtagType("tag", new TagHashtagType(owner));
    });
  },
};
