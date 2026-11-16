import { expectTypeOf } from "expect-type";
import type AdminUser from "discourse/admin/models/admin-user";
import RestCompatModel from "discourse/data/rest-compat";
import type Badge from "discourse/models/badge";
import type { RestPayload } from "discourse/models/rest";
import type Topic from "discourse/models/topic";
import type { default as User, UserFields } from "discourse/models/user";
import UserBadge, { type UserBadgeFields } from "discourse/models/user-badge";
import type {
  default as StoreService,
  ModelFor,
} from "discourse/services/store";

declare const store: StoreService;
declare const userBadge: UserBadge;
declare const topic: Topic;
declare const user: User;
declare const admin: AdminUser;

/**
 * Grant fields across `BasicUserBadgeSerializer`, `DetailedUserBadgeSerializer`
 * and `UserBadgeSerializer`. Post and topic fields are sent only when the badge
 * shows posts and the viewer can see the topic. `badge_id`, `user_id` and
 * `granted_by_id` are kept as extra attributes because the schema omits them.
 */
interface ExpectedUserBadgeFields {
  id: number;
  granted_at?: string;
  created_at?: string;
  /** Grouped and featured lists only. */
  count?: number;
  grouping_position?: number | null;
  post_id?: number;
  post_number?: number;
  topic_id?: number;
  topic_title?: string;
  is_favorite?: boolean | null;
  can_favorite?: boolean;
  badge_id?: number;
  user_id?: number;
  granted_by_id?: number;
}

/** `UserBadgeSerializer::UserSerializer`, inlined from the `users` sideloads. */
interface ExpectedUserBadgeUser {
  id: number;
  username: string;
  name?: string | null;
  avatar_template: string;
  trust_level: number;
  admin?: true;
  moderator?: true;
  primary_group_name?: string;
  flair_name?: string;
  flair_url?: string;
  flair_bg_color?: string;
  flair_color?: string;
  flair_group_id?: number;
}

declare module "discourse/models/user-badge" {
  interface UserBadgeFields {
    type_test_plugin_flag?: boolean;
  }
}

expectTypeOf(userBadge).toExtend<RestCompatModel>();
expectTypeOf(userBadge).not.toBeAny();
expectTypeOf<ModelFor<"user-badge">>().toEqualTypeOf<UserBadge>();
expectTypeOf(
  store.createRecord("user-badge", { id: 1 })
).toEqualTypeOf<UserBadge>();

/* Fields. */

expectTypeOf<
  Omit<UserBadgeFields, "type_test_plugin_flag">
>().toEqualTypeOf<ExpectedUserBadgeFields>();
expectTypeOf<
  Pick<UserBadge, keyof ExpectedUserBadgeFields>
>().toEqualTypeOf<ExpectedUserBadgeFields>();
expectTypeOf(userBadge.type_test_plugin_flag).toEqualTypeOf<
  boolean | undefined
>();
// Getter-backed relations are declared by the class, not the fields interface.
expectTypeOf<UserBadgeFields>().not.toHaveProperty("badge");
expectTypeOf<UserBadgeFields>().not.toHaveProperty("topic");
expectTypeOf<UserBadgeFields>().not.toHaveProperty("user");
expectTypeOf<UserBadgeFields>().not.toHaveProperty("granted_by");

userBadge.is_favorite = true;

/* Relations: cached sideloads are wrapped on read. */

expectTypeOf(userBadge.badge).toEqualTypeOf<Badge | undefined>();
expectTypeOf(userBadge.topic).toEqualTypeOf<Topic | undefined>();
expectTypeOf(userBadge.user).toEqualTypeOf<User | undefined>();
expectTypeOf(userBadge.granted_by).toEqualTypeOf<
  ExpectedUserBadgeUser | User | undefined
>();
// @ts-expect-error the badge relation has no setter
userBadge.badge = undefined;
// Callers replace the wrapped relations with their own instances.
userBadge.topic = topic;
userBadge.user = user;
userBadge.granted_by = admin;

/* Derived state. */

expectTypeOf(userBadge.grantedAt).toEqualTypeOf<number | null>();
expectTypeOf(userBadge.postUrl).toEqualTypeOf<string | undefined>();

/* Actions. */

expectTypeOf(userBadge.revoke()).not.toBeAny();
expectTypeOf(userBadge.revoke()).toExtend<PromiseLike<unknown>>();
expectTypeOf(userBadge.favorite()).resolves.toEqualTypeOf<void>();

/** Audit only what UserBadge adds over its base. */
type AnyKeys<T> = {
  [K in keyof T]-?: 0 extends 1 & T[K] ? K : never;
}[keyof T];
type AnyReturnKeys<T> = {
  [K in keyof T]-?: T[K] extends (...args: never) => infer R
    ? 0 extends 1 & R
      ? K
      : never
    : never;
}[keyof T];
type OwnAnyKeys<T, Base> = Exclude<
  AnyKeys<T> | AnyReturnKeys<T>,
  AnyKeys<Base> | AnyReturnKeys<Base>
>;
expectTypeOf<OwnAnyKeys<UserBadge, RestCompatModel>>().toEqualTypeOf<never>();

/* Fetching. */

const byUsername = UserBadge.findByUsername("sam", { grouped: true });
expectTypeOf(byUsername).resolves.toExtend<UserBadge[]>();
declare const listed: Awaited<typeof byUsername>;
expectTypeOf(listed[0]).toEqualTypeOf<UserBadge>();
// Anonymous visitors on a badge page pass no username.
UserBadge.findByUsername(null);
UserBadge.findByUsername(undefined);
UserBadge.findByUsername("sam");

expectTypeOf(
  UserBadge.findByBadgeId(1, { offset: 0, username: "sam" })
).resolves.toExtend<UserBadge[]>();
UserBadge.findByBadgeId(1);
// The badge page filters by a username query param that defaults to null.
UserBadge.findByBadgeId(1, { offset: 30, username: null });
UserBadge.findByBadgeIds([1], { username: null });
expectTypeOf(
  UserBadge.findByBadgeIds([1, 2], { badgeTypeId: 1, limit: 5 })
).resolves.toExtend<UserBadge[]>();
// An empty list asks for every enabled listable badge.
UserBadge.findByBadgeIds([]);
// @ts-expect-error badge ids are numbers
UserBadge.findByBadgeIds(["1"]);

expectTypeOf(
  UserBadge.grant(1, "sam", "Helped out")
).resolves.toEqualTypeOf<UserBadge>();

/* Ingest. */

expectTypeOf(
  UserBadge.createFromJson({
    user_badge: { id: 1, granted_at: "2026-01-01T00:00:00.000Z" },
  })
).toEqualTypeOf<UserBadge>();
const ingested = UserBadge.createFromJson({ user_badges: [], badges: [] });
expectTypeOf(ingested).toExtend<UserBadge[]>();
expectTypeOf(ingested).not.toExtend<UserBadge>();
expectTypeOf(ingested[0]).toEqualTypeOf<UserBadge>();

declare const unknownPayload: RestPayload;
expectTypeOf(UserBadge.createFromJson(unknownPayload)).toExtend<
  UserBadge | UserBadge[]
>();

/* Users keep their featured grants. */

expectTypeOf<UserFields["featured_user_badges"]>().toEqualTypeOf<
  UserBadge[] | undefined
>();
