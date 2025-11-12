import { tracked } from "@glimmer/tracking";
import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { url } from "discourse/lib/computed";
import { trackedArray } from "discourse/lib/tracked-tools";
import UserAction from "discourse/models/user-action";

export default class UserPostsStream extends EmberObject {
  @tracked canLoadMore = true;
  @tracked filter;
  @tracked itemsLoaded = 0;
  @tracked lastLoadedUrl;
  @tracked loaded = false;
  @tracked loading = false;
  @trackedArray content = [];

  @url("user.username_lower", "filter", "itemsLoaded", "/posts/%@/%@?offset=%@")
  url;

  async filterBy(opts) {
    if (this.loaded && this.filter === opts.filter) {
      return;
    }

    this.setProperties({
      itemsLoaded: 0,
      content: [],
      lastLoadedUrl: null,
      ...opts,
    });

    return this.findItems();
  }

  async findItems() {
    if (this.loading || !this.canLoadMore) {
      return;
    }

    this.loading = true;

    try {
      const result = await ajax(this.url);
      if (result) {
        const posts = result.map((post) => UserAction.create(post));
        this.content.push(...posts);
        this.setProperties({
          loaded: true,
          itemsLoaded: this.itemsLoaded + posts.length,
          canLoadMore: posts.length > 0,
        });
      }
    } finally {
      this.loading = false;
    }
  }
}
