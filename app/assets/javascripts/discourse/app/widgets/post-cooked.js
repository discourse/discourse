import { spinnerHTML } from "discourse/helpers/loading-spinner";
import { ajax } from "discourse/lib/ajax";
import { isValidLink } from "discourse/lib/click-track";
import { number } from "discourse/lib/formatter";
import highlightHTML, { unhighlightHTML } from "discourse/lib/highlight-html";
import highlightSearch from "discourse/lib/highlight-search";
import { applyValueTransformer } from "discourse/lib/transformer";
import {
  destroyUserStatusOnMentions,
  updateUserStatusOnMention,
} from "discourse/lib/update-user-status-on-mention";
import escape from "discourse-common/lib/escape";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import getURL from "discourse-common/lib/get-url";
import { iconHTML } from "discourse-common/lib/icon-library";
import { i18n } from "discourse-i18n";

let _beforeAdoptDecorators = [];
let _afterAdoptDecorators = [];

// Don't call this directly: use `plugin-api/decorateCookedElement`
export function addDecorator(callback, { afterAdopt = false } = {}) {
  if (afterAdopt) {
    _afterAdoptDecorators.push(callback);
  } else {
    _beforeAdoptDecorators.push(callback);
  }
}

export function resetDecorators() {
  _beforeAdoptDecorators = [];
  _afterAdoptDecorators = [];
}

let detachedDocument = document.implementation.createHTMLDocument("detached");

function createDetachedElement(nodeName) {
  return detachedDocument.createElement(nodeName);
}

export default class PostCooked {
  originalQuoteContents = null;

  constructor(attrs, decoratorHelper, currentUser) {
    this.attrs = attrs;
    this.expanding = false;
    this._highlighted = false;
    this.decoratorHelper = decoratorHelper;
    this.currentUser = currentUser;
    this.ignoredUsers = this.currentUser
      ? this.currentUser.ignored_users
      : null;
  }

  init() {
    this.originalQuoteContents = null;
    // todo should be a better way of detecting if it is composer preview
    this._isInComposerPreview = !this.decoratorHelper;

    this.cookedDiv = this._computeCooked();

    this._insertQuoteControls(this.cookedDiv);
    this._showLinkCounts(this.cookedDiv);
    this._applySearchHighlight(this.cookedDiv);
    this._decorateMentions();
    this._decorateAndAdopt(this.cookedDiv);

    return this.cookedDiv;
  }

  update(prev) {
    if (
      prev.attrs.cooked !== this.attrs.cooked ||
      prev.attrs.highlightTerm !== this.attrs.highlightTerm
    ) {
      return this.init();
    }
  }

  destroy() {
    this._stopTrackingMentionedUsersStatus();
    destroyUserStatusOnMentions();
  }

  _decorateAndAdopt(cooked) {
    _beforeAdoptDecorators.forEach((d) => d(cooked, this.decoratorHelper));

    document.adoptNode(cooked);

    _afterAdoptDecorators.forEach((d) => d(cooked, this.decoratorHelper));
  }

  _applySearchHighlight(html) {
    const highlight = this.attrs.highlightTerm;

    if (highlight && highlight.length > 2) {
      if (this._highlighted) {
        unhighlightHTML(html);
      }

      highlightSearch(html, highlight, { defaultClassName: true });
      this._highlighted = true;
    } else if (this._highlighted) {
      unhighlightHTML(html);
      this._highlighted = false;
    }
  }

  _showLinkCounts(html) {
    const linkCounts = this.attrs.linkCounts;
    if (!linkCounts) {
      return;
    }

    // find the best <a> element in each onebox and display link counts only
    // for that one (the best element is the most significant one to the
    // viewer)
    const bestElements = new Map();
    html.querySelectorAll("aside.onebox").forEach((onebox) => {
      // look in headings first
      for (let i = 1; i <= 6; ++i) {
        const hLinks = onebox.querySelectorAll(`h${i} a[href]`);
        if (hLinks.length > 0) {
          bestElements.set(onebox, hLinks[0]);
          return;
        }
      }

      // use the header otherwise
      const hLinks = onebox.querySelectorAll("header a[href]");
      if (hLinks.length > 0) {
        bestElements.set(onebox, hLinks[0]);
      }
    });

    linkCounts.forEach((lc) => {
      if (!lc.clicks || lc.clicks < 1) {
        return;
      }

      html.querySelectorAll("a[href]").forEach((link) => {
        const href = link.getAttribute("href");
        let valid = href === lc.url;

        // this might be an attachment
        if (lc.internal && /^\/uploads\//.test(lc.url)) {
          valid = href.includes(lc.url);
        }

        // match server-side behavior for internal links with query params
        if (lc.internal && /\?/.test(href)) {
          valid = href.split("?")[0] === lc.url;
        }

        // don't display badge counts on category badge & oneboxes (unless when explicitly stated)
        if (valid && isValidLink(link)) {
          const onebox = link.closest(".onebox");

          if (
            !onebox ||
            !bestElements.has(onebox) ||
            bestElements.get(onebox) === link
          ) {
            link.setAttribute("data-clicks", number(lc.clicks));
            const ariaLabel = `${link.textContent.trim()} ${i18n(
              "post.link_clicked",
              {
                count: lc.clicks,
              }
            )}`;
            link.setAttribute("aria-label", ariaLabel);
          }
        }
      });
    });
  }

