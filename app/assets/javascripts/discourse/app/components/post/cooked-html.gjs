import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DecoratedHtml from "discourse/components/decorated-html";
import { spinnerHTML } from "discourse/helpers/loading-spinner";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import escape from "discourse/lib/escape";
import highlightHTML from "discourse/lib/highlight-html";
import { iconHTML } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";

const detachedDocument = document.implementation.createHTMLDocument("detached");

export default class PostCookedHtml extends Component {
  @service appEvents;
  @service currentUser;

  @bind
  decorateBeforeAdopt(element, helper) {
    this.#decorateWithSelectionBarrier(element);
    this.#decorateWithQuoteControls(element, helper);

    this.appEvents.trigger(
      "decorate-post-cooked-element:before-adopt",
      element,
      helper
    );
  }

  get ignoredUsers() {
    return this.currentUser?.ignored_users;
  }

  get isIgnored() {
    return (
      (this.args.post.firstPost || this.args.embeddedPost) &&
      this.ignoredUsers?.includes?.(this.args.post.username)
    );
  }

  get cooked() {
    if (this.isIgnored) {
      return i18n("post.ignored");
    }

    return this.args.post.cooked;
  }

  #createDetachedElement(nodeName) {
    return detachedDocument.createElement(nodeName);
  }

  // On WebKit-based browsers, triple clicking on the last paragraph of a post won't stop at the end of the paragraph.
  // It looks like the browser is selecting EOL characters, and that causes the selection to leak into the following
  // nodes until it finds a non-empty node. This is a workaround to prevent that from happening.
  // We insert a div after the last paragraph at the end of the cooked content, containing a <br> element.
  // The line break works as a barrier, causing the selection to stop at the correct place.
  // To prevent layout shifts this div is styled to be invisible with height 0 and overflow hidden and set aria-hidden
  // to true to prevent screen readers from reading it.
  #decorateWithSelectionBarrier(element) {
    const selectionBarrier = document.createElement("div");
    selectionBarrier.classList.add("cooked-selection-barrier");
    selectionBarrier.ariaHidden = "true";
    selectionBarrier.appendChild(document.createElement("br"));
    element.appendChild(selectionBarrier);
  }

  #decorateWithQuoteControls(element, helper) {
    const quotes = element.querySelectorAll("aside.quote");
    if (quotes.length === 0) {
      return;
    }

    this.originalQuoteContents = new Map();

    quotes.forEach((aside, index) => {
      if (aside.dataset.post) {
        const quoteId = `quote-id-${aside.dataset.topic}-${aside.dataset.post}-${index}`;

        const blockquote = aside.querySelector("blockquote");
        if (blockquote) {
          blockquote.id = quoteId;
        }

        this.#updateQuoteElements(aside, "chevron-down");
        const title = aside.querySelector(".title");

        if (!title) {
          return;
        }

        // If post/topic is not found then display username, skip controls
        if (aside.classList.contains("quote-post-not-found")) {
          if (aside.dataset.username) {
            title.innerHTML = escape(aside.dataset.username);
          } else {
            title.remove();
          }

          return;
        }

        // Unless it's a full quote, allow click to expand
        if (!aside.dataset.full && !title.dataset.hasQuoteControls) {
          title.addEventListener("click", (e) => {
            if (e.target.closest("a")) {
              return true;
            }

            this.#toggleQuote(aside, helper);
          });

          title.dataset.hasQuoteControls = true;
        }
      }
    });
  }

  #updateQuoteElements(aside, desc) {
    const quoteTitle = i18n("post.follow_quote");
    const postNumber = aside.dataset.post;
    const topicNumber = aside.dataset.topic;

    // If we have a post reference
    let navLink = "";
    if (
      topicNumber &&
      postNumber &&
      topicNumber === this.args.post.topic_id?.toString()
    ) {
      const icon = iconHTML("arrow-up");
      navLink = `<a href='${this.#urlForPostNumber(
        postNumber
      )}' title='${quoteTitle}' class='btn-flat back'>${icon}</a>`;
    }

    // Only add the expand/contract control if it's not a full post
    const titleElement = aside.querySelector(".title");
    let expandContract = "";

    if (!aside.dataset.full) {
      const icon = iconHTML(desc, { title: "post.expand_collapse" });
      const quoteId = aside.querySelector("blockquote")?.id;

      if (quoteId) {
        const isExpanded = aside.dataset.expanded === "true";
        expandContract = `<button aria-controls="${quoteId}" aria-expanded="${isExpanded}" class="quote-toggle btn-flat">${icon}</button>`;

        if (titleElement) {
          titleElement.style.cursor = "pointer";
        }
      }
    }

    if (this.ignoredUsers?.length && titleElement) {
      const username = titleElement.innerText.trim().slice(0, -1);

      if (username.length > 0 && this.ignoredUsers.includes(username)) {
        aside.querySelectorAll("p").forEach((el) => el.remove());
        aside.classList.add("ignored-user");
      }
    }

    const quoteControls = aside.querySelector(".quote-controls");
    if (quoteControls) {
      quoteControls.innerHTML = expandContract + navLink;
    }
  }

  async #toggleQuote(aside, helper) {
    if (this.expanding) {
      return;
    }

    this.expanding = true;
    const blockQuote = aside.querySelector("blockquote");

    if (!blockQuote) {
      return;
    }

    if (aside.dataset.expanded) {
      delete aside.dataset.expanded;
    } else {
      aside.dataset.expanded = true;
    }

    const quoteId = blockQuote.id;

    if (aside.dataset.expanded) {
      this.#updateQuoteElements(aside, "chevron-up");

      // Show expanded quote
      this.originalQuoteContents.set(quoteId, blockQuote.innerHTML);

      const originalText =
        blockQuote.textContent.trim() ||
        this.args.post.cooked.querySelector("blockquote").textContent.trim();

      blockQuote.innerHTML = spinnerHTML;

      const topicId = parseInt(
        aside.dataset.topic || this.args.post.topic_id,
        10
      );
      const postId = parseInt(aside.dataset.post, 10);

      try {
        const result = await ajax(`/posts/by_number/${topicId}/${postId}`);

        const post = this.args.post;
        const quotedPosts = post.quoted || {};
        quotedPosts[result.id] = result;
        post.set("quoted", quotedPosts);

        const div = this.#createDetachedElement("div");
        div.classList.add("expanded-quote");
        div.dataset.postId = result.id;

        helper.renderGlimmer(div, InnerCookedHtml, {
          post,
          cooked: result.cooked,
        });

        // TODO (glimmer-post-stream) shouldn't this be done in the renderGlimmer component above?
        highlightHTML(div, originalText, {
          matchCase: true,
        });

        blockQuote.innerHTML = "";
        blockQuote.appendChild(div);
      } catch (e) {
        if ([403, 404].includes(e.jqXHR.status)) {
          const icon = e.jqXHR.status === 403 ? "lock" : "trash-can";
          blockQuote.innerHTML = `<div class='expanded-quote icon-only'>${iconHTML(
            icon
          )}</div>`;
        }
      }
    } else {
      // Hide expanded quote
      this.#updateQuoteElements(aside, "chevron-down");
      blockQuote.innerHTML = this.originalQuoteContents.get(blockQuote.id);
    }

    this.expanding = false;
  }

  #urlForPostNumber(postNumber) {
    return postNumber > 0
      ? `${this.args.post.topicUrl}/${postNumber}`
      : this.args.post.topicUrl;
  }

  <template>
    <DecoratedHtml
      @className="cooked"
      @decorate={{this.decorateBeforeAdopt}}
      @decorateAfterAdopt={{this.decorateAfterAdopt}}
      @html={{htmlSafe this.cooked}}
      @model={{@post}}
    />
  </template>
}

class InnerCookedHtml extends Component {
  @service appEvents;

  @bind
  decorateBeforeAdopt(element, helper) {
    this.appEvents.trigger(
      "decorate-post-cooked-element:before-adopt",
      element,
      helper
    );
  }

  @bind
  decorateAfterAdopt(element, helper) {
    // this function should only include the trigger to the event below.
    // if in the future we need to add more functionality, we should follow the same pattern
    // as the decorateBeforeAdopt function to prevent applying the other decorations
    // to the inner elements
    this.appEvents.trigger(
      "decorate-post-cooked-element:after-adopt",
      element,
      helper
    );
  }

  <template>
    <DecoratedHtml
      @decorate={{this.decorateBeforeAdopt}}
      @decorateAfterAdopt={{this.decorateAfterAdopt}}
      @html={{htmlSafe @data.cooked}}
      @model={{@data.post}}
    />
  </template>
}
