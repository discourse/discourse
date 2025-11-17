import { tracked } from "@glimmer/tracking";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { ajax } from "discourse/lib/ajax";
import { removeValueFromArray } from "discourse/lib/array-tools";
import { url } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import { trackedArray } from "discourse/lib/tracked-tools";
import RestModel from "discourse/models/rest";
import Site from "discourse/models/site";
import UserAction from "discourse/models/user-action";

export default class UserStream extends RestModel {
  @tracked actingUsername;
  @tracked lastLoadedUrl;
  @tracked loaded = false;
  @tracked loading = false;
  @tracked itemsLoaded = 0;
  @trackedArray content = [];

  @url(
    "itemsLoaded",
    "user.username_lower",
    "/user_actions.json?offset=%@&username=%@"
  )
  baseUrl;

  @discourseComputed("filter")
  filterParam(filter) {
    if (filter === UserAction.TYPES.replies) {
      return [UserAction.TYPES.replies, UserAction.TYPES.quotes].join(",");
    }

    if (!filter) {
      return [UserAction.TYPES.topics, UserAction.TYPES.posts].join(",");
    }

    return filter;
  }

  async filterBy(opts) {
    this.setProperties({
      itemsLoaded: 0,
      content: [],
      lastLoadedUrl: null,
      ...opts,
    });

    return this.findItems();
  }

  @discourseComputed("baseUrl", "filterParam", "actingUsername")
  nextFindUrl() {
    let findUrl = this.baseUrl;
    if (this.filterParam) {
      findUrl += `&filter=${this.filterParam}`;
    }

    if (this.actingUsername) {
      findUrl += `&acting_username=${this.actingUsername}`;
    }

    return findUrl;
  }

  @discourseComputed("loaded", "content.[]")
  noContent(loaded, content) {
    return loaded && content.length === 0;
  }

  @discourseComputed("nextFindUrl", "lastLoadedUrl")
  canLoadMore() {
    return this.nextFindUrl !== this.lastLoadedUrl;
  }

  remove(userAction) {
    // 1) remove the user action from the child groups
    this.content.forEach((ua) => {
      ["likes", "stars", "edits", "bookmarks"].forEach((group) => {
        const items = ua.get(`childGroups.${group}.items`);
        if (items) {
          removeValueFromArray(items, userAction);
        }
      });
    });

    // 2) remove the parents that have no children
    const content = this.content.filter((ua) => {
      return ["likes", "stars", "edits", "bookmarks"].some((group) => {
        return ua.get(`childGroups.${group}.items.length`) > 0;
      });
    });

    this.setProperties({ content, itemsLoaded: content.length });
  }

  async findItems() {
    if (this.loading || !this.canLoadMore) {
      // Don't load the same stream twice. We're probably at the end.
      return;
    }

    const findUrl = this.nextFindUrl;

    this.loading = true;
    try {
      const result = await ajax(findUrl);
      if (result && result.user_actions) {
        const copy = [];

        result.categories?.forEach((category) => {
          Site.current().updateCategory(category);
        });

        result.user_actions?.forEach((action) => {
          action.titleHtml = replaceEmoji(action.title);
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
