import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import FastEditModal from "discourse/components/modal/fast-edit";
import PostTextSelectionToolbar from "discourse/components/post-text-selection-toolbar";
import { ajax } from "discourse/lib/ajax";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";
import escapeRegExp from "discourse/lib/escape-regexp";
import isElementInViewport from "discourse/lib/is-element-in-viewport";
import toMarkdown from "discourse/lib/to-markdown";
import {
  getElement,
  selectedNode,
  selectedRange,
  selectedText,
  setCaretPosition,
} from "discourse/lib/utilities";
import virtualElementFromTextRange from "discourse/lib/virtual-element-from-text-range";

export function fixQuotes(str) {
  // u+201c, u+201d = “ ”
  // u+2018, u+2019 = ‘ ’
  return str.replace(/[\u201C\u201D]/g, '"').replace(/[\u2018\u2019]/g, "'");
}

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
  @service modal;

  setup = modifier(() => {
    document.addEventListener("selectionchange", this.selectionChange);
    this.appEvents.on("quote-button:quote", this, "insertQuote");
    this.appEvents.on("quote-button:edit", this, "toggleHeadlessFastEdit");

    return () => {
      cancel(this.debouncedSelectionChangeHandler);
      document.removeEventListener("selectionchange", this.selectionChange);
      this.appEvents.off("quote-button:quote", this, "insertQuote");
      this.appEvents.off("quote-button:edit", this, "toggleHeadlessFastEdit");
      this.menuInstance?.close();
    };
  });

  @bind
  async toggleHeadlessFastEdit() {
    const cooked = this.computeCurrentCooked();
    if (!cooked) {
      return;
    }

    const quoteState = this.computeQuoteState(cooked);
    const supportsFastEdit = this.computeSupportsFastEdit(cooked, quoteState);

    await this.toggleFastEdit(quoteState, supportsFastEdit);
  }

  @bind
  async toggleFastEdit(quoteState, supportsFastEdit) {
    if (supportsFastEdit) {
      this.modal.show(FastEditModal, {
        model: {
          initialValue: quoteState.buffer,
          post: this.post,
        },
      });
    } else {
      const result = await ajax(`/posts/${this.post.id}`);

      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      let bestIndex = 0;
      const rows = result.raw.split("\n");

      // selecting even a part of the text of a list item will include
      // "* " at the beginning of the buffer, we remove it to be able
      // to find it in row
      const buffer = fixQuotes(
        quoteState.buffer.split("\n")[0].replace(/^\* /, "")
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

    this.hideToolbar();
  }

  @bind
  async showToolbar(cooked) {
    const quoteState = this.computeQuoteState(cooked);

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
        offset = 70;
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
        supportsFastEdit: this.computeSupportsFastEdit(cooked, quoteState),
        canEditPost: this.canEditPost,
        canCopyQuote: this.canCopyQuote,
        topic: this.args.topic,
        quoteState,
        insertQuote: this.insertQuote,
        buildQuote: this.buildQuote,
        hideToolbar: this.hideToolbar,
        toggleFastEdit: this.toggleFastEdit,
        editPost: this.args.editPost,
      },
    };

    this.menuInstance = await this.menu.show(
      virtualElementFromTextRange(),
      menuOptions
    );
  }

  @bind
  async hideToolbar() {
    await this.menuInstance?.close();
    await this.menuInstance?.destroy();
  }

  @bind
  async selectionChange() {
    await this.hideToolbar();
    this.debouncedSelectionChangeHandler = discourseDebounce(
      this.selectionChangeHandler,
      INPUT_DELAY
    );
  }

  @bind
  async selectionChangeHandler() {
    const cooked = this.computeCurrentCooked();
    if (cooked) {
      await this.showToolbar(cooked);
    } else {
      await this.hideToolbar();
    }
  }

  computeCurrentCooked() {
    const range = selectedRange();

    if (!range) {
      return;
    }

    // ensures triple click selection works
    if (range.endContainer?.classList?.contains?.("cooked-selection-barrier")) {
      range.setEndBefore(range.endContainer);
      return; // we changed the range here, so we want to go through the selection change handler again
    }

    if (!selectedText()?.length) {
      return;
    }

    const cooked = getElement(range.commonAncestorContainer)?.closest?.(
      ".cooked"
    );

    if (!cooked) {
      return;
    }

    if (cooked.closest(".small-action")) {
      return;
    }

    return cooked;
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
    const { isIOS, isAndroid, isOpera, isFirefox, touch } = this.capabilities;
    return (
      this.site.isMobileDevice ||
      isIOS ||
      isAndroid ||
      isOpera ||
      (touch && isFirefox)
    );
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

  computeSupportsFastEdit(cooked, quoteState) {
    const selection = window.getSelection();
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

    return supportsFastEdit;
  }

  computeQuoteState(cooked) {
    const _selectedText = selectedText();
    const _selectedElement = getElement(selectedNode());
    const postId = cooked.closest(".boxed, .reply")?.dataset?.postId;

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
    return quoteState;
  }

  <template>
    <div {{this.setup}}></div>
  </template>
}
