import EmberObject from "@ember/object";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { url } from "discourse/lib/computed";
import UserAction from "discourse/models/user-action";
import { on } from "discourse-common/utils/decorators";

export default class UserPostsStream extends EmberObject {
  loaded = false;

  @url("user.username_lower", "filter", "itemsLoaded", "/posts/%@/%@?offset=%@")
  url;

  @on("init")
  _initialize() {
    this.setProperties({
      itemsLoaded: 0,
      canLoadMore: true,
      content: [],
    });
  }

  filterBy(opts) {
    if (this.loaded && this.filter === opts.filter) {
      return Promise.resolve();
    }

    this.setProperties(
      Object.assign(
        {
          itemsLoaded: 0,
          content: [],
          lastLoadedUrl: null,
        },
        opts
      )
    );

    return this.findItems();
  }

  findItems() {
    if (this.loading || !this.canLoadMore) {
      return Promise.reject();
    }

    this.set("loading", true);

    return ajax(this.url)
      .then((result) => {
        if (result) {
          const posts = result.map((post) => UserAction.create(post));
          this.content.pushObjects(posts);
          this.setProperties({
            loaded: true,
            itemsLoaded: this.itemsLoaded + posts.length,
            canLoadMore: posts.length > 0,
          });
        }
      })
      .finally(() => this.set("loading", false));
  }
}
