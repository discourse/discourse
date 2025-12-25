import { tracked } from "@glimmer/tracking";
import EmberObject from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import { trackedArray } from "discourse/lib/tracked-tools";
import UserAction from "discourse/models/user-action";

export default class UserPostsStream extends EmberObject {
  @tracked canLoadMore = true;
  @tracked filter;
  @tracked itemsLoaded = 0;
  @tracked lastLoadedUrl;
  @tracked loaded = false;
  @tracked loading = false;
  @tracked user;
  @trackedArray content = [];

  @dependentKeyCompat
  get url() {
    return getURL(
      `/posts/${this.user?.username_lower}/${this.filter}?offset=${this.itemsLoaded}`
    );
  }

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
