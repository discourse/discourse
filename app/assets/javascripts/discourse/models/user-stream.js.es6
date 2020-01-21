import { ajax } from "discourse/lib/ajax";
import { url } from "discourse/lib/computed";
import RestModel from "discourse/models/rest";
import UserAction from "discourse/models/user-action";
import { emojiUnescape } from "discourse/lib/text";
import { Promise } from "rsvp";
import discourseComputed, { on } from "discourse-common/utils/decorators";

export default RestModel.extend({
  loaded: false,

  @on("init")
  _initialize() {
    this.setProperties({ itemsLoaded: 0, content: [] });
  },

  @discourseComputed("filter")
  filterParam(filter) {
    if (filter === UserAction.TYPES.replies) {
      return [UserAction.TYPES.replies, UserAction.TYPES.quotes].join(",");
    }

    if (!filter) {
      return [UserAction.TYPES.topics, UserAction.TYPES.posts].join(",");
    }

    return filter;
  },

  baseUrl: url(
    "itemsLoaded",
    "user.username_lower",
    "/user_actions.json?offset=%@&username=%@"
  ),

  filterBy(opts) {
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

  @discourseComputed("loaded", "content.[]")
  noContent(loaded, content) {
    return loaded && content.length === 0;
  },

  remove(userAction) {
    // 1) remove the user action from the child groups
    this.content.forEach(ua => {
      ["likes", "stars", "edits", "bookmarks"].forEach(group => {
        const items = ua.get(`childGroups.${group}.items`);
        if (items) {
          items.removeObject(userAction);
        }
      });
    });

    // 2) remove the parents that have no children
    const content = this.content.filter(ua => {
      return ["likes", "stars", "edits", "bookmarks"].some(group => {
        return ua.get(`childGroups.${group}.items.length`) > 0;
      });
    });

    this.setProperties({ content, itemsLoaded: content.length });
  },

  findItems() {
    let findUrl = this.baseUrl;
    if (this.filterParam) {
      findUrl += `&filter=${this.filterParam}`;
    }
    if (this.noContentHelpKey) {
      findUrl += `&no_results_help_key=${this.noContentHelpKey}`;
    }

    if (this.actingUsername) {
      findUrl += `&acting_username=${this.actingUsername}`;
    }

    // Don't load the same stream twice. We're probably at the end.
    const lastLoadedUrl = this.lastLoadedUrl;
    if (lastLoadedUrl === findUrl) {
      return Promise.resolve();
    }

    if (this.loading) {
      return Promise.resolve();
    }

    this.set("loading", true);
    return ajax(findUrl, { cache: "false" })
      .then(result => {
        if (result && result.no_results_help) {
          this.set("noContentHelp", result.no_results_help);
        }
        if (result && result.user_actions) {
          const copy = Ember.A();
          result.user_actions.forEach(action => {
            action.title = emojiUnescape(
              Handlebars.Utils.escapeExpression(action.title)
            );
            copy.pushObject(UserAction.create(action));
          });

          this.content.pushObjects(UserAction.collapseStream(copy));
          this.setProperties({
            itemsLoaded: this.itemsLoaded + result.user_actions.length
          });
        }
      })
      .finally(() =>
        this.setProperties({
          loaded: true,
          loading: false,
          lastLoadedUrl: findUrl
        })
      );
  }
});
