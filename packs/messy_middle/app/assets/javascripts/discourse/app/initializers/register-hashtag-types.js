import { withPluginApi } from "discourse/lib/plugin-api";
import CategoryHashtagType from "discourse/lib/hashtag-types/category";
import TagHashtagType from "discourse/lib/hashtag-types/tag";

export default {
  name: "register-hashtag-types",
  before: "hashtag-css-generator",

  initialize() {
    withPluginApi("0.8.7", (api) => {
      api.registerHashtagType("category", CategoryHashtagType);
      api.registerHashtagType("tag", TagHashtagType);
    });
  },
};
