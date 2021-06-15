import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import { Promise } from "rsvp";
import User from "discourse/models/user";
import { ajax } from "discourse/lib/ajax";
import bootbox from "bootbox";
import getURL, { samePrefix } from "discourse-common/lib/get-url";
import { isTesting } from "discourse-common/config/environment";
import { later } from "@ember/runloop";
import { selectedText } from "discourse/lib/utilities";
import { wantsNewWindow } from "discourse/lib/intercept-click";

export function isValidLink($link) {
  // .hashtag == category/tag link
  // .back == quote back ^ button
  if ($link.is(".lightbox, .no-track-link, .hashtag, .back")) {
    return false;
  }

  if ($link.parents("aside.quote, .elided, .expanded-embed").length !== 0) {
    return false;
  }

  if ($link.closest(".onebox-result, .onebox-body").length) {
    const $a = $link.closest(".onebox").find("header a");
    if ($a[0] && $a[0].href === $link[0].href) {
      return true;
    }
  }

  return (
    $link.hasClass("track-link") ||
    $link.closest(".hashtag, .badge-category, .onebox-result, .onebox-body")
      .length === 0
  );
}

export function shouldOpenInNewTab(href) {
  const isInternal = DiscourseURL.isInternal(href);
  const openExternalInNewTab = User.currentProp("external_links_in_new_tab");
  return !isInternal && openExternalInNewTab;
}

export function openLinkInNewTab(link) {
  let href = (link.href || link.dataset.href || "").trim();
  if (href === "") {
    return;
  }

  const newWindow = window.open(href, "_blank");
  newWindow.opener = null;
  newWindow.focus();

  // Hack to prevent changing current window.location.
  // e.preventDefault() does not work.
  if (!link.dataset.href) {
    link.classList.add("no-href");
    link.dataset.href = link.href;
    link.dataset.autoRoute = true;
    link.removeAttribute("href");

    later(() => {
      if (link) {
        link.classList.remove("no-href");
        link.setAttribute("href", link.dataset.href);
        delete link.dataset.href;
        delete link.dataset.autoRoute;
      }
    }, 50);
  }
}

export default {
  trackClick(e, siteSettings, { returnPromise = false } = {}) {
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
    const tracking = isValidLink($link);

    // Return early for mentions and group mentions
    if ($link.is(".mention, .mention-group")) {
      return true;
    }

    let href = ($link.attr("href") || $link.data("href") || "").trim();
    if (!href || href.indexOf("mailto:") === 0) {
      return true;
    }

    if ($link.hasClass("attachment")) {
      // Warn the user if they cannot download the file.
      if (
        siteSettings &&
        siteSettings.prevent_anons_from_downloading_files &&
        !User.current()
      ) {
        bootbox.alert(I18n.t("post.errors.attachment_download_requires_login"));
      } else if (wantsNewWindow(e)) {
        const newWindow = window.open(href, "_blank");
        newWindow.opener = null;
        newWindow.focus();
      } else {
        DiscourseURL.redirectTo(href);
      }
      return false;
    }

    const $article = $link.closest(
      "article:not(.onebox-body), .excerpt, #revisions"
    );
    const postId = $article.data("post-id");
    const topicId = $("#topic").data("topic-id") || $article.data("topic-id");
    const userId = $link.data("user-id") || $article.data("user-id");
    const ownLink = userId && userId === User.currentProp("id");

    // Update badge clicks unless it's our own.
    if (tracking && !ownLink) {
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

    let trackPromise = Promise.resolve();
    if (tracking) {
      if (!isTesting() && navigator.sendBeacon) {
        const data = new FormData();
        data.append("url", href);
        data.append("post_id", postId);
        data.append("topic_id", topicId);
        navigator.sendBeacon(getURL("/clicks/track"), data);
      } else {
        trackPromise = ajax(getURL("/clicks/track"), {
          type: "POST",
          data: {
            url: href,
            post_id: postId,
            topic_id: topicId,
          },
        });
      }
    }

    if (!wantsNewWindow(e)) {
      if (shouldOpenInNewTab(href)) {
        openLinkInNewTab($link[0]);
      } else {
        trackPromise.finally(() => {
          if (DiscourseURL.isInternal(href) && samePrefix(href)) {
            DiscourseURL.routeTo(href);
          } else {
            DiscourseURL.redirectAbsolute(href);
          }
        });
      }

      return returnPromise ? trackPromise : false;
    }

    return returnPromise ? trackPromise : true;
  },
};
