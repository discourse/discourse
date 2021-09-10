import discourseComputed from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import { cookAsync, emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import {
  NEW_PRIVATE_MESSAGE_KEY,
  NEW_TOPIC_KEY,
} from "discourse/models/composer";
import RestModel from "discourse/models/rest";
import UserDraft from "discourse/models/user-draft";
import { Promise } from "rsvp";

function encode(str) {
  return str.replaceAll("<", "&lt;").replaceAll(">", "&gt;");
}

function traverse(element, callback) {
  if (callback(element)) {
    for (let i = 0; i < element.childNodes.length; ++i) {
      traverse(element.childNodes[i], callback);
    }
  }
}

function excerpt(cooked, length) {
  const div = document.createElement("div");
  div.innerHTML = cooked;

  let result = "";
  let resultLength = 0;
  traverse(div, (element) => {
    if (resultLength >= length) {
      return;
    }

    if (element.nodeType === Node.TEXT_NODE) {
      if (resultLength + element.textContent.length > length) {
        const text = element.textContent.substr(0, length - resultLength);
        result += encode(text);
        result += "&hellip;";
        resultLength += text.length;
        return;
      } else {
        result += encode(element.textContent);
        resultLength += element.textContent.length;
      }
    } else if (element.tagName === "A") {
      element.innerHTML = element.innerText;
      result += element.outerHTML;
      resultLength += element.innerText.length;
    } else if (element.tagName === "IMG") {
      if (element.classList.contains("emoji")) {
        result += element.outerHTML;
      } else {
        result += "[image]";
        resultLength += "[image]".length;
      }
    } else {
      return true;
    }
  });

  return result;
}

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

    const url = `/drafts.json?offset=${this.content.length}&limit=${this.limit}&username=${this.user.username_lower}`;
    return ajax(url)
      .then((result) => {
        if (!result) {
          return;
        }

        if (result.no_results_help) {
          this.set("noContentHelp", result.no_results_help);
        }

        if (!result.drafts) {
          return;
        }

        this.set("hasMore", result.drafts.size >= this.limit);

        const promises = result.drafts.map((draft) => {
          const data = JSON.parse(draft.data);
          return cookAsync(data.reply).then((cooked) => {
            draft.excerpt = excerpt(cooked.string, 300);
            draft.post_number = data.postId || null;
            if (
              draft.draft_key === NEW_PRIVATE_MESSAGE_KEY ||
              draft.draft_key === NEW_TOPIC_KEY
            ) {
              draft.title = data.title;
            }
            draft.title = emojiUnescape(escapeExpression(draft.title));
            if (data.categoryId) {
              draft.category =
                this.site.categories.findBy("id", data.categoryId) || null;
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
