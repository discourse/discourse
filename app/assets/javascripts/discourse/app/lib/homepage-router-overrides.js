import { defaultHomepage } from "discourse/lib/utilities";

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

const homepageRewriteParam = "_discourse_homepage_rewrite";

/**
 * Returns a magic URL which `discovery-index` will redirect to.
 * We watch for this, and then perform the rewrite in the router.
 */
export function homepageDestination() {
  return `/${defaultHomepage()}?${homepageRewriteParam}=1`;
}

function rewriteIfNeeded(url, transition) {
  const { intent } = transition || {};
  const { url: intentUrl, name, queryParams } = intent || {};

  const isHomepageUrl = intentUrl?.startsWith(homepageDestination());
  const isHomepageRoute = name === `discovery.${defaultHomepage()}`;
  const hasRewriteParam = queryParams?.[homepageRewriteParam];

  if (isHomepageUrl || (isHomepageRoute && hasRewriteParam)) {
    const urlParams = new URLSearchParams((intentUrl || url).split("?", 2)[1]);

    if (queryParams) {
      for (const [key, value] of Object.entries(queryParams)) {
        if (value !== null && value !== undefined) {
          urlParams.set(key, value);
        }
      }
    }

    urlParams.delete(homepageRewriteParam);

    url = urlParams.size > 0 ? `/?${urlParams}` : "/";
  }

  return url;
}
