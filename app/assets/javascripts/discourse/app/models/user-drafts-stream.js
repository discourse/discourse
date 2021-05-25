import {
  NEW_PRIVATE_MESSAGE_KEY,
  NEW_TOPIC_KEY,
} from "discourse/models/composer";
import { A } from "@ember/array";
import { Promise } from "rsvp";
import RestModel from "discourse/models/rest";
import UserDraft from "discourse/models/user-draft";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { url } from "discourse/lib/computed";

export default RestModel.extend({
  loaded: false,

  init() {
    this._super(...arguments);
    this.setProperties({
      itemsLoaded: 0,
      content: [],
      lastLoadedUrl: null,
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
      site: site,
    });
    return this.findItems();
  },

  @discourseComputed("content.length", "loaded")
  noContent(contentLength, loaded) {
    return loaded && contentLength === 0;
  },

  remove(draft) {
    let content = this.content.filter(
      (item) => item.draft_key !== draft.draft_key
    );
    this.setProperties({ content, itemsLoaded: content.length });
  },

  findItems() {
    let findUrl = this.baseUrl;

    const lastLoadedUrl = this.lastLoadedUrl;
    if (lastLoadedUrl === findUrl) {
      return Promise.resolve();
    }

    if (this.loading) {
      return Promise.resolve();
    }

    this.set("loading", true);

    return ajax(findUrl)
      .then((result) => {
        if (result && result.no_results_help) {
          this.set("noContentHelp", result.no_results_help);
        }
        if (result && result.drafts) {
          const copy = A();
          result.drafts.forEach((draft) => {
            let draftData = JSON.parse(draft.data);
            draft.post_number = draftData.postId || null;
            if (
              draft.draft_key === NEW_PRIVATE_MESSAGE_KEY ||
              draft.draft_key === NEW_TOPIC_KEY
            ) {
              draft.title = draftData.title;
            }
            draft.title = emojiUnescape(escapeExpression(draft.title));
            if (draft.category_id) {
              draft.category =
                this.site.categories.findBy("id", draft.category_id) || null;
            }

            copy.pushObject(UserDraft.create(draft));
          });
          this.content.pushObjects(copy);
          this.setProperties({
            loaded: true,
            itemsLoaded: this.itemsLoaded + result.drafts.length,
          });
        }
      })
      .finally(() => {
        this.set("loading", false);
        this.set("lastLoadedUrl", findUrl);
      });
  },
});
