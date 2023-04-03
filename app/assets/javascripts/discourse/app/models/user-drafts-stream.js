import discourseComputed from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import { cookAsync, emojiUnescape, excerpt } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import {
  NEW_PRIVATE_MESSAGE_KEY,
  NEW_TOPIC_KEY,
} from "discourse/models/composer";
import RestModel from "discourse/models/rest";
import UserDraft from "discourse/models/user-draft";

export default RestModel.extend({
  limit: 30,

  loading: false,
  hasMore: false,
  content: null,

  init() {
    this._super(...arguments);
    this.reset();
  },

  reset() {
    this.setProperties({
      loading: false,
      hasMore: true,
      content: [],
    });
  },

  @discourseComputed("content.length", "loading")
  noContent(contentLength, loading) {
    return contentLength === 0 && !loading;
  },

  remove(draft) {
    this.set(
      "content",
      this.content.filter((item) => item.draft_key !== draft.draft_key)
    );
  },

  findItems(site) {
    if (site) {
      this.set("site", site);
    }

    if (this.loading || !this.hasMore) {
      return Promise.resolve();
    }

    this.set("loading", true);

    const url = `/drafts.json?offset=${this.content.length}&limit=${this.limit}`;
    return ajax(url)
      .then((result) => {
        if (!result) {
          return;
        }

        if (!result.drafts) {
          return;
        }

        this.set("hasMore", result.drafts.size >= this.limit);

        const promises = result.drafts.map((draft) => {
          draft.data = JSON.parse(draft.data);
          return cookAsync(draft.data.reply).then((cooked) => {
            draft.excerpt = excerpt(cooked.string, 300);
            draft.post_number = draft.data.postId || null;
            if (
              draft.draft_key === NEW_PRIVATE_MESSAGE_KEY ||
              draft.draft_key === NEW_TOPIC_KEY
            ) {
              draft.title = draft.data.title;
            }
            draft.title = emojiUnescape(escapeExpression(draft.title));
            if (draft.data.categoryId) {
              draft.category =
                this.site.categories.findBy("id", draft.data.categoryId) ||
                null;
            }
            this.content.push(UserDraft.create(draft));
          });
        });

        return Promise.all(promises);
      })
      .finally(() => {
        this.set("loading", false);
      });
  },
});
