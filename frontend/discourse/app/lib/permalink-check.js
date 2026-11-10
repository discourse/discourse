import { ajax } from "discourse/lib/ajax";
import EmbedMode from "discourse/lib/embed-mode";
import DiscourseURL from "discourse/lib/url";

/**
 * Looks up a permalink for `path` and redirects to its target. Returns
 * `{ type: "redirect" }` once handled, or `{ type: "not-found", html }`
 * carrying the server-rendered 404 page.
 *
 * Redirects replace the permalink URL in the back stack: internal targets
 * navigate within the router, external ones full-page (new tab when embedded).
 */
export default async function resolvePermalink(path, transition, router) {
  const results = await ajax("/permalink-check.json", { data: { path } });

  if (!results.found) {
    return { type: "not-found", html: results.html };
  }

  let url = results.target_url;
  if (transition?._discourse_anchor) {
    // Keep the navigation anchor over any anchor already in the target
    url = url.split("#")[0] + `#${transition._discourse_anchor}`;
  }

  if (results.internal) {
    router.replaceWith(url);
    return { type: "redirect" };
  }

  transition?.abort();
  if (EmbedMode.enabled) {
    DiscourseURL.routeTo(url);
  } else {
    DiscourseURL.redirectAbsolute(url, { replace: true });
  }

  return { type: "redirect" };
}
