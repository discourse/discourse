import {
  selectedNode,
  selectedRange,
  selectedText,
} from "discourse/lib/utilities";
import { INPUT_DELAY } from "discourse-common/config/environment";
import { action } from "@ember/object";
import { bind } from "discourse-common/utils/decorators";
import discourseDebounce from "discourse-common/lib/debounce";
import toMarkdown from "discourse/lib/to-markdown";
import escapeRegExp from "discourse-common/utils/escape-regexp";
import virtualElementFromTextRange from "discourse/lib/virtual-element-from-text-range";
import { inject as service } from "@ember/service";
import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import PostTextSelectionToolbar from "discourse/components/post-text-selection-toolbar";
import { cancel } from "@ember/runloop";
import discourseLater from "discourse-common/lib/later";

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

export default class PostTextSelection extends Component {
  <template>
    {{! template-lint-disable modifier-name-case }}
    <div
      {{this.documentListeners}}
      {{this.appEventsListeners}}
      {{this.runLoopHandlers}}
    ></div>
  </template>

  @service appEvents;
  @service capabilities;
  @service currentUser;
  @service site;
  @service siteSettings;
  @service menu;

  prevSelection;

  runLoopHandlers = modifier(() => {
    return () => {
      cancel(this.selectionChangeHandler);
      cancel(this.holdingMouseDownHandle);
    };
  });

  documentListeners = modifier(() => {
    document.addEventListener("mousedown", this.mousedown, { passive: true });
    document.addEventListener("mouseup", this.mouseup, { passive: true });
    document.addEventListener("selectionchange", this.selectionchange);

    return () => {
      document.removeEventListener("mousedown", this.mousedown);
      document.removeEventListener("mouseup", this.mouseup);
      document.removeEventListener("selectionchange", this.selectionchange);
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
    cancel(this.selectionChangedHandler);
  }

  @bind
  async hideToolbar() {
    this.args.quoteState.clear();
    await this.menuInstance?.close();
  }

  @bind
  async selectionChanged() {
    let supportsFastEdit = this.canEditPost;
    const selection = window.getSelection();

    if (selection.isCollapsed) {
      return;
    }

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
    const _selectedText = selectedText();
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

    if (this.canEditPost) {
      const regexp = new RegExp(escapeRegExp(quoteState.buffer), "gi");
      const matches = cooked.innerHTML.match(regexp);
      const non_ascii_regex = /[^\x00-\x7F]/;

      if (
        quoteState.buffer.length === 0 ||
        quoteState.buffer.includes("|") || // tables are too complex
        quoteState.buffer.match(/\n/g) || // linebreaks are too complex
        matches?.length > 1 || // duplicates are too complex
        non_ascii_regex.test(quoteState.buffer) // non-ascii chars break fast-edit
      ) {
        supportsFastEdit = false;
      } else if (matches?.length === 1) {
        supportsFastEdit = true;
      }
    }

    // avoid hard loops in quote selection unconditionally
    // this can happen if you triple click text in firefox
    if (this.menuInstance?.expanded && this.prevSelection === _selectedText) {
      return;
    }

    this.prevSelection = _selectedText;

    // on Desktop, shows the button at the beginning of the selection
    // on Mobile, shows the button at the end of the selection
    const { isIOS, isAndroid, isOpera } = this.capabilities;
    const showAtEnd = this.site.isMobileDevice || isIOS || isAndroid || isOpera;
    const options = {
      component: PostTextSelectionToolbar,
      inline: true,
      placement: showAtEnd ? "bottom-start" : "top-start",
      fallbackPlacements: showAtEnd
        ? ["bottom-end", "top-start"]
        : ["bottom-start"],
      offset: showAtEnd ? 25 : 3,
      trapTab: false,
      data: {
        canEditPost: this.canEditPost,
        editPost: this.args.editPost,
        supportsFastEdit,
        topic: this.args.topic,
        quoteState,
        insertQuote: this.insertQuote,
        hideToolbar: this.hideToolbar,
      },
    };

    this.menuInstance?.destroy();

    this.menuInstance = await this.menu.show(
      virtualElementFromTextRange(),
      options
    );
  }

  @bind
  onSelectionChanged() {
    const { isIOS, isWinphone, isAndroid } = this.capabilities;
    const wait = isIOS || isWinphone || isAndroid ? INPUT_DELAY : 100;
    this.selectionChangedHandler = discourseDebounce(
      this,
      this.selectionChanged,
      wait
    );
  }

  @bind
  mousedown(event) {
    this.holdingMouseDown = false;

    if (!event.target.closest(".cooked")) {
      return;
    }

    this.isMousedown = true;
    this.holdingMouseDownHandler = discourseLater(() => {
      this.holdingMouseDown = true;
    }, 100);
  }

  @bind
  async mouseup() {
    this.prevSelection = null;
    this.isMousedown = false;

    if (this.holdingMouseDown) {
      this.onSelectionChanged();
    }
  }

  @bind
  selectionchange() {
    cancel(this.selectionChangeHandler);
    this.selectionChangeHandler = discourseLater(() => {
      if (!this.isMousedown) {
        this.onSelectionChanged();
      }
    }, 100);
  }

  get post() {
    return this.args.topic.postStream.findLoadedPost(
      this.args.quoteState.postId
    );
  }

  get canEditPost() {
    return this.siteSettings.enable_fast_edit && this.post?.can_edit;
  }

  @action
  async insertQuote() {
    await this.args.selectText();
    await this.hideToolbar();
  }
}
