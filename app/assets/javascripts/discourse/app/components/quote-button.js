import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import {
  postUrl,
  selectedElement,
  selectedRange,
  selectedText,
  setCaretPosition,
} from "discourse/lib/utilities";
import { INPUT_DELAY } from "discourse-common/config/environment";
import Sharing from "discourse/lib/sharing";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import discourseDebounce from "discourse-common/lib/debounce";
import { getAbsoluteURL } from "discourse-common/lib/get-url";
import { next, schedule } from "@ember/runloop";
import toMarkdown from "discourse/lib/to-markdown";
import escapeRegExp from "discourse-common/utils/escape-regexp";
import { createPopper } from "@popperjs/core";
import virtualElementFromTextRange from "discourse/lib/virtual-element-from-text-range";
import { inject as service } from "@ember/service";
import FastEditModal from "discourse/components/modal/fast-edit";

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

export function fixQuotes(str) {
  // u+201c, u+201d = “ ”
  // u+2018, u+2019 = ‘ ’
  return str.replace(/[\u201C\u201D]/g, '"').replace(/[\u2018\u2019]/g, "'");
}

export default class QuoteButton extends Component {
  @service appEvents;
  @service capabilities;
  @service currentUser;
  @service modal;
  @service site;
  @service siteSettings;

  @tracked visible = false;
  @tracked animated = false;
  @tracked canEditPost = false;
  @tracked isFastEditable = false;
  @tracked displayFastEditInput = false;
  @tracked fastEditInitialSelection;

  isMouseDown = false;
  reselected = false;
  prevSelection;
  element;
  popper;
  popperPlacement = "top-start";
  popperOffset = [0, 3];

  @bind
  hideButton() {
    this.args.quoteState.clear();

    this.visible = false;
    this.animated = false;
    this.isFastEditable = false;
    this.displayFastEditInput = false;
    this.fastEditInitialSelection = null;

    this.teardownSelectionListeners();
  }

