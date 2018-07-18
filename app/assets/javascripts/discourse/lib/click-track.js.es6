import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { selectedText } from "discourse/lib/utilities";

export function isValidLink($link) {
  return (
    $link.hasClass("track-link") ||
    $link.closest(".hashtag,.badge-category,.onebox-result,.onebox-body")
      .length === 0
  );
}

export default {
  trackClick(e) {
    // cancel click if triggered as part of selection.
    if (selectedText() !== "") {
      return false;
    }

    const $link = $(e.currentTarget);

    // don't track
    //   - lightboxes
    //   - group mentions
    //   - links with disabled tracking
    //   - category links
    //   - quote back button
    if (
      $link.is(".lightbox, .mention-group, .no-track-link, .hashtag, .back")
    ) {
      return true;
    }

    // don't track links in quotes or in elided part
    let tracking = $link.parents("aside.quote, .elided").length === 0;

    let href = $link.attr("href") || $link.data("href");

    if (!href || href.trim().length === 0) {
      return false;
    }
    if (href.indexOf("mailto:") === 0) {
      return true;
    }

    const $article = $link.closest(
      "article:not(.onebox-body), .excerpt, #revisions"
    );
    const postId = $article.data("post-id");
    const topicId = $("#topic").data("topic-id") || $article.data("topic-id");
    const userId = $link.data("user-id") || $article.data("user-id");
    const ownLink = userId && userId === Discourse.User.currentProp("id");

    let destUrl = href;

    if (tracking) {
      destUrl = Discourse.getURL(
        "/clicks/track?url=" + encodeURIComponent(href)
      );

      if (postId && !$link.data("ignore-post-id")) {
        destUrl += "&post_id=" + encodeURI(postId);
      }
      if (topicId) {
        destUrl += "&topic_id=" + encodeURI(topicId);
      }

      // Update badge clicks unless it's our own
      if (!ownLink) {
        const $badge = $("span.badge", $link);
        if ($badge.length === 1) {
          // don't update counts in category badge nor in oneboxes (except when we force it)
          if (isValidLink($link)) {
            const html = $badge.html();
            const key = `${new Date().toLocaleDateString()}-${postId}-${href}`;
            if (/^\d+$/.test(html) && !sessionStorage.getItem(key)) {
              sessionStorage.setItem(key, true);
              $badge.html(parseInt(html, 10) + 1);
            }
          }
        }
      }
    }

    // If they right clicked, change the destination href
    if (e.which === 3) {
      $link.attr(
        "href",
        Discourse.SiteSettings.track_external_right_clicks ? destUrl : href
      );
      return true;
    }

    // if they want to open in a new tab, do an AJAX request
    if (tracking && wantsNewWindow(e)) {
      ajax("/clicks/track", {
        data: {
          url: href,
          post_id: postId,
          topic_id: topicId,
          redirect: false
        },
        dataType: "html"
      });
      return true;
    }

    e.preventDefault();

    // Remove the href, put it as a data attribute
    if (!$link.data("href")) {
      $link.addClass("no-href");
      $link.data("href", $link.attr("href"));
      $link.attr("href", null);
      // Don't route to this URL
      $link.data("auto-route", true);
    }

    // restore href
    setTimeout(() => {
      $link.removeClass("no-href");
      $link.attr("href", $link.data("href"));
      $link.data("href", null);
    }, 50);

    // warn the user if they can't download the file
    if (
      Discourse.SiteSettings.prevent_anons_from_downloading_files &&
      $link.hasClass("attachment") &&
      !Discourse.User.current()
    ) {
      bootbox.alert(I18n.t("post.errors.attachment_download_requires_login"));
      return false;
    }

    const isInternal = DiscourseURL.isInternal(href);

    // If we're on the same site, use the router and track via AJAX
    if (tracking && isInternal && !$link.hasClass("attachment")) {
      ajax("/clicks/track", {
        data: {
          url: href,
          post_id: postId,
          topic_id: topicId,
          redirect: false
        },
        dataType: "html"
      });
      DiscourseURL.routeTo(href);
      return false;
    }

    const modifierLeftClicked = (e.ctrlKey || e.metaKey) && e.which === 1;
    const middleClicked = e.which === 2;
    const openExternalInNewTab = Discourse.User.currentProp(
      "external_links_in_new_tab"
    );

    if (
      modifierLeftClicked ||
      middleClicked ||
      (!isInternal && openExternalInNewTab)
    ) {
      window.open(destUrl, "_blank").focus();
    } else {
      DiscourseURL.redirectTo(destUrl);
    }

    return false;
  }
};