  async _toggleQuote(aside) {
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
      this._updateQuoteElements(aside, "chevron-up");

      // Show expanded quote
      this.originalQuoteContents.set(quoteId, blockQuote.innerHTML);

      const originalText =
        blockQuote.textContent.trim() ||
        this.attrs.cooked.querySelector("blockquote").textContent.trim();

      blockQuote.innerHTML = spinnerHTML;

      const topicId = parseInt(aside.dataset.topic || this.attrs.topicId, 10);
      const postId = parseInt(aside.dataset.post, 10);

      try {
        const result = await ajax(`/posts/by_number/${topicId}/${postId}`);

        const post = this._post();
        const quotedPosts = post.quoted || {};
        quotedPosts[result.id] = result;
        post.set("quoted", quotedPosts);

        const div = createDetachedElement("div");
        div.classList.add("expanded-quote");
        div.dataset.postId = result.id;
        div.innerHTML = result.cooked;

        this._decorateAndAdopt(div);

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
      this._updateQuoteElements(aside, "chevron-down");
      blockQuote.innerHTML = this.originalQuoteContents.get(blockQuote.id);
    }

    this.expanding = false;
  }

  _urlForPostNumber(postNumber) {
    return postNumber > 0
      ? `${this.attrs.topicUrl}/${postNumber}`
      : this.attrs.topicUrl;
  }

  _updateQuoteElements(aside, desc) {
    const quoteTitle = i18n("post.follow_quote");
    const postNumber = aside.dataset.post;
    const topicNumber = aside.dataset.topic;

    // If we have a post reference
    let navLink = "";
    if (
      topicNumber &&
      postNumber &&
      topicNumber === this.attrs.topicId?.toString()
    ) {
      const icon = iconHTML("arrow-up");
      navLink = `<a href='${this._urlForPostNumber(
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

  _insertQuoteControls(html) {
    const quotes = html.querySelectorAll("aside.quote");
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

        this._updateQuoteElements(aside, "chevron-down");
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

            this._toggleQuote(aside);
          });

          title.dataset.hasQuoteControls = true;
        }
      }
    });
  }

  _computeCooked() {
    const cookedDiv = createDetachedElement("div");
    cookedDiv.classList.add("cooked");

    if (
      (this.attrs.firstPost || this.attrs.embeddedPost) &&
      this.ignoredUsers?.includes?.(this.attrs.username)
    ) {
      cookedDiv.classList.add("post-ignored");
      cookedDiv.innerHTML = i18n("post.ignored");
    } else {
      cookedDiv.innerHTML = this.attrs.cooked;
    }

    return cookedDiv;
  }

  _decorateMentions() {
    if (!this._isInComposerPreview) {
      destroyUserStatusOnMentions();
    }

    this._extractMentions().forEach(({ mentions, user }) => {
      if (!this._isInComposerPreview) {
        this._trackMentionedUserStatus(user);
        this._rerenderUserStatusOnMentions(mentions, user);
      }

      const classes = applyValueTransformer("mentions-class", [], {
        user,
      });

      mentions.forEach((mention) => {
        mention.classList.add(...classes);
      });
    });
  }

  _rerenderUserStatusOnMentions(mentions, user) {
    mentions.forEach((mention) => {
      updateUserStatusOnMention(
        getOwnerWithFallback(this),
        mention,
        user.status
      );
    });
  }

  _rerenderUsersStatusOnMentions() {
    this._extractMentions().forEach(({ mentions, user }) => {
      this._rerenderUserStatusOnMentions(mentions, user);
    });
  }

  _extractMentions() {
    return (
      this._post()?.mentioned_users?.map((user) => {
        const href = getURL(`/u/${user.username.toLowerCase()}`);
        const mentions = this.cookedDiv.querySelectorAll(
          `a.mention[href="${href}"]`
        );

        return { user, mentions };
      }) || []
    );
  }

  _trackMentionedUserStatus(user) {
    user.statusManager?.trackStatus?.();
    user.on?.("status-changed", this, "_rerenderUsersStatusOnMentions");
  }

  _stopTrackingMentionedUsersStatus() {
    this._post()?.mentioned_users?.forEach((user) => {
      user.statusManager?.stopTrackingStatus?.();
      user.off?.("status-changed", this, "_rerenderUsersStatusOnMentions");
    });
  }

  _post() {
    return this.decoratorHelper?.getModel?.();
  }
}

PostCooked.prototype.type = "Widget";
