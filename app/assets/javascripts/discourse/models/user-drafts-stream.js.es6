import { ajax } from "discourse/lib/ajax";
import { url } from "discourse/lib/computed";
import RestModel from "discourse/models/rest";
import UserDraft from "discourse/models/user-draft";
import { emojiUnescape } from "discourse/lib/text";

import {
  NEW_TOPIC_KEY,
  NEW_PRIVATE_MESSAGE_KEY
} from "discourse/models/composer";

export default RestModel.extend({
  loaded: false,

  _initialize: function() {
    this.setProperties({
      itemsLoaded: 0,
      content: [],
      lastLoadedUrl: null
    });
  }.on("init"),

  baseUrl: url(
    "itemsLoaded",
    "user.username_lower",
    "/drafts.json?offset=%@&username=%@"
  ),

  load() {
    this.setProperties({
      itemsLoaded: 0,
      content: [],
      lastLoadedUrl: null
    });
    return this.findItems();
  },

  noContent: function() {
    return this.get("loaded") && this.get("content").length === 0;
  }.property("loaded", "content.@each"),

  remove(draft) {
    let content = this.get("content").filter(function(item) {
      return item.sequence !== draft.sequence;
    });

    this.setProperties({ content, itemsLoaded: content.length });
  },

  findItems() {
    const self = this;
    let findUrl = this.get("baseUrl");

    const lastLoadedUrl = this.get("lastLoadedUrl");
    if (lastLoadedUrl === findUrl) {
      return Ember.RSVP.resolve();
    }

    if (this.get("loading")) {
      return Ember.RSVP.resolve();
    }

    this.set("loading", true);

    return ajax(findUrl, { cache: "false" })
      .then(function(result) {
        if (result && result.no_results_help) {
          self.set("noContentHelp", result.no_results_help);
        }
        if (result && result.drafts) {
          const copy = Em.A();
          result.drafts.forEach(function(draft) {
            let draftData = JSON.parse(draft.data);
            draft.post_number = draftData.postId || null;
            if (
              draft.draft_key === NEW_PRIVATE_MESSAGE_KEY ||
              draft.draft_key === NEW_TOPIC_KEY
            ) {
              draft.title = draftData.title;
            }
            draft.title = emojiUnescape(
              Handlebars.Utils.escapeExpression(draft.title)
            );
            copy.pushObject(UserDraft.create(draft));
          });
          self.get("content").pushObjects(copy);
          self.setProperties({
            loaded: true,
            itemsLoaded: self.get("itemsLoaded") + result.drafts.length
          });
        }
      })
      .finally(function() {
        self.set("loading", false);
        self.set("lastLoadedUrl", findUrl);
      });
  }
});
