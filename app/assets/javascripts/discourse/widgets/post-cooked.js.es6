import { iconHTML } from "discourse-common/lib/icon-library";
import { ajax } from "discourse/lib/ajax";
import { isValidLink } from "discourse/lib/click-track";
import { number } from "discourse/lib/formatter";

const _decorators = [];

// Don't call this directly: use `plugin-api/decorateCooked`
export function addDecorator(cb) {
  _decorators.push(cb);
}

export default class PostCooked {
  constructor(attrs, decoratorHelper) {
    this.attrs = attrs;
    this.expanding = false;
    this._highlighted = false;
    this.decoratorHelper = decoratorHelper;
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
    const $html = $(`<div class='cooked'>${this.attrs.cooked}</div>`);
    this._insertQuoteControls($html);
    this._showLinkCounts($html);
    this._fixImageSizes($html);
    this._applySearchHighlight($html);

    _decorators.forEach(cb => cb($html, this.decoratorHelper));
    return $html[0];
  }

  _applySearchHighlight($html) {
    const highlight = this.attrs.highlightTerm;

    if (highlight && highlight.length > 2) {
      if (this._highlighted) {
        $html.unhighlight();
      }
      $html.highlight(highlight.split(/\s+/));
      this._highlighted = true;
    } else if (this._highlighted) {
      $html.unhighlight();
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

      const originalText = $blockQuote.text().trim();
      $blockQuote.html(I18n.t("loading"));
      let topicId = this.attrs.topicId;
      if ($aside.data("topic")) {
        topicId = $aside.data("topic");
      }

      const postId = parseInt($aside.data("post"), 10);
      topicId = parseInt(topicId, 10);

      ajax(`/posts/by_number/${topicId}/${postId}`)
        .then(result => {
          const div = $("<div class='expanded-quote'></div>");
          div.html(result.cooked);
          _decorators.forEach(cb => cb(div, this.decoratorHelper));

          div.highlight(originalText, {
            caseSensitive: true,
            element: "span",
            className: "highlighted"
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
}

PostCooked.prototype.type = "Widget";
