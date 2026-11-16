import { tracked } from "@glimmer/tracking";
import { computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { removeValueFromArray } from "discourse/lib/array-tools";
import getURL from "discourse/lib/get-url";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import type { CategoryFields } from "discourse/models/category";
import RestModel from "discourse/models/rest";
import Site from "discourse/models/site";
import type User from "discourse/models/user";
import UserAction, {
  type UserActionFields,
} from "discourse/models/user-action";

export interface UserStreamFilter {
  filter?: number | null;
  actingUsername?: string | null;
}

export interface UserStreamFields {
  user?: User;
  filter?: number | null;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface UserStream extends UserStreamFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class UserStream extends RestModel {
  @tracked actingUsername: string | null | undefined;
  @tracked lastLoadedUrl: string | null | undefined;
  @tracked loaded = false;
  @tracked loading = false;
  @tracked itemsLoaded = 0;
  @autoTrackedArray content: UserAction[] = [];

  @computed("itemsLoaded", "user.username_lower")
  get baseUrl(): string {
    return getURL(
      `/user_actions.json?offset=${this.itemsLoaded}&username=${this.user?.username_lower}`
    );
  }

  @computed("filter")
  get filterParam() {
    if (this.filter === UserAction.TYPES.replies) {
      return [UserAction.TYPES.replies, UserAction.TYPES.quotes].join(",");
    }

    if (!this.filter) {
      return [UserAction.TYPES.topics, UserAction.TYPES.posts].join(",");
    }

    return this.filter;
  }

  @computed("baseUrl", "filterParam", "actingUsername")
  get nextFindUrl(): string {
    let findUrl = this.baseUrl;
    if (this.filterParam) {
      findUrl += `&filter=${this.filterParam}`;
    }

    if (this.actingUsername) {
      findUrl += `&acting_username=${this.actingUsername}`;
    }

    return findUrl;
  }

  @computed("loaded", "content.[]")
  get noContent() {
    return this.loaded && this.content?.length === 0;
  }

  @computed("nextFindUrl", "lastLoadedUrl")
  get canLoadMore() {
    return this.nextFindUrl !== this.lastLoadedUrl;
  }

  async filterBy(opts: UserStreamFilter): Promise<void> {
    this.setProperties({
      itemsLoaded: 0,
      content: [],
      lastLoadedUrl: null,
      ...opts,
    });

    return this.findItems();
  }

  remove(userAction: UserAction): void {
    // 1) remove the user action from the child groups
    this.content.forEach((ua) => {
      ["likes", "stars", "edits", "bookmarks"].forEach((group) => {
        const items = ua.get(`childGroups.${group}.items`) as
          | UserAction[]
          | undefined;
        if (items) {
          removeValueFromArray(items, userAction);
        }
      });
    });

    // 2) remove the parents that have no children
    const content = this.content.filter((ua) => {
      return ["likes", "stars", "edits", "bookmarks"].some((group) => {
        // Missing child groups compare as undefined > 0, which excludes them.
        return (ua.get(`childGroups.${group}.items.length`) as number) > 0;
      });
    });

    this.setProperties({ content, itemsLoaded: content.length });
  }

  async findItems(): Promise<void> {
    if (this.loading || !this.canLoadMore) {
      // Don't load the same stream twice. We're probably at the end.
      return;
    }

    const findUrl = this.nextFindUrl;

    this.loading = true;
    try {
      const result = await ajax<
        | {
            user_actions?: (UserActionFields & Record<string, unknown>)[];
            categories?: CategoryFields[];
          }
        | null
        | undefined
      >(findUrl);
      if (result && result.user_actions) {
        const copy: UserAction[] = [];

        result.categories?.forEach((category) => {
          Site.current().updateCategory(category);
        });

        result.user_actions?.forEach((action) => {
          copy.push(UserAction.create(action));
        });

        this.content.push(...UserAction.collapseStream(copy));
        this.setProperties({
          itemsLoaded: this.itemsLoaded + result.user_actions.length,
        });
      }
    } finally {
      this.setProperties({
        loaded: true,
        loading: false,
        lastLoadedUrl: findUrl,
      });
    }
  }
}
