import { ajax } from "discourse/lib/ajax";
import { url } from "discourse/lib/computed";
import RestModel from "discourse/models/rest";
import UserDraft from "discourse/models/user-draft";
import UserAction from "discourse/models/user-action";
import { emojiUnescape } from "discourse/lib/text";

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
        self.set("noContentHelp", "result.no_results_help_drafts"); // TODO: i18n
        if (result && result.drafts) {
          const copy = Em.A();
          result.drafts.forEach(function(draft) {
            let draftData = JSON.parse(draft.data);
            if (draftData.action === 'createTopic') {
              draft.title = draftData.title;
            }

            draft.excerpt = draftData.reply;
            draft.title = emojiUnescape(
              Handlebars.Utils.escapeExpression(draft.title)
            );
            draft.action_type = UserAction.TYPES.drafts;
            copy.pushObject(UserDraft.create(draft));
          });

          self.get("content").pushObjects(UserAction.collapseStream(copy));
          self.setProperties({
            loaded: true,
            itemsLoaded: self.get("itemsLoaded") + result.drafts.length,
          });
        }
      })
      .finally(function() {
        self.set("loading", false);
        self.set("lastLoadedUrl", findUrl);
      });
  }
});
