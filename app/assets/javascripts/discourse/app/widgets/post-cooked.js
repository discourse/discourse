import highlightHTML, { unhighlightHTML } from "discourse/lib/highlight-html";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import highlightSearch from "discourse/lib/highlight-search";
import { iconHTML } from "discourse-common/lib/icon-library";
import { isValidLink } from "discourse/lib/click-track";
import { number } from "discourse/lib/formatter";
import { spinnerHTML } from "discourse/helpers/loading-spinner";

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

  update(prev) {
    if (
      prev.attrs.cooked !== this.attrs.cooked ||
      prev.attrs.highlightTerm !== this.attrs.highlightTerm
    ) {
      return this.init();
    }
  }

  init() {
    const cookedDiv = this._computeCooked();
    const $cookedDiv = $(cookedDiv);

    this._insertQuoteControls($cookedDiv);
    this._showLinkCounts($cookedDiv);
    this._applySearchHighlight($cookedDiv);

    this._decorateAndAdopt(cookedDiv);

    return cookedDiv;
  }

  _decorateAndAdopt(cooked) {
    _beforeAdoptDecorators.forEach((d) => d(cooked, this.decoratorHelper));

    document.adoptNode(cooked);

    _afterAdoptDecorators.forEach((d) => d(cooked, this.decoratorHelper));
  }

  _applySearchHighlight($html) {
    const html = $html[0];
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

  _showLinkCounts($html) {
    const linkCounts = this.attrs.linkCounts;
    if (!linkCounts) {
      return;
    }

    // find the best <a> element in each onebox and display link counts only
    // for that one (the best element is the most significant one to the
    // viewer)
    const bestElements = new Map();
    $html[0].querySelectorAll("aside.onebox").forEach((onebox) => {
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

      $html.find("a[href]").each((i, e) => {
        const $link = $(e);
        const href = $link.attr("href");

        let valid = href === lc.url;

        // this might be an attachment
        if (lc.internal && /^\/uploads\//.test(lc.url)) {
          valid = href.indexOf(lc.url) >= 0;
        }

        // Match server-side behaviour for internal links with query params
        if (lc.internal && /\?/.test(href)) {
          valid = href.split("?")[0] === lc.url;
        }

        // don't display badge counts on category badge & oneboxes (unless when explicitly stated)
        if (valid && isValidLink($link)) {
          const $onebox = $link.closest(".onebox");
          if (
            $onebox.length === 0 ||
            !bestElements.has($onebox[0]) ||
            bestElements.get($onebox[0]) === $link[0]
          ) {
            const title = I18n.t("topic_map.clicks", { count: lc.clicks });
            $link.append(
              ` <span class='badge badge-notification clicks' title='${title}'>${number(
                lc.clicks
              )}</span>`
            );
          }
        }
      });
    });
  }

  _toggleQuote($aside) {
    if (this.expanding) {
      return;
    }

    this.expanding = true;
    const blockQuote = $aside[0].querySelector("blockquote");
    $aside.data("expanded", !$aside.data("expanded"));

    const finished = () => (this.expanding = false);

    if ($aside.data("expanded")) {
      this._updateQuoteElements($aside, "chevron-up");
      // Show expanded quote
      $aside.data("original-contents", blockQuote.innerHTML);

      const originalText =
        blockQuote.textContent.trim() ||
        this.attrs.cooked.querySelector("blockquote").textContent.trim();

      blockQuote.innerHTML = spinnerHTML;

      let topicId = this.attrs.topicId;
      if ($aside.data("topic")) {
        topicId = $aside.data("topic");
      }

      const postId = parseInt($aside.data("post"), 10);
      topicId = parseInt(topicId, 10);

      ajax(`/posts/by_number/${topicId}/${postId}`)
        .then((result) => {
          const post = this.decoratorHelper.getModel();
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
          finished();
        })
        .catch((e) => {
          if ([403, 404].includes(e.jqXHR.status)) {
            const icon = e.jqXHR.status === 403 ? "lock" : "far-trash-alt";
            blockQuote.innerHTML = `<div class='expanded-quote icon-only'>${iconHTML(
              icon
            )}</div>`;
          }
        });
    } else {
      // Hide expanded quote
      this._updateQuoteElements($aside, "chevron-down");
      blockQuote.innerHTML = $aside.data("original-contents");
      finished();
    }
    return false;
  }

  _urlForPostNumber(postNumber) {
    return postNumber > 0
      ? `${this.attrs.topicUrl}/${postNumber}`
      : this.attrs.topicUrl;
  }

  _updateQuoteElements($aside, desc) {
    let navLink = "";
    const quoteTitle = I18n.t("post.follow_quote");
    let postNumber = $aside.data("post");
    let topicNumber = $aside.data("topic");

    // If we have a post reference
    if (topicNumber && topicNumber === this.attrs.topicId && postNumber) {
      let icon = iconHTML("arrow-up");
      navLink = `<a href='${this._urlForPostNumber(
        postNumber
      )}' title='${quoteTitle}' class='btn-flat back'>${icon}</a>`;
    }

    // Only add the expand/contract control if it's not a full post
    let expandContract = "";
    const isExpanded = $aside.data("expanded") === true;
    if (!$aside.data("full")) {
      let icon = iconHTML(desc, { title: "post.expand_collapse" });
      const quoteId = $aside.find("blockquote").attr("id");
      expandContract = `<button aria-controls="${quoteId}" aria-expanded="${isExpanded}" class="quote-toggle btn-flat">${icon}</button>`;
      $(".title", $aside).css("cursor", "pointer");
    }
    if (this.ignoredUsers && this.ignoredUsers.length > 0) {
      const username = $aside.find(".title").text().trim().slice(0, -1);
      if (username.length > 0 && this.ignoredUsers.includes(username)) {
        $aside.find("p").remove();
        $aside.addClass("ignored-user");
      }
    }
    $(".quote-controls", $aside).html(expandContract + navLink);
  }

  _insertQuoteControls($html) {
    const $quotes = $html.find("aside.quote");
    if ($quotes.length === 0) {
      return;
    }

    $quotes.each((index, e) => {
      const $aside = $(e);
      if ($aside.data("post")) {
        const quoteId = `quote-id-${$aside.data("topic")}-${$aside.data(
          "post"
        )}-${index}`;
        $aside.find("blockquote").attr("id", quoteId);

        this._updateQuoteElements($aside, "chevron-down");
        const $title = $(".title", $aside);

        // Unless it's a full quote, allow click to expand
        if (!($aside.data("full") || $title.data("has-quote-controls"))) {
          $title.on("click", (e2) => {
            let $target = $(e2.target);
            if ($target.closest("a").length) {
              return true;
            }
            this._toggleQuote($aside);
          });
          $title.data("has-quote-controls", true);
        }
      }
    });
  }

  _computeCooked() {
    const cookedDiv = createDetachedElement("div");
    cookedDiv.classList.add("cooked");

    if (
      (this.attrs.firstPost || this.attrs.embeddedPost) &&
      this.ignoredUsers &&
      this.ignoredUsers.length > 0 &&
      this.ignoredUsers.includes(this.attrs.username)
    ) {
      cookedDiv.classList.add("post-ignored");
      cookedDiv.innerHTML = I18n.t("post.ignored");
    } else {
      cookedDiv.innerHTML = this.attrs.cooked;
    }

    return cookedDiv;
  }
}

PostCooked.prototype.type = "Widget";
