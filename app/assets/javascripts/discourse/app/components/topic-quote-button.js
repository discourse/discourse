import QuoteButton from "discourse/components/quote-button";
import afterTransition from "discourse/lib/after-transition";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { fixQuotes } from "discourse/lib/quote";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { postUrl, setCaretPosition } from "discourse/lib/utilities";
import { getAbsoluteURL } from "discourse-common/lib/get-url";
import Sharing from "discourse/lib/sharing";
import { alias } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";

export default QuoteButton.extend({
  layoutName: "components/quote-button",
  privateCategory: alias("topic.category.read_restricted"),

  @discourseComputed("topic.isPrivateMessage")
  quoteSharingSources(isPM) {
    return Sharing.activeSources(
      this.siteSettings.share_quote_buttons,
      this.siteSettings.login_required || isPM
    );
  },

  @discourseComputed("topic.{isPrivateMessage,invisible,category}")
  quoteSharingShowLabel() {
    return this.quoteSharingSources.length > 1;
  },

  @discourseComputed("topic.{id,slug}", "quoteState")
  shareUrl(topic, quoteState) {
    const postId = quoteState.data.postId;
    const postNumber = topic.postStream.findLoadedPost(postId).post_number;
    return getAbsoluteURL(postUrl(topic.slug, topic.id, postNumber));
  },

  @discourseComputed("topic.details.can_create_post", "composerVisible")
  embedQuoteButton(canCreatePost, composerOpened) {
    return (
      (canCreatePost || composerOpened) && this.currentUser?.enable_quoting
    );
  },

  @discourseComputed("topic.{isPrivateMessage,invisible,category}")
  quoteSharingEnabled(topic) {
    if (
      this.site.mobileView ||
      this.siteSettings.share_quote_visibility === "none" ||
      (this.currentUser &&
        this.siteSettings.share_quote_visibility === "anonymous") ||
      this.quoteSharingSources.length === 0 ||
      this.privateCategory ||
      (this.currentUser && topic.invisible)
    ) {
      return false;
    }

    return true;
  },

  _setCanEdit(params) {
    this.set(
      "_canEdit",
      this.topic.postStream.findLoadedPost(params.postId)?.can_edit
    );
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

        this.editText(postModel);

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

  @action
  _saveFastEdit() {
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

  @action
  save() {
    if (this._displayFastEditInput && !this._saveFastEditDisabled) {
      this._saveFastEdit();
    }
  },

  @action
  share(source) {
    Sharing.shareSource(source, {
      url: this.shareUrl,
      title: this.topic.title,
      quote: window.getSelection().toString(),
    });
  },

  // code related to extraction of quote from elements
  //
  // this must be overridden for any other different type
  // of quote buttons that we implement, because everything
  // can have different data needed to form the quote and
  // different CSS classes etc.
  _getRequiredQuoteData($ancestor, requiredData = {}) {
    if (requiredData.postId) {
      return requiredData;
    }
    return { postId: $ancestor.closest(".boxed, .reply").data("post-id") };
  },

  _hasRequiredQuoteData(requiredQuoteData) {
    return requiredQuoteData.postId !== null;
  },

  _noCloseContentEl($ancestor) {
    return $ancestor.closest(".contents").length === 0;
  },

  _noCloseQuotableEl($selectionStart) {
    return $selectionStart.closest(".cooked").length === 0;
  },

  _findCooked($selectedElement) {
    return (
      $selectedElement.find(".cooked")[0] ||
      $selectedElement.closest(".cooked")[0]
    );
  },

  _quoteStateOpts(element, opts) {
    opts.username = element.dataset.username || this._getQuoteTitle(element);
    opts.post = element.dataset.post;
    opts.topic = element.dataset.topic;
  },

  _getQuoteTitle(element) {
    const titleEl = element.querySelector(".title");
    if (!titleEl) {
      return;
    }

    const titleLink = titleEl.querySelector("a:not(.back)");
    if (titleLink) {
      return titleLink.textContent.trim();
    }

    return titleEl.textContent.trim().replace(/:$/, "");
  },
});
