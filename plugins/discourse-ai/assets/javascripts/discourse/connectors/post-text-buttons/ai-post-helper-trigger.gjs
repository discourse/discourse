import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { selectedRange } from "discourse/lib/utilities";
import AiPostHelperMenu from "../../components/ai-post-helper-menu";
import { showPostAIHelper } from "../../lib/show-ai-helper";

export default class AiPostHelperTrigger extends Component {
  static shouldRender(outletArgs, helper) {
    return showPostAIHelper(outletArgs, helper);
  }

  @service menu;

  @tracked postHighlighted = false;
  @tracked currentMenu = this.menu.getByIdentifier(
    "post-text-selection-toolbar"
  );

  // capture the state at the moment the toolbar is rendered
  // so we ensure change of state (selection change for example)
  // is not impacting the menu data
  menuData = {
    ...this.args.outletArgs.data,
    quoteState: {
      buffer: this.args.outletArgs.data.quoteState.buffer,
      opts: this.args.outletArgs.data.quoteState.opts,
      postId: this.args.outletArgs.data.quoteState.postId,
    },
    post: this.args.outletArgs.post,
    selectedRange: selectedRange(),
  };

  highlightSelectedText() {
    const postId = this.args.outletArgs.data.quoteState.postId;
    const postElement = document.querySelector(
      `article[data-post-id='${postId}'] .cooked`
    );

    if (!postElement) {
      return;
    }

    const range = this.menuData.selectedRange;

    // Split start/end text nodes at their range boundary
    if (
      range.startContainer.nodeType === Node.TEXT_NODE &&
      range.startOffset > 0
    ) {
      const newStartNode = range.startContainer.splitText(range.startOffset);
      range.setStart(newStartNode, 0);
    }
    if (
      range.endContainer.nodeType === Node.TEXT_NODE &&
      range.endOffset < range.endContainer.length
    ) {
      range.endContainer.splitText(range.endOffset);
    }

    // Create a Walker to traverse text nodes within range
    const walker = document.createTreeWalker(
      range.commonAncestorContainer,
      NodeFilter.SHOW_TEXT,
      {
        acceptNode: (node) =>
          range.intersectsNode(node)
            ? NodeFilter.FILTER_ACCEPT
            : NodeFilter.FILTER_REJECT,
      }
    );

    const textNodes = [];

    if (walker.currentNode?.nodeType === Node.TEXT_NODE) {
      textNodes.push(walker.currentNode);
    } else {
      while (walker.nextNode()) {
        textNodes.push(walker.currentNode);
      }
    }

    for (let textNode of textNodes) {
      const highlight = document.createElement("span");
      highlight.classList.add("ai-helper-highlighted-selection");

      // Replace textNode with highlighted clone
      const clone = textNode.cloneNode(true);
      highlight.appendChild(clone);
      textNode.parentNode.replaceChild(highlight, textNode);
    }

    window.getSelection().removeAllRanges();
    this.postHighlighted = true;
  }

  removeHighlightedText() {
    if (!this.postHighlighted) {
      return;
    }

    const highlightedSpans = document.querySelectorAll(
      "span.ai-helper-highlighted-selection"
    );

    highlightedSpans.forEach((span) => {
      const textNode = document.createTextNode(span.textContent);
      span.parentNode.replaceChild(textNode, span);
    });

    this.postHighlighted = false;
  }

  @action
  async showAiPostHelperMenu() {
    await this.currentMenu.close();

    await this.menu.show(this.currentMenu.trigger, {
      identifier: "ai-post-helper-menu",
      component: AiPostHelperMenu,
      interactive: true,
      trapTab: false,
      closeOnScroll: false,
      modalForMobile: true,
      data: this.menuData,
      placement: "top-start",
      fallbackPlacements: ["bottom-start"],
      updateOnScroll: false,
      onClose: () => {
        this.removeHighlightedText();
      },
    });

    await this.currentMenu.destroy();

    this.highlightSelectedText();
  }

  <template>
    {{yield}}

    <div class="ai-post-helper">
      <DButton
        @icon="discourse-sparkles"
        @title="discourse_ai.ai_helper.post_options_menu.title"
        @label="discourse_ai.ai_helper.post_options_menu.trigger"
        @action={{this.showAiPostHelperMenu}}
        class="btn-flat ai-post-helper__trigger"
      />
    </div>
  </template>
}
