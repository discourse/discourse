import { dependentKeyCompat } from "@ember/object/compat";
import type { SingleResourceDocument } from "@warp-drive/core/types/spec/json-api-raw";
import {
  findUserBadgesByBadgeId,
  findUserBadgesByBadgeIds,
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
  type WarpResource,
  warpStore,
} from "discourse/data/warp-rest-model";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Badge from "discourse/models/badge";
import Topic, { type TopicCreateAttrs } from "discourse/models/topic";
import User, { type UserCreateAttrs } from "discourse/models/user";
import type WarpStore from "discourse/services/warp-store";

/**
 * Grant fields across the basic, detailed and full user badge serializers.
 * The getter-backed relations (`badge`, `topic`, `user`, `granted_by`) are declared on the class.
 */
export interface UserBadgeFields {
  id: number;
  granted_at?: string;
  /** UserBadgeSerializer only. */
  created_at?: string;
  /** Grouped and featured lists only. */
  count?: number;
  /** Basic and detailed serializers; null without a badge grouping. */
  grouping_position?: number | null;
  /** Sent only when the badge shows posts and the viewer can see the topic. */
  post_id?: number;
  post_number?: number;
  topic_id?: number;
  /** Detailed serializer only, alongside the post fields. */
  topic_title?: string;
  /** Detailed serializer only; `favorite` also flips it locally. */
  is_favorite?: boolean | null;
  /** Detailed serializer only. */
  can_favorite?: boolean;
  /** Kept as extra attributes because the schema omits them. */
  badge_id?: number;
  user_id?: number;
  granted_by_id?: number;
}

/** A `users` sideload row, inlined by normalization; admin may replace it with a User. */
export interface UserBadgeUserPayload {
  id: number;
  username: string;
  /** Sent only when names are enabled. */
  name?: string | null;
  avatar_template: string;
  trust_level: number;
  /** Sent only when true. */
  admin?: true;
  moderator?: true;
  /** Sent only when set. */
  primary_group_name?: string;
  flair_name?: string;
  flair_url?: string;
  flair_bg_color?: string;
  flair_color?: string;
  flair_group_id?: number;
}

interface UserBadgeRelations {
  topic: Topic;
  user: User;
  badge: Badge;
}

// Restores the setter these getters displace, shadowing the getter from then
// on so admin's read-then-write `groupedBadges` doesn't trip Glimmer.
function shadow(instance: UserBadge, name: string, value: unknown) {
  Object.defineProperty(instance, name, {
    value,
    writable: true,
    configurable: true,
    enumerable: true,
  });
}

/** Schema forwarders expose these fields without adding instance properties. */
// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface UserBadge extends UserBadgeFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class UserBadge extends RestCompatModel {
  static override type = "user-badge";

  /** Type-only opt-in: the normalizer treats this root as a single record. */
  declare static singleRecordRoot: "user_badge";
  static override normalize = normalizeUserBadgesPayload;

  // Async so callers can `.then` even on the no-username short circuit
  // (`badges.show` passes a null username for anonymous visitors).
  static async findByUsername(
    username: string | null | undefined,
    options: { grouped?: boolean } = {}
  ) {
    if (!username) {
      return [];
    }
    return requestMany(this, findUserBadgesByUsername(username, options));
  }

  static findByBadgeId(
    badgeId: number,
    options: { offset?: number; username?: string | null } = {}
  ) {
    return requestMany(this, findUserBadgesByBadgeId(badgeId, options));
  }

  // One request for the most recent grants across several badges (or every
  // enabled listable badge when the list is empty). `options` may set
  // `badgeTypeId`/`limit`.
  static findByBadgeIds(
    badgeIds: number[],
    options: {
      badgeTypeId?: number;
      limit?: number;
      offset?: number;
      username?: string | null;
    } = {}
  ) {
    return requestMany(this, findUserBadgesByBadgeIds(badgeIds, options));
  }

  static grant(badgeId: number, username: string, reason?: string) {
    return requestOne(this, grantUserBadge(badgeId, username, reason));
  }

  declare id: number;

  #wrappers = new Map<
    keyof UserBadgeRelations,
    {
      raw: unknown;
      value: UserBadgeRelations[keyof UserBadgeRelations] | undefined;
    }
  >();

  @dependentKeyCompat
  get topic(): Topic | undefined {
    return this.#wrap("topic", (raw) =>
      Topic.create({ ...raw } as TopicCreateAttrs<Topic>)
    );
  }

  set topic(value) {
    shadow(this, "topic", value);
  }

  @dependentKeyCompat
  get user(): User | undefined {
    return this.#wrap("user", (raw) =>
      User.create({ ...raw } as UserCreateAttrs)
    );
  }

  set user(value) {
    shadow(this, "user", value);
  }

  // Getter: null → undefined (test contract).
  @dependentKeyCompat
  get granted_by(): UserBadgeUserPayload | User | undefined {
    return (
      (this.__resource?.granted_by as
        | UserBadgeUserPayload
        | User
        | null
        | undefined) ?? undefined
    );
  }

  set granted_by(value) {
    shadow(this, "granted_by", value);
  }

  // Consumers read class getters off these (`badge.url`, `topic.fancyTitle`,
  // `user.statusManager`), which the cached plain objects lack. Copy before
  // wrapping — `RestModel.create` stamps `__munge` onto its argument — and
  // apply `@dependentKeyCompat` by hand, since `defineFieldForwarders` skips
  // names already on the prototype.
  @dependentKeyCompat
  get badge(): Badge | undefined {
    return this.#wrap("badge", (raw) => new Badge(raw));
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
    const partial = (
      value: boolean | null | undefined
    ): SingleResourceDocument => ({
      data: {
        type: "user-badge",
        id: String(this.id),
        attributes: { is_favorite: value! },
      },
    });

    // Optimistic flip. `_adoptResource` swaps a draft wrapper to the now-
    // cached record so the new value is visible.
    store.push(partial(!previous));
    this._adoptResource(this.id);

    try {
      await store.request(
        toggleFavoriteUserBadge(this.id) as Parameters<WarpStore["request"]>[0]
      );
    } catch (e) {
      store.push(partial(previous));
      popupAjaxError(e);
    }
  }

  // Memoized against the raw value: rebuilding per read would refire the
  // model's `init` callbacks and hand out a new identity each render.
  #wrap<K extends keyof UserBadgeRelations>(
    name: K,
    build: (raw: WarpResource) => UserBadgeRelations[K]
  ): UserBadgeRelations[K] | undefined {
    const raw = this.__resource?.[name];
    let cached = this.#wrappers.get(name);
    if (!cached || cached.raw !== raw) {
      cached = { raw, value: raw ? build(raw as WarpResource) : undefined };
      this.#wrappers.set(name, cached);
    }
    return cached.value as UserBadgeRelations[K] | undefined;
  }
}

defineFieldForwarders(UserBadge, UserBadgeSchema);
