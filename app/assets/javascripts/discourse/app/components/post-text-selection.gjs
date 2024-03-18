import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import PostTextSelectionToolbar from "discourse/components/post-text-selection-toolbar";
import toMarkdown from "discourse/lib/to-markdown";
import {
  selectedNode,
  selectedRange,
  selectedText,
} from "discourse/lib/utilities";
import virtualElementFromTextRange from "discourse/lib/virtual-element-from-text-range";
import { INPUT_DELAY } from "discourse-common/config/environment";
import discourseDebounce from "discourse-common/lib/debounce";
import { bind } from "discourse-common/utils/decorators";
import escapeRegExp from "discourse-common/utils/escape-regexp";

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

export default class PostTextSelection extends Component {
  @service appEvents;
  @service capabilities;
  @service currentUser;
  @service site;
  @service siteSettings;
  @service menu;

  @tracked isSelecting = false;

  prevSelectedText;

  runLoopHandlers = modifier(() => {
    return () => {
      cancel(this.selectionChangeHandler);
    };
  });

  documentListeners = modifier(() => {
    document.addEventListener("mousedown", this.mousedown, { passive: true });
    document.addEventListener("mouseup", this.mouseup, { passive: true });
    document.addEventListener("selectionchange", this.onSelectionChanged);

    return () => {
      document.removeEventListener("mousedown", this.mousedown);
      document.removeEventListener("mouseup", this.mouseup);
      document.removeEventListener("selectionchange", this.onSelectionChanged);
    };
  });

  appEventsListeners = modifier(() => {
    this.appEvents.on("quote-button:quote", this, "insertQuote");

    return () => {
      this.appEvents.off("quote-button:quote", this, "insertQuote");
    };
  });

  willDestroy() {
    super.willDestroy(...arguments);

    this.menuInstance?.destroy();
  }

  @bind
  async hideToolbar() {
    this.args.quoteState.clear();
    await this.menuInstance?.close();
  }

  @bind
  async selectionChanged() {
    if (this.isSelecting) {
      return;
    }

    const _selectedText = selectedText();

    const selection = window.getSelection();
    if (selection.isCollapsed || _selectedText === "") {
      if (!this.menuInstance?.expanded) {
        this.args.quoteState.clear();
      }
      return;
    }

    // avoid hard loops in quote selection unconditionally
    // this can happen if you triple click text in firefox
    // it's also generally unecessary work to go
    // through this if the selection hasn't changed
    if (
      this.menuInstance?.expanded &&
      this.prevSelectedText === _selectedText
    ) {
      return;
    }

    this.prevSelectedText = _selectedText;

    // ensure we selected content inside 1 post *only*
    let postId;
    for (let r = 0; r < selection.rangeCount; r++) {
      const range = selection.getRangeAt(r);
      const selectionStart =
        range.startContainer.nodeType === Node.ELEMENT_NODE
          ? range.startContainer
          : range.startContainer.parentElement;
      const ancestor =
        range.commonAncestorContainer.nodeType === Node.ELEMENT_NODE
          ? range.commonAncestorContainer
          : range.commonAncestorContainer.parentElement;

      if (!selectionStart.closest(".cooked")) {
        return await this.hideToolbar();
      }

      postId ||= ancestor.closest(".boxed, .reply")?.dataset?.postId;

      if (!ancestor.closest(".contents") || !postId) {
        return await this.hideToolbar();
      }
    }

    const _selectedElement =
      selectedNode().nodeType === Node.ELEMENT_NODE
        ? selectedNode()
        : selectedNode().parentElement;
    const cooked =
      _selectedElement.querySelector(".cooked") ||
      _selectedElement.closest(".cooked");

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

    const quoteState = this.args.quoteState;
    quoteState.selected(postId, _selectedText, opts);

    let supportsFastEdit = this.canEditPost;
    if (this.canEditPost) {
      const regexp = new RegExp(escapeRegExp(quoteState.buffer), "gi");
      const matches = cooked.innerHTML.match(regexp);

      if (
        quoteState.buffer.length === 0 ||
        quoteState.buffer.includes("|") || // tables are too complex
        quoteState.buffer.match(/\n/g) || // linebreaks are too complex
        matches?.length > 1 // duplicates are too complex
      ) {
        supportsFastEdit = false;
      } else if (matches?.length === 1) {
        supportsFastEdit = true;
      }
    }

    const options = {
      identifier: "post-text-selection-toolbar",
      component: PostTextSelectionToolbar,
      inline: true,
      placement: this.shouldRenderUnder ? "bottom-start" : "top-start",
      fallbackPlacements: this.shouldRenderUnder
        ? ["bottom-end", "top-start"]
        : ["bottom-start"],
      offset: this.shouldRenderUnder ? 25 : 3,
      trapTab: false,
      closeOnScroll: false,
      data: {
        canEditPost: this.canEditPost,
        canCopyQuote: this.canCopyQuote,
        editPost: this.args.editPost,
        supportsFastEdit,
        topic: this.args.topic,
        quoteState,
        insertQuote: this.insertQuote,
        buildQuote: this.buildQuote,
        hideToolbar: this.hideToolbar,
      },
    };

    await this.menuInstance?.destroy();

    this.menuInstance = await this.menu.show(
      virtualElementFromTextRange(),
      options
    );
  }

  @bind
  onSelectionChanged() {
    if (this.isSelecting) {
      return;
    }

    const { isIOS, isWinphone, isAndroid } = this.capabilities;
    const wait = isIOS || isWinphone || isAndroid ? INPUT_DELAY : 25;
    this.selectionChangeHandler = discourseDebounce(
      this,
      this.selectionChanged,
      wait
    );
  }

  @bind
  mousedown() {
    this.isSelecting = true;
  }

  @bind
  mouseup() {
    this.isSelecting = false;
    this.onSelectionChanged();
  }

  get post() {
    return this.args.topic.postStream.findLoadedPost(
      this.args.quoteState.postId
    );
  }

  get canEditPost() {
    return this.siteSettings.enable_fast_edit && this.post?.can_edit;
  }

  get canCopyQuote() {
    return (
      this.siteSettings.enable_quote_copy &&
      this.currentUser?.get("user_option.enable_quoting")
    );
  }

  // on Desktop, shows the bar at the beginning of the selection
  // on Mobile, shows the bar at the end of the selection
  @cached
  get shouldRenderUnder() {
    const { isIOS, isAndroid, isOpera } = this.capabilities;
    return this.site.isMobileDevice || isIOS || isAndroid || isOpera;
  }

  @action
  async insertQuote() {
    await this.args.selectText();
    await this.hideToolbar();
  }

  @action
  async buildQuote() {
    return await this.args.buildQuoteMarkdown();
  }

  <template>
    <div
      {{this.documentListeners}}
      {{this.appEventsListeners}}
      {{this.runLoopHandlers}}
    ></div>
  </template>
}
