import EmberObject from "@ember/object";
import afterTransition from "discourse/lib/after-transition";
import { setCaretPosition } from "discourse/lib/utilities";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Sharing from "discourse/lib/sharing";
import { fixQuotes } from "discourse/mixins/quote-button";

function getQuoteTitle(element) {
  const titleEl = element.querySelector(".title");
  if (!titleEl) {
    return;
  }

  const titleLink = titleEl.querySelector("a:not(.back)");
  if (titleLink) {
    return titleLink.textContent.trim();
  }

  return titleEl.textContent.trim().replace(/:$/, "");
}

// TODO (martin) Maybe move the selectText function here too, or at least
// part of it? Perhaps should be inside the component even since the
// components are now specific to what we are quoting...same for things
// like hasRequiredData, getRequiredData, noCloseContentEl
export const TopicQuoteHandler = EmberObject.extend({
  init(params) {
    this.topic = params.topic;
  },

  fastEdit(quoteState, quoteRegExp, markdownBody, params = {}) {
    if (!this.canFastEdit) {
      return;
    }

    // todo: canEdit instead of canEditPost?
    this.set(
      "_canEditPost",
      this.topic.postStream.findLoadedPost(params.postId)?.can_edit
    );

    const matches = markdownBody.match(quoteRegExp);
    if (
      quoteState.buffer.length < 1 ||
      quoteState.buffer.includes("|") || // tables are too complex
      quoteState.buffer.match(/\n/g) || // linebreaks are too complex
      matches?.length > 1 // duplicates are too complex
    ) {
      this.set("_isFastEditable", false);
      this.set("_fastEditInitalSelection", null);
      this.set("_fastEditNewSelection", null);
    } else if (matches?.length === 1) {
      this.set("_isFastEditable", true);
      this.set("_fastEditInitalSelection", quoteState.buffer);
      this.set("_fastEditNewSelection", quoteState.buffer);
    }
  },

  getRequiredData($ancestor, requiredData = {}) {
    if (requiredData.postId) {
      return requiredData;
    }
    return { postId: $ancestor.closest(".boxed, .reply").data("post-id") };
  },

  hasRequiredData(requiredData) {
    return requiredData.postId !== null;
  },

  noCloseContentEl($ancestor) {
    return $ancestor.closest(".contents").length === 0;
  },

  noCloseQuotableEl($selectionStart) {
    return $selectionStart.closest(".cooked").length === 0;
  },

  findCooked($selectedElement) {
    return (
      $selectedElement.find(".cooked")[0] ||
      $selectedElement.closest(".cooked")[0]
    );
  },

  quoteStateOpts(element, opts) {
    opts.username = element.dataset.username || getQuoteTitle(element);
    opts.post = element.dataset.post;
    opts.topic = element.dataset.topic;
  },

  toggleFastEdit() {
    const postId = this.quoteState.data.postId;
    const postModel = this.topic.postStream.findLoadedPost(postId);
    return ajax(`/posts/${postModel.id}`, { type: "GET", cache: false }).then(
      (result) => {
        let bestIndex = 0;
        const rows = result.raw.split("\n");

        // selecting even a part of the text of a list item will include
        // "* " at the beginning of the buffer, we remove it to be able
        // to find it in row
        const buffer = fixQuotes(
          this.quoteState.buffer.split("\n")[0].replace(/^\* /, "")
        );

        rows.some((row, index) => {
          if (row.length && row.includes(buffer)) {
            bestIndex = index;
            return true;
          }
        });

        this?.editPost(postModel);

        afterTransition(document.querySelector("#reply-control"), () => {
          const textarea = document.querySelector(".d-editor-input");
          if (!textarea || this.isDestroyed || this.isDestroying) {
            return;
          }

          // best index brings us to one row before as slice start from 1
          // we add 1 to be at the beginning of next line, unless we start from top
          setCaretPosition(
            textarea,
            rows.slice(0, bestIndex).join("\n").length + (bestIndex > 0 ? 1 : 0)
          );

          // ensures we correctly scroll to caret and reloads composer
          // if we do another selection/edit
          textarea.blur();
          textarea.focus();
        });
      }
    );
  },

  saveFastEdit() {
    const postId = this.quoteState?.data.postId;
    const postModel = this.topic.postStream.findLoadedPost(postId);

    this.set("_isSavingFastEdit", true);

    return ajax(`/posts/${postModel.id}`, { type: "GET", cache: false })
      .then((result) => {
        const newRaw = result.raw.replace(
          fixQuotes(this._fastEditInitalSelection),
          fixQuotes(this._fastEditNewSelection)
        );

        postModel
          .save({ raw: newRaw })
          .catch(popupAjaxError)
          .finally(() => {
            this.set("_isSavingFastEdit", false);
            this._hideButton();
          });
      })
      .catch(popupAjaxError);
  },

  share(source) {
    Sharing.shareSource(source, {
      url: this.shareUrl,
      title: this.topic.title,
      quote: window.getSelection().toString(),
    });
  },
});