  selectionChanged() {
    if (this.displayFastEditInput) {
      this.textRange = virtualElementFromTextRange();
      return;
    }

    const quoteState = this.args.quoteState;

    const selection = window.getSelection();
    if (selection.isCollapsed) {
      if (this.visible) {
        this.hideButton();
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
          this.hideButton();
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
    this.visible = quoteState.buffer.length > 0;

    if (this.siteSettings.enable_fast_edit) {
      this.canEditPost = this.post?.can_edit;

      if (this.canEditPost) {
        const regexp = new RegExp(escapeRegExp(quoteState.buffer), "gi");
        const matches = cooked.innerHTML.match(regexp);
        const non_ascii_regex = /[^\x00-\x7F]/;

        if (
          quoteState.buffer.length < 1 ||
          quoteState.buffer.includes("|") || // tables are too complex
          quoteState.buffer.match(/\n/g) || // linebreaks are too complex
          matches?.length > 1 || // duplicates are too complex
          non_ascii_regex.test(quoteState.buffer) // non-ascii chars break fast-edit
        ) {
          this.isFastEditable = false;
          this.fastEditInitialSelection = null;
        } else if (matches?.length === 1) {
          this.isFastEditable = true;
          this.fastEditInitialSelection = quoteState.buffer;
        }
      }
    }

    // avoid hard loops in quote selection unconditionally
    // this can happen if you triple click text in firefox
    if (this.prevSelection === _selectedText) {
      return;
    }

    this.prevSelection = _selectedText;

    // on Desktop, shows the button at the beginning of the selection
    // on Mobile, shows the button at the end of the selection
    const isMobileDevice = this.site.isMobileDevice;
    const { isIOS, isAndroid, isOpera } = this.capabilities;
    const showAtEnd = isMobileDevice || isIOS || isAndroid || isOpera;

    if (showAtEnd) {
      this.popperPlacement = "bottom-start";
      this.popperOffset = [0, 25];
    }

    // change the position of the button
    schedule("afterRender", () => {
      if (!this.element || this.isDestroying || this.isDestroyed) {
        return;
      }

      this.textRange = virtualElementFromTextRange();
      this.setupSelectionListeners();

      this.popper = createPopper(this.textRange, this.element, {
        placement: this.popperPlacement,
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
              offset: this.popperOffset,
            },
          },
        ],
      });

      if (!this.animated) {
        // We only enable CSS transitions after the initial positioning
        // otherwise the button can appear to fly in from off-screen
        next(() => (this.animated = true));
      }
    });
  }

  @bind
  updateRect() {
    this.textRange?.updateRect();
  }

  setupSelectionListeners() {
    document.body.addEventListener("mouseup", this.updateRect);
    window.addEventListener("scroll", this.updateRect);
    document.scrollingElement.addEventListener("scroll", this.updateRect);
  }

  teardownSelectionListeners() {
    document.body.removeEventListener("mouseup", this.updateRect);
    window.removeEventListener("scroll", this.updateRect);
    document.scrollingElement.removeEventListener("scroll", this.updateRect);
  }

  @action
  didInsert(element) {
    this.element = element;

    const { isWinphone, isAndroid } = this.capabilities;
    const wait = isWinphone || isAndroid ? INPUT_DELAY : 25;
    const onSelectionChanged = () => {
      discourseDebounce(this, this.selectionChanged, wait);
    };

    $(document)
      .on("mousedown.quote-button", (e) => {
        this.prevSelection = null;
        this.isMouseDown = true;
        this.reselected = false;

        // prevents fast-edit input event to trigger mousedown
        if (e.target.classList.contains("fast-edit-input")) {
          return;
        }

        if (
          $(e.target).closest(".quote-button, .create, .share, .reply-new")
            .length === 0
        ) {
          this.hideButton();
        }
      })
      .on("mouseup.quote-button", (e) => {
        // prevents fast-edit input event to trigger mouseup
        if (e.target.classList.contains("fast-edit-input")) {
          return;
        }

        this.prevSelection = null;
        this.isMouseDown = false;
        onSelectionChanged();
      })
      .on("selectionchange.quote-button", () => {
        if (!this.isMouseDown && !this.reselected) {
          onSelectionChanged();
        }
      });

    this.appEvents.on("quote-button:quote", this, "insertQuote");
    this.appEvents.on("quote-button:edit", this, "toggleFastEditForm");
  }

  willDestroy() {
    this.popper?.destroy();
    $(document)
      .off("mousedown.quote-button")
      .off("mouseup.quote-button")
      .off("selectionchange.quote-button");
    this.appEvents.off("quote-button:quote", this, "insertQuote");
    this.appEvents.off("quote-button:edit", this, "toggleFastEditForm");
    this.teardownSelectionListeners();
  }

  get privateCategory() {
    return this.args.topic.category.read_restricted;
  }

  get post() {
    return this.args.topic.postStream.findLoadedPost(
      this.args.quoteState.postId
    );
  }

  get quoteSharingEnabled() {
    if (
      this.site.mobileView ||
      this.siteSettings.share_quote_visibility === "none" ||
      (this.currentUser &&
        this.siteSettings.share_quote_visibility === "anonymous") ||
      this.quoteSharingSources.length === 0 ||
      this.privateCategory ||
      (this.currentUser && this.args.topic.invisible)
    ) {
      return false;
    }

    return true;
  }

  get quoteSharingSources() {
    return Sharing.activeSources(
      this.siteSettings.share_quote_buttons,
      this.siteSettings.login_required || this.args.topic.isPrivateMessage
    );
  }

  get quoteSharingShowLabel() {
    return this.quoteSharingSources.length > 1;
  }

  get shareUrl() {
    return getAbsoluteURL(
      postUrl(this.args.topic.slug, this.args.topic.id, this.post.post_number)
    );
  }

  get embedQuoteButton() {
    const canCreatePost = this.args.topic.details.can_create_post;
    const canReplyAsNewTopic = this.args.topic.details.can_reply_as_new_topic;

    return (
      (canCreatePost || canReplyAsNewTopic) &&
      this.currentUser?.get("user_option.enable_quoting")
    );
  }

  @action
  insertQuote() {
    this.args.selectText().then(() => this.hideButton());
  }

  @action
  async toggleFastEditForm() {
    if (this.isFastEditable) {
      if (this.site.desktopView) {
        this.displayFastEditInput = !this.displayFastEditInput;
      } else {
        this.modal.show(FastEditModal, {
          model: {
            initialValue: this.fastEditInitialSelection,
            post: this.post,
          },
        });
        this.hideButton();
      }

      return;
    }

    const result = await ajax(`/posts/${this.post.id}`, { cache: false });
    let bestIndex = 0;
    const rows = result.raw.split("\n");

    // selecting even a part of the text of a list item will include
    // "* " at the beginning of the buffer, we remove it to be able
    // to find it in row
    const buffer = fixQuotes(
      this.args.quoteState.buffer.split("\n")[0].replace(/^\* /, "")
    );

    rows.some((row, index) => {
      if (row.length && row.includes(buffer)) {
        bestIndex = index;
        return true;
      }
    });

    this.args.editPost(this.post);

    document
      .querySelector("#reply-control")
      ?.addEventListener("transitionend", () => {
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

  @action
  share(source) {
    Sharing.shareSource(source, {
      url: this.shareUrl,
      title: this.args.topic.title,
      quote: window.getSelection().toString(),
    });
  }
}
