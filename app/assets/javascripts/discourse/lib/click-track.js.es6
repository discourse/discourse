import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { selectedText } from "discourse/lib/utilities";

export function isValidLink($link) {
  // Do not track:
  //  - lightboxes
  //  - group mentions
  //  - links with disabled tracking
  //  - category links
  //  - quote back button
  if ($link.is(".lightbox, .mention-group, .no-track-link, .hashtag, .back")) {
    return false;
  }

  // Do not track links in quotes or in elided part
  if ($link.parents("aside.quote, .elided").length !== 0) {
    return false;
  }

  return (
    $link.hasClass("track-link") ||
    $link.closest(".hashtag, .badge-category, .onebox-result, .onebox-body")
      .length === 0
  );
}

export default {
  trackClick(e) {
    // right clicks are not tracked
    if (e.which === 3) {
      return true;
    }

    // Cancel click if triggered as part of selection.
    const selection = window.getSelection();
    if (selection.type === "Range" || selection.rangeCount > 0) {
      if (selectedText() !== "") {
        return true;
      }
    }

    const $link = $(e.currentTarget);
    if (!isValidLink($link)) {
      return true;
    }

    if ($link.hasClass("attachment")) {
      // Warn the user if they cannot download the file.
      if (
        Discourse.SiteSettings.prevent_anons_from_downloading_files &&
        !Discourse.User.current()
      ) {
        bootbox.alert(I18n.t("post.errors.attachment_download_requires_login"));
        return false;
      }

      return true;
    }

    let href = ($link.attr("href") || $link.data("href")).trim();
    if (!href) {
      return false;
    } else if (href.indexOf("mailto:") === 0) {
      return true;
    }

    const $article = $link.closest(
      "article:not(.onebox-body), .excerpt, #revisions"
    );
    const postId = $article.data("post-id");
    const topicId = $("#topic").data("topic-id") || $article.data("topic-id");
    const userId = $link.data("user-id") || $article.data("user-id");
    const ownLink = userId && userId === Discourse.User.currentProp("id");

    // Update badge clicks unless it's our own.
    if (!ownLink) {
      const $badge = $("span.badge", $link);
      if ($badge.length === 1) {
        const html = $badge.html();
        const key = `${new Date().toLocaleDateString()}-${postId}-${href}`;
        if (/^\d+$/.test(html) && !sessionStorage.getItem(key)) {
          sessionStorage.setItem(key, true);
          $badge.html(parseInt(html, 10) + 1);
        }
      }
    }

    const trackPromise = ajax("/clicks/track", {
      data: {
        url: href,
        post_id: postId,
        topic_id: topicId
      }
    });

    const isInternal = DiscourseURL.isInternal(href);
    const openExternalInNewTab = Discourse.User.currentProp(
      "external_links_in_new_tab"
    );

    if (!wantsNewWindow(e)) {
      if (!isInternal && openExternalInNewTab) {
        window.open(href, "_blank").focus();

        // Hack to prevent changing current window.location.
        // e.preventDefault() does not work.
        if (!$link.data("href")) {
          $link.addClass("no-href");
          $link.data("href", $link.attr("href"));
          $link.attr("href", null);
          $link.data("auto-route", true);

          Ember.run.later(() => {
            $link.removeClass("no-href");
            $link.attr("href", $link.data("href"));
            $link.data("href", null);
            $link.data("auto-route", null);
          }, 50);
        }
      } else {
        trackPromise.finally(() => {
          if (isInternal) {
            DiscourseURL.routeTo(href);
          } else {
            DiscourseURL.redirectTo(href);
          }
        });
      }

      return false;
    }

    return true;
  }
};
