import {
  findUserBadgesByBadgeId,
  findUserBadgesByUsername,
  grantUserBadge,
  toggleFavoriteUserBadge,
} from "discourse/data/builders/user-badges";
import { normalizeUserBadgesPayload } from "discourse/data/normalize";
import RestCompatModel from "discourse/data/rest-compat";
import { UserBadgeSchema } from "discourse/data/schemas/user-badge";
import {
  defineFieldForwarders,
  requestMany,
  requestOne,
  warpStore,
} from "discourse/data/warp-rest-model";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Badge from "discourse/models/badge";

export default class UserBadge extends RestCompatModel {
  static type = "user-badge";
  static normalize = normalizeUserBadgesPayload;

  // Async so callers can `.then` even on the no-username short circuit
  // (`badges.show` passes a null username for anonymous visitors).
  static async findByUsername(username, options = {}) {
    if (!username) {
      return [];
    }
    return requestMany(this, findUserBadgesByUsername(username, options));
  }

  static findByBadgeId(badgeId, options = {}) {
    return requestMany(this, findUserBadgesByBadgeId(badgeId, options));
  }

  static grant(badgeId, username, reason) {
    return requestOne(this, grantUserBadge(badgeId, username, reason));
  }

  #badge;
  #badgeResource;

  // Wraps the cached resource in a `Badge` so callers can read its computed
  // getters (`.url`, `.badgeTypeClassName`, ...). Memoized against that
  // resource — a fresh instance per read would fire `init` callbacks and break
  // identity — while the unconditional read keeps its tracked tag consumed.
  get badge() {
    const resource = this.__resource?.badge;
    if (resource !== this.#badgeResource) {
      this.#badgeResource = resource;
      this.#badge = resource ? new Badge(resource) : undefined;
    }
    return this.#badge;
  }

  // Getter: null → undefined (test contract).
  get granted_by() {
    return this.__resource?.granted_by ?? undefined;
  }

  // Setter: shadows on the wrapper so admin's read-then-write `groupedBadges`
  // doesn't trip Glimmer.
  set granted_by(value) {
    Object.defineProperty(this, "granted_by", {
      value,
      writable: true,
      configurable: true,
      enumerable: true,
    });
  }

  get grantedAt() {
    return this.granted_at ? Date.parse(this.granted_at) : null;
  }

  get postUrl() {
    if (this.topic_title) {
      return `/t/-/${this.topic_id}/${this.post_number}`;
    }
  }

  // Direct ajax so admin callers can read the response body.
  revoke() {
    return ajax(`/user_badges/${this.id}`, { type: "DELETE" });
  }

  async favorite() {
    const store = warpStore();
    const previous = this.is_favorite;
    const partial = (value) => ({
      data: {
        type: "user-badge",
        id: String(this.id),
        attributes: { is_favorite: value },
      },
    });

    // Optimistic flip. `_adoptCacheRecord` swaps a draft wrapper to the now-
    // cached record so the new value is visible.
    store.push(partial(!previous));
    this._adoptCacheRecord();

    try {
      await store.request(toggleFavoriteUserBadge(this.id));
    } catch (e) {
      store.push(partial(previous));
      popupAjaxError(e);
    }
  }
}

defineFieldForwarders(UserBadge, UserBadgeSchema);
