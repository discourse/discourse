/**
 * Finds the link in a sidebar section that corresponds to the page being
 * viewed. Sections use it to know whether they hold the current page, which
 * drives expanding a collapsed section and scrolling the row into view.
 *
 * Route-backed links are matched through the router; links that only carry a
 * URL — user-built custom sections store their links that way — are matched
 * against the current URL instead.
 *
 * @param {Object[]} links - the section's links
 * @param {RouterService} router
 * @returns {Object|undefined} the matching link, if any
 */
/**
 * Whether one link corresponds to the page being viewed. The router throws for
 * a route it does not know, and is not always a full router service — in
 * rendering tests it is a stand-in — so every lookup goes through here.
 *
 * @param {Object} link
 * @param {RouterService} router
 * @returns {boolean}
 */
export function isActiveLink(link, router) {
  try {
    const currentWhen = link.currentWhen;

    if (typeof currentWhen === "boolean") {
      return currentWhen;
    }

    const href = link.href ?? link.value;

    if (!link.route && href) {
      return router.currentURL === href;
    }

    const queryParams = link.query || {};
    let models;

    if (link.model) {
      models = [link.model];
    } else if (link.models) {
      models = link.models;
    } else {
      models = [];
    }

    if (typeof currentWhen === "string") {
      return currentWhen
        .split(" ")
        .some((route) => router.isActive(route, ...models, { queryParams }));
    }

    return router.isActive(link.route, ...models, { queryParams });
  } catch {
    // false if ember throws an exception while checking the routes
    return false;
  }
}

export function findActiveLink(links, router) {
  if (!links?.length) {
    return;
  }

  return links.find((link) => isActiveLink(link, router));
}
