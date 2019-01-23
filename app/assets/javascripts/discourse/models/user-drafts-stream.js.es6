import { ajax } from "discourse/lib/ajax";
import { url } from "discourse/lib/computed";
import RestModel from "discourse/models/rest";
import UserDraft from "discourse/models/user-draft";
import { emojiUnescape } from "discourse/lib/text";
import computed from "ember-addons/ember-computed-decorators";

import {
  NEW_TOPIC_KEY,
  NEW_PRIVATE_MESSAGE_KEY
} from "discourse/models/composer";

export default RestModel.extend({
  loaded: false,

  init() {
    this._super(...arguments);
    this.setProperties({
      itemsLoaded: 0,
      content: [],
      lastLoadedUrl: null
    });
  },

  baseUrl: url(
    "itemsLoaded",
    "user.username_lower",
    "/drafts.json?offset=%@&username=%@"
  ),

  load(site) {
    this.setProperties({
      itemsLoaded: 0,
      content: [],
      lastLoadedUrl: null,
      site: site
    });
    return this.findItems();
  },

  @computed("content.length", "loaded")
  noContent(contentLength, loaded) {
    return loaded && contentLength === 0;
  },

  remove(draft) {
    let content = this.get("content").filter(
      item => item.sequence !== draft.sequence
    );
    this.setProperties({ content, itemsLoaded: content.length });
  },

  findItems() {
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
      .then(result => {
        if (result && result.no_results_help) {
          this.set("noContentHelp", result.no_results_help);
        }
        if (result && result.drafts) {
          const copy = Ember.A();
          result.drafts.forEach(draft => {
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
            if (draft.category_id) {
              draft.category =
                this.site.categories.findBy("id", draft.category_id) || null;
            }

            copy.pushObject(UserDraft.create(draft));
          });
          this.get("content").pushObjects(copy);
          this.setProperties({
            loaded: true,
            itemsLoaded: this.get("itemsLoaded") + result.drafts.length
          });
        }
      })
      .finally(() => {
        this.set("loading", false);
        this.set("lastLoadedUrl", findUrl);
      });
  }
});
