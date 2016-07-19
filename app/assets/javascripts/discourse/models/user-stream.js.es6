import { ajax } from 'discourse/lib/ajax';
import { url } from 'discourse/lib/computed';
import RestModel from 'discourse/models/rest';
import UserAction from 'discourse/models/user-action';
import { emojiUnescape } from 'discourse/lib/text';

export default RestModel.extend({
  loaded: false,

  _initialize: function() {
    this.setProperties({ itemsLoaded: 0, content: [] });
  }.on("init"),

  filterParam: function() {
    const filter = this.get('filter');
    if (filter === Discourse.UserAction.TYPES.replies) {
      return [UserAction.TYPES.replies,
              UserAction.TYPES.quotes].join(",");
    }

    if(!filter) {
      return [UserAction.TYPES.topics,
              UserAction.TYPES.posts].join(",");
    }

    return filter;
  }.property('filter'),

  baseUrl: url('itemsLoaded', 'user.username_lower', '/user_actions.json?offset=%@&username=%@'),

  filterBy(filter) {
    this.setProperties({ filter, itemsLoaded: 0, content: [], lastLoadedUrl: null });
    return this.findItems();
  },

  remove(userAction) {
    // 1) remove the user action from the child groups
    this.get("content").forEach(function (ua) {
      ["likes", "stars", "edits", "bookmarks"].forEach(function (group) {
        const items = ua.get("childGroups." + group + ".items");
        if (items) {
          items.removeObject(userAction);
        }
      });
    });

    // 2) remove the parents that have no children
    const content = this.get("content").filter(function (ua) {
      return ["likes", "stars", "edits", "bookmarks"].any(function (group) {
        return ua.get("childGroups." + group + ".items.length") > 0;
      });
    });

    this.setProperties({ content, itemsLoaded: content.length });
  },

  findItems() {
    const self = this;

    let findUrl = this.get('baseUrl');
    if (this.get('filterParam')) {
      findUrl += "&filter=" + this.get('filterParam');
    }

    // Don't load the same stream twice. We're probably at the end.
    const lastLoadedUrl = this.get('lastLoadedUrl');
    if (lastLoadedUrl === findUrl) { return Ember.RSVP.resolve(); }

    if (this.get('loading')) { return Ember.RSVP.resolve(); }
    this.set('loading', true);
    return ajax(findUrl, {cache: 'false'}).then( function(result) {
      if (result && result.user_actions) {
        const copy = Em.A();
        result.user_actions.forEach(function(action) {
          action.title = emojiUnescape(Handlebars.Utils.escapeExpression(action.title));
          copy.pushObject(UserAction.create(action));
        });

        self.get('content').pushObjects(UserAction.collapseStream(copy));
        self.setProperties({
          loaded: true,
          itemsLoaded: self.get('itemsLoaded') + result.user_actions.length
        });
      }
    }).finally(function() {
      self.set('loading', false);
      self.set('lastLoadedUrl', findUrl);
    });
  }

});
