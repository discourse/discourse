/**
 * Helpers for the route matchers a sidebar panel's `mobileTab` gives the
 * mobile tab bar (see `BaseCustomSidebarPanel#mobileTab`).
 */

/**
 * @param {Object} routeInfo
 * @param {...string} names Route names.
 * @returns {boolean} Whether the route is one of the named routes or sits
 * below one, as `chat.channel.index` sits below `chat`.
 */
export function routeWithin(routeInfo, ...names) {
  const name = routeInfo?.name ?? "";
  return names.some((n) => name === n || name.startsWith(`${n}.`));
}

/**
 * @param {Object} routeInfo
 * @param {string} name A route name.
 * @returns {Object|undefined} The route or its ancestor with the name, whose
 * `attributes` hold its model, as a topic route's hold the topic.
 */
export function findRoute(routeInfo, name) {
  for (let route = routeInfo; route; route = route.parent) {
    if (route.name === name) {
      return route;
    }
  }
}
