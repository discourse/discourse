import { lookup } from "discourse/lib/service";
import { withPluginApi } from "discourse/lib/core-api";
import { decorateHashtags } from "discourse/lib/hashtag-decorator";
import SiteService from "discourse/services/site";

export default {
  after: "hashtag-css-generator",

  initialize(owner) {
    const site = lookup(owner, SiteService);

    withPluginApi((api) => {
      api.decorateCookedElement((post) => decorateHashtags(post, site));
    });
  },
};
