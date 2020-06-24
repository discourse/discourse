import I18n from "I18n";
import { iconHTML } from "discourse-common/lib/icon-library";
import { ajax } from "discourse/lib/ajax";
import { isValidLink } from "discourse/lib/click-track";
import { number } from "discourse/lib/formatter";
import highlightSearch from "discourse/lib/highlight-search";
import {
  default as highlightHTML,
  unhighlightHTML
} from "discourse/lib/highlight-html";

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
    this._fixImageSizes($cookedDiv);
    this._applySearchHighlight($cookedDiv);

    this._decorateAndAdopt(cookedDiv);

    return cookedDiv;
  }

  _decorateAndAdopt(cooked) {
    _beforeAdoptDecorators.forEach(d => d(cooked, this.decoratorHelper));

    document.adoptNode(cooked);

    _afterAdoptDecorators.forEach(d => d(cooked, this.decoratorHelper));
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

  _fixImageSizes($html) {
    const maxImageWidth = Discourse.SiteSettings.max_image_width;
    const maxImageHeight = Discourse.SiteSettings.max_image_height;

    let maxWindowWidth;
    $html.find("img:not(.avatar)").each((idx, img) => {
      // deferring work only for posts with images
      // we got to use screen here, cause nothing is rendered yet.
      // long term we may want to allow for weird margins that are enforced, instead of hardcoding at 70/20
      maxWindowWidth =
        maxWindowWidth || $(window).width() - (this.attrs.mobileView ? 20 : 70);
      if (maxImageWidth < maxWindowWidth) {
        maxWindowWidth = maxImageWidth;
      }

      const aspect = img.height / img.width;
      if (img.width > maxWindowWidth) {
        img.width = maxWindowWidth;
        img.height = parseInt(maxWindowWidth * aspect, 10);
      }

      // very unlikely but lets fix this too
      if (img.height > maxImageHeight) {
        img.height = maxImageHeight;
        img.width = parseInt(maxWindowWidth / aspect, 10);
      }
    });
  }

  _showLinkCounts($html) {
    const linkCounts = this.attrs.linkCounts;
    if (!linkCounts) {
      return;
    }

    linkCounts.forEach(lc => {
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

        // don't display badge counts on category badge & oneboxes (unless when explicitely stated)
        if (valid && isValidLink($link)) {
          const title = I18n.t("topic_map.clicks", { count: lc.clicks });
          $link.append(
            ` <span class='badge badge-notification clicks' title='${title}'>${number(
              lc.clicks
            )}</span>`
          );
        }
      });
    });
  }

  _toggleQuote($aside) {
    if (this.expanding) {
      return;
    }

    this.expanding = true;

    $aside.data("expanded", !$aside.data("expanded"));

    const finished = () => (this.expanding = false);

    if ($aside.data("expanded")) {
      this._updateQuoteElements($aside, "chevron-up");
      // Show expanded quote
      const $blockQuote = $("> blockquote", $aside);
      $aside.data("original-contents", $blockQuote.html());

      const originalText =
        $blockQuote.text().trim() ||
        $("> blockquote", this.attrs.cooked)
          .text()
          .trim();
      $blockQuote.html(I18n.t("loading"));
      let topicId = this.attrs.topicId;
      if ($aside.data("topic")) {
        topicId = $aside.data("topic");
      }

      const postId = parseInt($aside.data("post"), 10);
      topicId = parseInt(topicId, 10);

      ajax(`/posts/by_number/${topicId}/${postId}`)
        .then(result => {
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
            matchCase: true
          });
          $blockQuote.showHtml(div, "fast", finished);
        })
        .catch(e => {
          if ([403, 404].includes(e.jqXHR.status)) {
            const icon = e.jqXHR.status === 403 ? "lock" : "far-trash-alt";
            $blockQuote.showHtml(
              $(`<div class='expanded-quote'>${iconHTML(icon)}</div>`),
              "fast",
              finished
            );
          }
        });
    } else {
      // Hide expanded quote
      this._updateQuoteElements($aside, "chevron-down");
      $("blockquote", $aside).showHtml(
        $aside.data("original-contents"),
        "fast",
        finished
      );
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
      )}' title='${quoteTitle}' class='back'>${icon}</a>`;
    }

    // Only add the expand/contract control if it's not a full post
    let expandContract = "";
    if (!$aside.data("full")) {
      expandContract = iconHTML(desc, { title: "post.expand_collapse" });
      $(".title", $aside).css("cursor", "pointer");
    }
    if (this.ignoredUsers && this.ignoredUsers.length > 0) {
      const username = $aside
        .find(".title")
        .text()
        .trim()
        .slice(0, -1);
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

    $quotes.each((i, e) => {
      const $aside = $(e);
      if ($aside.data("post")) {
        this._updateQuoteElements($aside, "chevron-down");
        const $title = $(".title", $aside);

        // Unless it's a full quote, allow click to expand
        if (!($aside.data("full") || $title.data("has-quote-controls"))) {
          $title.on("click", e2 => {
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
