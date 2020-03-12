import DiscourseURL from "discourse/lib/url";

export function wantsNewWindow(e) {
  return (
    e.isDefaultPrevented() ||
    e.shiftKey ||
    e.metaKey ||
    e.ctrlKey ||
    (e.button && e.button !== 0) ||
    (e.target && e.target.target === "_blank")
  );
}

/**
  Discourse does some server side rendering of HTML, such as the `cooked` contents of
  posts. The downside of this in an Ember app is the links will not go through the router.
  This jQuery code intercepts clicks on those links and routes them properly.
**/
export default function interceptClick(e) {
  if (wantsNewWindow(e)) {
    return;
  }

  const $currentTarget = $(e.currentTarget),
    href = $currentTarget.attr("href");

  if (
    !href ||
    href === "#" ||
    $currentTarget.attr("target") ||
    $currentTarget.data("ember-action") ||
    $currentTarget.data("auto-route") ||
    $currentTarget.data("share-url") ||
    $currentTarget.hasClass("widget-link") ||
    $currentTarget.hasClass("raw-link") ||
    $currentTarget.hasClass("mention") ||
    (!$currentTarget.hasClass("d-link") &&
      !$currentTarget.data("user-card") &&
      $currentTarget.hasClass("ember-view")) ||
    $currentTarget.hasClass("lightbox") ||
    href.indexOf("mailto:") === 0 ||
    (href.match(/^http[s]?:\/\//i) &&
      !href.match(new RegExp("^https?:\\/\\/" + window.location.hostname, "i")))
  ) {
    return;
  }

  e.preventDefault();
  DiscourseURL.routeTo(href);
  return false;
}
