import DiscourseURL from "discourse/lib/url";

export function wantsNewWindow(e, target) {
  return (
    e.defaultPrevented ||
    e.shiftKey ||
    e.metaKey ||
    e.ctrlKey ||
    (e.button && e.button !== 0) ||
    target?.target === "_blank"
  );
}

/**
  Discourse does some server side rendering of HTML, such as the `cooked` contents of
  posts. The downside of this in an Ember app is the links will not go through the router.
  This code intercepts clicks on those links and routes them properly.
**/
export default function interceptClick(event, target) {
  if (wantsNewWindow(event, target)) {
    return;
  }

  const href = target.getAttribute("href");

  if (
    !href ||
    href.startsWith("#") ||
    target.getAttribute("target") ||
    target.dataset.emberAction ||
    target.dataset.autoRoute ||
    target.dataset.shareUrl ||
    target.classList.contains("widget-link") ||
    target.classList.contains("raw-link") ||
    target.classList.contains("mention") ||
    (!target.classList.contains("d-link") &&
      !target.dataset.userCard &&
      target.classList.contains("ember-view")) ||
    target.classList.contains("lightbox") ||
    href.startsWith("mailto:") ||
    (href.match(/^http[s]?:\/\//i) &&
      !href.match(new RegExp("^https?:\\/\\/" + window.location.hostname, "i")))
  ) {
    return;
  }

  event.preventDefault();
  event.stopPropagation();

  DiscourseURL.routeTo(href);
}
