import { dependentKeyCompat } from "@ember/object/compat";
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
import Topic from "discourse/models/topic";
import User from "discourse/models/user";

// Restores the setter these getters displace, shadowing the getter from then
// on so admin's read-then-write `groupedBadges` doesn't trip Glimmer.
function shadow(instance, name, value) {
  Object.defineProperty(instance, name, {
    value,
    writable: true,
    configurable: true,
    enumerable: true,
  });
}

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

  #wrappers = new Map();

  // Consumers read class getters off these (`badge.url`, `topic.fancyTitle`,
  // `user.statusManager`), which the cached plain objects lack. Copy before
  // wrapping — `RestModel.create` stamps `__munge` onto its argument — and
  // apply `@dependentKeyCompat` by hand, since `defineFieldForwarders` skips
  // names already on the prototype.
  @dependentKeyCompat
  get badge() {
    return this.#wrap("badge", (raw) => new Badge(raw));
  }

  @dependentKeyCompat
  get topic() {
    return this.#wrap("topic", (raw) => Topic.create({ ...raw }));
  }

  set topic(value) {
    shadow(this, "topic", value);
  }

  @dependentKeyCompat
  get user() {
    return this.#wrap("user", (raw) => User.create({ ...raw }));
  }

  set user(value) {
    shadow(this, "user", value);
  }

  // Getter: null → undefined (test contract).
  @dependentKeyCompat
  get granted_by() {
    return this.__resource?.granted_by ?? undefined;
  }

  set granted_by(value) {
    shadow(this, "granted_by", value);
  }

  // Memoized against the raw value: rebuilding per read would refire the
  // model's `init` callbacks and hand out a new identity each render.
  #wrap(name, build) {
    const raw = this.__resource?.[name];
    let cached = this.#wrappers.get(name);
    if (!cached || cached.raw !== raw) {
      cached = { raw, value: raw ? build(raw) : undefined };
      this.#wrappers.set(name, cached);
    }
    return cached.value;
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

    // Optimistic flip. `_adoptResource` swaps a draft wrapper to the now-
    // cached record so the new value is visible.
    store.push(partial(!previous));
    this._adoptResource(this.id);

    try {
      await store.request(toggleFavoriteUserBadge(this.id));
    } catch (e) {
      store.push(partial(previous));
      popupAjaxError(e);
    }
  }
}

defineFieldForwarders(UserBadge, UserBadgeSchema);
