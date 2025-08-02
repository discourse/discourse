import DiscourseURL from "discourse/lib/url";

const MOUSE_EVENT_PRIMARY_BUTTON_ID = 0;

export function wantsNewWindow(e) {
  return (
    e.defaultPrevented ||
    e.isDefaultPrevented?.() ||
    e.shiftKey ||
    e.metaKey ||
    e.ctrlKey ||
    (e.button && e.button !== MOUSE_EVENT_PRIMARY_BUTTON_ID) ||
    e.currentTarget?.target === "_blank"
  );
}

/**
  Discourse does some server side rendering of HTML, such as the `cooked` contents of
  posts. The downside of this in an Ember app is the links will not go through the router.
  This jQuery code intercepts clicks on those links and routes them properly.
**/
export default function interceptClick(e) {
  const target = e.target.closest("a");

  if (!target) {
    return;
  }

  if (wantsNewWindow(e, target) || target.target === "_blank") {
    return;
  }

  const href = target.getAttribute("href");
  const linkTarget = target.getAttribute("target");
  const targetingOtherFrame = linkTarget && linkTarget !== "_self";

  if (
    !href ||
    href.startsWith("#") ||
    targetingOtherFrame ||
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
    target.closest('[contenteditable="true"]') ||
    (href.match(/^http[s]?:\/\//i) &&
      !href.match(new RegExp("^https?:\\/\\/" + window.location.hostname, "i")))
  ) {
    return;
  }

  e.preventDefault();
  DiscourseURL.routeTo(href);
}
