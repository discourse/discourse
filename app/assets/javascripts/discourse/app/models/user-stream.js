import { A } from "@ember/array";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { url } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import RestModel from "discourse/models/rest";
import Site from "discourse/models/site";
import UserAction from "discourse/models/user-action";

export default class UserStream extends RestModel {
  loaded = false;
  itemsLoaded = 0;
  content = [];

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

  filterBy(opts) {
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
          items.removeObject(userAction);
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

  findItems() {
    if (!this.canLoadMore) {
      // Don't load the same stream twice. We're probably at the end.
      return Promise.resolve();
    }

    const findUrl = this.nextFindUrl;

    if (this.loading) {
      return Promise.resolve();
    }

    this.set("loading", true);
    return ajax(findUrl)
      .then((result) => {
        if (result && result.user_actions) {
          const copy = A();

          result.categories?.forEach((category) => {
            Site.current().updateCategory(category);
          });

          result.user_actions.forEach((action) => {
            action.title = emojiUnescape(escapeExpression(action.title));
            copy.pushObject(UserAction.create(action));
          });

          this.content.pushObjects(UserAction.collapseStream(copy));
          this.setProperties({
            itemsLoaded: this.itemsLoaded + result.user_actions.length,
          });
        }
      })
      .finally(() =>
        this.setProperties({
          loaded: true,
          loading: false,
          lastLoadedUrl: findUrl,
        })
      );
  }
}
