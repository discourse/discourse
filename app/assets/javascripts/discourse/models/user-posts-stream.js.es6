import { on } from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import { url } from "discourse/lib/computed";
import UserAction from "discourse/models/user-action";
import { Promise } from "rsvp";
import EmberObject from "@ember/object";

export default EmberObject.extend({
  loaded: false,

  @on("init")
  _initialize() {
    this.setProperties({
      itemsLoaded: 0,
      canLoadMore: true,
      content: []
    });
  },

  url: url(
    "user.username_lower",
    "filter",
    "itemsLoaded",
    "/posts/%@/%@?offset=%@"
  ),

  filterBy(opts) {
    if (this.loaded && this.filter === opts.filter) {
      return Promise.resolve();
    }

    this.setProperties(
      Object.assign(
        {
          itemsLoaded: 0,
          content: [],
          lastLoadedUrl: null
        },
        opts
      )
    );

    return this.findItems();
  },

  findItems() {
    if (this.loading || !this.canLoadMore) {
      return Promise.reject();
    }

    this.set("loading", true);

    return ajax(this.url, { cache: false })
      .then(result => {
        if (result) {
          const posts = result.map(post => UserAction.create(post));
          this.content.pushObjects(posts);
          this.setProperties({
            loaded: true,
            itemsLoaded: this.itemsLoaded + posts.length,
            canLoadMore: posts.length > 0
          });
        }
      })
      .finally(() => this.set("loading", false));
  }
});
