import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";

/**
 * Follows a permalink for `path`, if one exists, redirecting to its target.
 * Internal targets are redirected within the router so the transition is
 * tracked; external ones navigate via `DiscourseURL` after aborting the
 * current transition. Returns `{ type: "redirect" }` once handled, otherwise a
 * `{ type: "not-found", html }` result carrying the server-rendered 404 page.
 */
export default async function resolvePermalink(path, transition, router) {
  const results = await ajax("/permalink-check.json", { data: { path } });

  if (!results.found) {
    return { type: "not-found", html: results.html };
  }

  let url = results.target_url;
  if (transition?._discourse_anchor) {
    // Remove the anchor from the permalink if present
    url = url.split("#")[0];

    // Add the anchor from the transition
    url += `#${transition._discourse_anchor}`;
  }

  if (results.internal) {
    // Redirect within the routing system so the transition is tracked
    router.replaceWith(url);
    return { type: "redirect" };
  }

  // Avoid polluting the history stack for external links
  transition?.abort();
  DiscourseURL.routeTo(url);

  return { type: "redirect" };
}
