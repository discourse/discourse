import afterTransition from "discourse/lib/after-transition";
import { propertyEqual } from "discourse/lib/computed";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  postUrl,
  selectedElement,
  selectedRange,
  selectedText,
  setCaretPosition,
  translateModKey,
} from "discourse/lib/utilities";
import Component from "@ember/component";
import I18n from "I18n";
import { INPUT_DELAY } from "discourse-common/config/environment";
import KeyEnterEscape from "discourse/mixins/key-enter-escape";
import Sharing from "discourse/lib/sharing";
import { action } from "@ember/object";
import { alias } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import discourseDebounce from "discourse-common/lib/debounce";
import { getAbsoluteURL } from "discourse-common/lib/get-url";
import { next, schedule } from "@ember/runloop";
import toMarkdown from "discourse/lib/to-markdown";
import escapeRegExp from "discourse-common/utils/escape-regexp";
import { createPopper } from "@popperjs/core";
import VirtualElementFromTextRange from "discourse/lib/virtual-element-from-text-range";

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

function fixQuotes(str) {
  // u+201c, u+201d = “ ”
  // u+2018, u+2019 = ‘ ’
  return str.replace(/[\u201C\u201D]/g, '"').replace(/[\u2018\u2019]/g, "'");
}

export default Component.extend(KeyEnterEscape, {
  classNames: ["quote-button"],
  classNameBindings: [
    "visible",
    "_displayFastEditInput:fast-editing",
    "animated",
  ],
  visible: false,
  animated: false,
  privateCategory: alias("topic.category.read_restricted"),
  editPost: null,
  placement: "top-start",

  _isFastEditable: false,
  _displayFastEditInput: false,
  _fastEditInitalSelection: null,
  _fastEditNewSelection: null,
  _isSavingFastEdit: false,
  _canEditPost: false,
  _saveEditButtonTitle: I18n.t("composer.title", {
    modifier: translateModKey("Meta+"),
  }),

  _isMouseDown: false,
  _reselected: false,

  _hideButton() {
    this.quoteState.clear();
    this.set("visible", false);
    this.set("animated", false);

    this.set("_isFastEditable", false);
    this.set("_displayFastEditInput", false);
    this.set("_fastEditInitalSelection", null);
    this.set("_fastEditNewSelection", null);
  },

  _selectionChanged() {
    if (this._displayFastEditInput) {
      return;
    }

    const quoteState = this.quoteState;

    const selection = window.getSelection();
    if (selection.isCollapsed) {
      if (this.visible) {
        this._hideButton();
      }
      return;
    }

    // ensure we selected content inside 1 post *only*
    let firstRange, postId;
    for (let r = 0; r < selection.rangeCount; r++) {
      const range = selection.getRangeAt(r);
      const $selectionStart = $(range.startContainer);
      const $ancestor = $(range.commonAncestorContainer);

      if ($selectionStart.closest(".cooked").length === 0) {
        return;
      }

      firstRange = firstRange || range;
      postId = postId || $ancestor.closest(".boxed, .reply").data("post-id");

      if ($ancestor.closest(".contents").length === 0 || !postId) {
        if (this.visible) {
          this._hideButton();
        }
        return;
      }
    }

    const _selectedElement = selectedElement();
    const _selectedText = selectedText();

    const $selectedElement = $(_selectedElement);
    const cooked =
      $selectedElement.find(".cooked")[0] ||
      $selectedElement.closest(".cooked")[0];

    // computing markdown takes a lot of time on long posts
    // this code attempts to compute it only when we can't fast track
    let opts = {
      full:
        selectedRange().startOffset > 0
          ? false
          : _selectedText === toMarkdown(cooked.innerHTML),
    };

    for (
      let element = _selectedElement;
      element && element.tagName !== "ARTICLE";
      element = element.parentElement
    ) {
      if (element.tagName === "ASIDE" && element.classList.contains("quote")) {
        opts.username = element.dataset.username || getQuoteTitle(element);
        opts.post = element.dataset.post;
        opts.topic = element.dataset.topic;
        break;
      }
    }

    quoteState.selected(postId, _selectedText, opts);
    this.set("visible", quoteState.buffer.length > 0);

    if (this.siteSettings.enable_fast_edit) {
      this.set(
        "_canEditPost",
        this.topic.postStream.findLoadedPost(postId)?.can_edit
      );

      if (this._canEditPost) {
        const regexp = new RegExp(escapeRegExp(quoteState.buffer), "gi");
        const matches = cooked.innerHTML.match(regexp);

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
      }
    }

    // avoid hard loops in quote selection unconditionally
    // this can happen if you triple click text in firefox
    if (this._prevSelection === _selectedText) {
      return;
    }

    this._prevSelection = _selectedText;

    // on Desktop, shows the button at the beginning of the selection
    // on Mobile, shows the button at the end of the selection
    const isMobileDevice = this.site.isMobileDevice;
    const { isIOS, isAndroid, isOpera } = this.capabilities;
    const showAtEnd = isMobileDevice || isIOS || isAndroid || isOpera;

    if (showAtEnd) {
      this.placement = "bottom-start";
    }

    // change the position of the button
    schedule("afterRender", () => {
      if (!this.element || this.isDestroying || this.isDestroyed) {
        return;
      }

      this.textRange = new VirtualElementFromTextRange(".cooked");

      this._popper = createPopper(this.textRange, this.element, {
        placement: this.placement,
        modifiers: [
          {
            name: "computeStyles",
            options: {
              adaptive: false,
            },
          },
          {
            name: "offset",
            options: {
              offset: [0, 3],
            },
          },
        ],
      });

      if (!this.animated) {
        // We only enable CSS transitions after the initial positioning
        // otherwise the button can appear to fly in from off-screen
        next(() => this.set("animated", true));
      }
    });
  },

  didInsertElement() {
    this._super(...arguments);

    const { isWinphone, isAndroid } = this.capabilities;
    const wait = isWinphone || isAndroid ? INPUT_DELAY : 25;
    const onSelectionChanged = () => {
      discourseDebounce(this, this._selectionChanged, wait);
    };

    $(document)
      .on("mousedown.quote-button", (e) => {
        this._prevSelection = null;
        this._isMouseDown = true;
        this._reselected = false;

        // prevents fast-edit input event to trigger mousedown
        if (e.target.classList.contains("fast-edit-input")) {
          return;
        }

        if (
          $(e.target).closest(".quote-button, .create, .share, .reply-new")
            .length === 0
        ) {
          this._hideButton();
        }
      })
      .on("mouseup.quote-button", (e) => {
        // prevents fast-edit input event to trigger mouseup
        if (e.target.classList.contains("fast-edit-input")) {
          return;
        }

        this._prevSelection = null;
        this._isMouseDown = false;
        onSelectionChanged();
      })
      .on("selectionchange.quote-button", () => {
        if (!this._isMouseDown && !this._reselected) {
          onSelectionChanged();
        }
      });
    this.appEvents.on("quote-button:quote", this, "insertQuote");
    this.appEvents.on("quote-button:edit", this, "_toggleFastEditForm");
  },

  willDestroyElement() {
    $(document)
      .off("mousedown.quote-button")
      .off("mouseup.quote-button")
      .off("selectionchange.quote-button");
    this.appEvents.off("quote-button:quote", this, "insertQuote");
    this.appEvents.off("quote-button:edit", this, "_toggleFastEditForm");
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
    const postId = quoteState.postId;
    const postNumber = topic.postStream.findLoadedPost(postId).post_number;
    return getAbsoluteURL(postUrl(topic.slug, topic.id, postNumber));
  },

  @discourseComputed(
    "topic.details.can_create_post",
    "topic.details.can_reply_as_new_topic"
  )
  embedQuoteButton(canCreatePost, canReplyAsNewTopic) {
    return (
      (canCreatePost || canReplyAsNewTopic) &&
      this.currentUser?.get("user_option.enable_quoting")
    );
  },

  _saveFastEditDisabled: propertyEqual(
    "_fastEditInitalSelection",
    "_fastEditNewSelection"
  ),

  @action
  insertQuote() {
    this.attrs.selectText().then(() => this._hideButton());
  },

  @action
  _toggleFastEditForm() {
    if (this._isFastEditable) {
      this.toggleProperty("_displayFastEditInput");

      schedule("afterRender", () => {
        if (this.site.mobileView) {
          this.element.style.left = `${
            (window.innerWidth - this.element.clientWidth) / 2
          }px`;
        }
        document.querySelector("#fast-edit-input")?.focus();
      });
    } else {
      const postId = this.quoteState.postId;
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
              rows.slice(0, bestIndex).join("\n").length +
                (bestIndex > 0 ? 1 : 0)
            );

            // ensures we correctly scroll to caret and reloads composer
            // if we do another selection/edit
            textarea.blur();
            textarea.focus();
          });
        }
      );
    }
  },

  @action
  _saveFastEdit() {
    const postId = this.quoteState?.postId;
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
  cancelled() {
    this._hideButton();
  },

  @action
  share(source) {
    Sharing.shareSource(source, {
      url: this.shareUrl,
      title: this.topic.title,
      quote: window.getSelection().toString(),
    });
  },
});
