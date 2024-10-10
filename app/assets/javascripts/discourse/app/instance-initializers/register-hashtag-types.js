import CategoryHashtagType from "discourse/lib/hashtag-types/category";
import TagHashtagType from "discourse/lib/hashtag-types/tag";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  initialize(owner) {
    withPluginApi("0.8.7", (api) => {
      api.registerHashtagType("category", new CategoryHashtagType(owner));
      api.registerHashtagType("tag", new TagHashtagType(owner));
    });
  },
};
