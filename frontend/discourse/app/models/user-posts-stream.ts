import { tracked } from "@glimmer/tracking";
import EmberObject, { computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import type User from "discourse/models/user";
import UserAction, {
  type UserActionFields,
} from "discourse/models/user-action";

export interface UserPostsStreamFields {
  user?: User;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface UserPostsStream extends UserPostsStreamFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class UserPostsStream extends EmberObject {
  @tracked canLoadMore = true;
  @tracked filter: "deleted" | "pending" | undefined;
  @tracked itemsLoaded = 0;
  @tracked lastLoadedUrl: string | null | undefined;
  @tracked loaded = false;
  @tracked loading = false;
  @autoTrackedArray content: UserAction[] = [];

  @computed("user.username_lower", "filter", "itemsLoaded")
  get url(): string {
    return getURL(
      `/posts/${this.user?.username_lower}/${this.filter}?offset=${this.itemsLoaded}`
    );
  }

  async filterBy(opts: { filter: "deleted" | "pending" }): Promise<void> {
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

  async findItems(): Promise<void> {
    if (this.loading || !this.canLoadMore) {
      return;
    }

    this.loading = true;

    try {
      // TODO(typescript-pending): ajax lacks response types; remove the cast when this endpoint can be typed by ajax.
      const result = (await ajax(this.url)) as
        | (UserActionFields & Record<string, unknown>)[]
        | null
        | undefined;
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
