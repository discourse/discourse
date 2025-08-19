import { decorateHashtags } from "discourse/lib/hashtag-decorator";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  after: "hashtag-css-generator",

  initialize(owner) {
    const site = owner.lookup("service:site");

    withPluginApi((api) => {
      api.decorateCookedElement((post) => decorateHashtags(post, site));
    });
  },
};
