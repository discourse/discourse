import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse/lib/decorators";
import { cook, emojiUnescape, excerpt } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import {
  NEW_PRIVATE_MESSAGE_KEY,
  NEW_TOPIC_KEY,
} from "discourse/models/composer";
import RestModel from "discourse/models/rest";
import Site from "discourse/models/site";
import UserDraft from "discourse/models/user-draft";

export default class UserDraftsStream extends RestModel {
  limit = 30;
  loading = false;
  hasMore = false;
  content = null;

  init() {
    super.init(...arguments);
    this.reset();
  }

  reset() {
    this.setProperties({
      loading: false,
      hasMore: true,
      content: [],
    });
  }

  @discourseComputed("content.length", "loading")
  noContent(contentLength, loading) {
    return contentLength === 0 && !loading;
  }

  remove(draft) {
    this.set(
      "content",
      this.content.filter((item) => item.draft_key !== draft.draft_key)
    );
  }

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

        result.categories?.forEach((category) =>
          Site.current().updateCategory(category)
        );

        this.set("hasMore", result.drafts.size >= this.limit);

        const promises = result.drafts.map((draft) => {
          draft.data = JSON.parse(draft.data);
          return cook(draft.data.reply).then((cooked) => {
            draft.excerpt = excerpt(cooked.toString(), 300);
            draft.post_number = draft.data.postId || null;
            if (
              draft.draft_key === NEW_PRIVATE_MESSAGE_KEY ||
              draft.draft_key === NEW_TOPIC_KEY
            ) {
              draft.title = draft.data.title;
            }
            draft.title = emojiUnescape(escapeExpression(draft.title));
            if (draft.data.categoryId) {
              draft.category = Category.findById(draft.data.categoryId) || null;
            }
            this.content.push(UserDraft.create(draft));
          });
        });

        return Promise.all(promises);
      })
      .finally(() => {
        this.set("loading", false);
      });
  }
}
