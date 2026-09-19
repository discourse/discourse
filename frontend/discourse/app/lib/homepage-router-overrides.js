import { defaultHomepage } from "discourse/lib/utilities";
import Site from "discourse/models/site";

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
      url = rewriteIfNeeded(url, this.activeTransition);
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

export function serverSideHomepage() {
  return registeredHomepageOption()?.server_side === true;
}

function registeredHomepageOption() {
  const homepage = defaultHomepage();

  return Site.current()?.homepage_options?.find(({ id }) => id === homepage);
}

function rewriteIfNeeded(url, transition) {
  const intentUrl = transition?.intent?.url;
  if (
    (homepageDestination() !== "/" &&
      intentUrl?.startsWith(homepageDestination())) ||
    intentUrl?.startsWith("/login-required") ||
    (transition?.intent.name === `discovery.${defaultHomepage()}` &&
      transition?.intent.queryParams[homepageRewriteParam])
  ) {
    const params = (intentUrl || url).split("?", 2)[1];
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
