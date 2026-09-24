import { defaultHomepage } from "discourse/lib/utilities";
import Site from "discourse/models/site";
import User from "discourse/models/user";

/**
 * We want / to display one of our discovery routes/controllers, but we don't
 * want to register it as `discovery.index` because that would break themes/plugins which
 * check the route name.
 *
 * Instead, `discovery.index` 'redirects' to a magic URL which we watch for in the router.
 * When detected, we rewrite the URL to `/` before saving it to the Ember router and the browser.
 */
export default function applyRouterHomepageOverrides(router) {
  // eslint-disable-next-line ember/no-private-routing-service
  const microLib = router._routerMicrolib;

  for (const method of ["updateURL", "replaceURL"]) {
    const original = microLib[method].bind(microLib);
    microLib[method] = function (url) {
      url = rewriteIfNeeded(url, this.activeTransition, router.location);
      return original(url);
    };
  }
}

export const homepageRewriteParam = "_discourse_homepage_rewrite";

/**
 * Returns a magic URL which `discovery-index` will redirect to.
 * We watch for this, and then perform the rewrite in the router.
 */
export function homepageDestination() {
  if (serverSideHomepage()) {
    return "/";
  }

  return `${homepagePath()}?${homepageRewriteParam}=1`;
}

export function homepageNavigationDestination() {
  const option = registeredHomepageOption();

  if (!option) {
    return `discovery.${defaultHomepage()}`;
  }

  return option.server_side ? "/" : option.path;
}

export function homepagePreviewDestination() {
  const option = registeredHomepageOption();

  if (!option) {
    return `discovery.${defaultHomepage()}`;
  }

  return option.server_side ? "discovery.latest" : option.path;
}

export function homepagePath() {
  const homepage = defaultHomepage();
  const option = registeredHomepageOption();

  return option?.path || `/${homepage}`;
}

/**
 * The homepage route when a topic list is required. A registered homepage
 * can't serve as one, so this falls back to the first top menu item the
 * current user can see.
 *
 * Use it when leaving a registered homepage, where going "home" would lead
 * straight back.
 *
 * @returns {string}
 */
export function discoveryHomepageRoute() {
  if (!registeredHomepageOption()) {
    return `discovery.${defaultHomepage()}`;
  }

  const site = Site.current();
  const items = site.siteSettings.top_menu
    .split("|")
    .map((item) => item.split(",")[0]);
  const item = User.current()
    ? items[0]
    : items.find((name) => site.anonymous_top_menu_items.includes(name));

  return `discovery.${item ?? "latest"}`;
}

export function serverSideHomepage() {
  return registeredHomepageOption()?.server_side === true;
}

function registeredHomepageOption() {
  const homepage = defaultHomepage();

  return Site.current()?.homepage_options?.find(({ id }) => id === homepage);
}

function rewriteIfNeeded(url, transition, location) {
  const intentUrl = transition?.intent?.url;
  const stayingOnHomepage = isStayingOnRegisteredHomepage(url, location);
  if (
    stayingOnHomepage ||
    (homepageDestination() !== "/" &&
      intentUrl?.startsWith(homepageDestination())) ||
    intentUrl?.startsWith("/login-required") ||
    (transition?.intent.name === `discovery.${defaultHomepage()}` &&
      transition?.intent.queryParams[homepageRewriteParam])
  ) {
    const source = stayingOnHomepage ? url : intentUrl || url;
    const params = source.split("?", 2)[1];
    url = "/";
    if (params) {
      const searchParams = new URLSearchParams(params);
      searchParams.delete(homepageRewriteParam);
      if (searchParams.size) {
        url += `?${searchParams.toString()}`;
      }
    }
  }
  return url;
}

/**
 * While a registered homepage is shown at `/`, navigating to its own path
 * (e.g. the page updating its query params) would otherwise swap `/` for the
 * page's real path.
 */
function isStayingOnRegisteredHomepage(url, location) {
  const option = registeredHomepageOption();

  if (!option || option.server_side) {
    return false;
  }

  const currentPath = location?.getURL?.().split(/[?#]/, 1)[0];

  return currentPath === "/" && url?.split(/[?#]/, 1)[0] === option.path;
}
