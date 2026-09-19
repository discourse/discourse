import { getOwner } from "@ember/owner";
import { ajax } from "discourse/lib/ajax";

/**
 * Saves an anonymous user's intended action server-side (in a short-lived
 * signed cookie) and redirects them to login. After they authenticate, the
 * matching `AnonymousAction` handler runs against their account and the
 * cookie is cleared.
 *
 * Example:
 *
 *   if (!this.currentUser) {
 *     return deferAnonymousAction(this, "like_post", {
 *       post_id: this.args.post.id,
 *     });
 *   }
 */
export async function deferAnonymousAction(caller, type, params = {}) {
  try {
    await ajax("/anonymous-action", {
      type: "POST",
      data: { type, params },
    });
  } catch {
    // If saving the intent fails, the user can still authenticate — they'll
    // just have to re-trigger the action after login.
  }
  getOwner(caller).lookup("route:application").send("showLogin");
}
