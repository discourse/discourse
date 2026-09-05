import { ajax } from "discourse/lib/ajax";
import DiscourseURL from "discourse/lib/url";

/**
 * Follows a permalink for `path`, if one exists, redirecting to its target.
 * Returns `{ type: "redirect" }` once handled, otherwise a `{ type:
 * "not-found", html }` result carrying the server-rendered 404 page.
 */
export default async function resolvePermalink(path, transition) {
  const results = await ajax("/permalink-check.json", { data: { path } });

  if (!results.found) {
    return { type: "not-found", html: results.html };
  }

  transition?.abort();

  let url = results.target_url;
  if (transition?._discourse_anchor) {
    // Remove the anchor from the permalink if present
    url = url.split("#")[0];

    // Add the anchor from the transition
    url += `#${transition._discourse_anchor}`;
  }

  DiscourseURL.routeTo(url);

  return { type: "redirect" };
}
