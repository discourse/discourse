import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel, debounce } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import PostTextSelectionToolbar from "discourse/components/post-text-selection-toolbar";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";
import escapeRegExp from "discourse/lib/escape-regexp";
import isElementInViewport from "discourse/lib/is-element-in-viewport";
import toMarkdown from "discourse/lib/to-markdown";
import { applyValueTransformer } from "discourse/lib/transformer";
import {
  getElement,
  selectedNode,
  selectedRange,
  selectedText,
} from "discourse/lib/utilities";
import virtualElementFromTextRange from "discourse/lib/virtual-element-from-text-range";

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

const CSS_TO_DISABLE_FAST_EDIT = [
  "aside.quote",
  "aside.onebox",
  ".cooked-date",
  "body.encrypted-topic-page",
].join(",");

export default class PostTextSelection extends Component {
  @service appEvents;
  @service capabilities;
  @service currentUser;
  @service site;
  @service siteSettings;
  @service menu;

  @tracked selectTextMode = false;
  @tracked preventClose = applyValueTransformer(
    "post-text-selection-prevent-close",
    false
  );

  prevSelectedText;

  runLoopHandlers = modifier(() => {
    return () => {
      cancel(this.selectionChangeHandler);
    };
  });

  documentListeners = modifier(() => {
    document.addEventListener("pointerup", this.pointerup, { passive: true });
    document.addEventListener("selectionchange", this.selectionchange);
    // fires when user finishes adjusting text selection on android
    document.addEventListener("contextmenu", this.contextmenu, {
      passive: true,
    });

    return () => {
      document.removeEventListener("pointerup", this.pointerup);
      document.removeEventListener("selectionchange", this.selectionchange);
      document.removeEventListener("contextmenu", this.contextmenu);
    };
  });

  appEventsListeners = modifier(() => {
    this.appEvents.on("topic:current-post-scrolled", this, "handleTopicScroll");
    this.appEvents.on("quote-button:quote", this, "insertQuote");

    return () => {
      this.appEvents.off(
        "topic:current-post-scrolled",
        this,
        "handleTopicScroll"
      );
      this.appEvents.off("quote-button:quote", this, "insertQuote");
    };
  });

  willDestroy() {
    super.willDestroy(...arguments);

    cancel(this.debouncedSelectionChanged);
    cancel(this.touchEndLaterHandler);
    this.menuInstance?.close();
  }

  @bind
  async hideToolbar() {
    if (this.preventClose) {
      return;
    }
    await this.menuInstance?.close();
  }

  async selectionChanged(options = {}, cooked, postId) {
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
      !options.force &&
      this.menuInstance?.expanded &&
      this.prevSelectedText === _selectedText
    ) {
      return;
    }

    this.prevSelectedText = _selectedText;

    // computing markdown takes a lot of time on long posts
    // this code attempts to compute it only when we can't fast track
    let opts = {
      full:
        selectedRange().startOffset > 0
          ? false
          : _selectedText === toMarkdown(cooked.innerHTML),
    };

    const _selectedElement = getElement(selectedNode());
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

    const start = getElement(selection.getRangeAt(0).startContainer);
    if (!start || start.closest(CSS_TO_DISABLE_FAST_EDIT)) {
      supportsFastEdit = false;
    }

    if (supportsFastEdit) {
      const regexp = new RegExp(escapeRegExp(quoteState.buffer), "gi");
      const matches = cooked.innerHTML.match(regexp);

      if (
        quoteState.buffer.length === 0 ||
        quoteState.buffer.includes("|") || // tables are too complex
        quoteState.buffer.match(/\n/g) || // linebreaks are too complex
        quoteState.buffer.match(/[‚‘’„“”«»‹›™±…→←↔¶]/g) || // typopgraphic characters are too complex
        matches?.length !== 1 // duplicates are too complex
      ) {
        supportsFastEdit = false;
      }
    }

    let offset = 3;
    if (this.shouldRenderUnder) {
      // on mobile, we ideally want to show the toolbar at the end of the selection
      offset = 20;

      if (
        !isElementInViewport(selectedRange().startContainer.parentNode) ||
        !isElementInViewport(selectedRange().endContainer.parentNode)
      ) {
        // we force a higher offset in two cases:
        // - the start of the selection is not in viewport, in this case on iOS for example
        //   the native menu will be shown at the bottom of the screen, right after text selection
        //   so we need more space
        // - the end of the selection is not in viewport, in this case our menu will be shown at the top
        //   of the screen, so we need more space to avoid overlapping with the native menu
        const { isAndroid } = this.capabilities;
        offset = isAndroid ? 90 : 70;
      }
    }

    const menuOptions = {
      identifier: "post-text-selection-toolbar",
      component: PostTextSelectionToolbar,
      inline: true,
      placement: this.shouldRenderUnder ? "bottom-start" : "top-start",
      fallbackPlacements: this.shouldRenderUnder
        ? ["bottom-end", "top-start"]
        : ["bottom-start"],
      offset,
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
      menuOptions
    );
  }

  @bind
  contextmenu() {
    this.handleSelection();
    this.enablePointerEventsOnMenu();
  }

  @bind
  selectionchange() {
    this.disablePointerEventsOnMenu();
  }

  @bind
  pointerup() {
    this.handleSelection();
    this.enablePointerEventsOnMenu();
  }

  enablePointerEventsOnMenu() {
    document
      .querySelector("[data-identifier='post-text-selection-toolbar']")
      ?.classList.remove("-disable-pointer-events");
  }

  disablePointerEventsOnMenu() {
    // on android there's no reliable way to know when user has finished text selection
    // so we use contextmenu which will be fired while holding the selection even if
    // the user didn't release the pointer yet, as a result menu will be shown
    // while selecting and we want to be sure it's not interfering
    document
      .querySelector("[data-identifier='post-text-selection-toolbar']")
      ?.classList.add("-disable-pointer-events");
  }

  @bind
  handleSelection(options = {}) {
    const selection = window.getSelection();
    if (selection.rangeCount) {
      const range = selection.getRangeAt(0);
      if (range.collapsed) {
        this.args.quoteState.clear();
        return;
      }

      const parent =
        range.commonAncestorContainer.nodeType === Node.TEXT_NODE
          ? range.commonAncestorContainer.parentNode
          : range.commonAncestorContainer;
      const cooked = parent.closest(".cooked");
      if (cooked) {
        const article = cooked.closest(".boxed, .reply");
        const postId = article.dataset.postId;
        const { isIOS, isWinphone, isAndroid } = this.capabilities;
        const wait = isIOS || isWinphone || isAndroid ? INPUT_DELAY : 25;
        this.selectionChangeHandler = discourseDebounce(
          this,
          this.selectionChanged,
          options,
          cooked,
          postId,
          wait
        );
      } else {
        this.args.quoteState.clear();
        this.hideToolbar();
        cancel(this.selectionChangeHandler);
      }
    }
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
    return this.currentUser?.get("user_option.enable_quoting");
  }

  // on Desktop, shows the bar at the beginning of the selection
  // on Mobile, shows the bar at the end of the selection
  @cached
  get shouldRenderUnder() {
    const { isIOS, isAndroid, isOpera } = this.capabilities;
    return this.site.isMobileDevice || isIOS || isAndroid || isOpera;
  }

  @action
  handleTopicScroll() {
    if (this.site.mobileView) {
      this.debouncedSelectionChanged = debounce(
        this,
        this.handleSelection,
        { force: true },
        250,
        false
      );
    }
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
