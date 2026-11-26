import { expectTypeOf } from "expect-type";
import RestCompatModel from "discourse/data/rest-compat";
import Badge, { type BadgeFields } from "discourse/models/badge";
import type Post from "discourse/models/post";
import type { RestPayload } from "discourse/models/rest";
import type { TopicFields } from "discourse/models/topic";
import type {
  default as User,
  UserFields,
  UserSummary,
} from "discourse/models/user";
import type {
  default as StoreService,
  ModelFor,
} from "discourse/services/store";

declare const store: StoreService;
declare const badge: Badge;
declare const post: Post;
declare const user: User;

/** Cached `badge-type` records keep JSON:API string ids. */
interface ExpectedBadgeType {
  id: string;
  name: string;
  sort_order: number;
}

/** Cached `badge-grouping` records; normalization derives `displayName`. */
interface ExpectedBadgeGrouping {
  id: string;
  name: string;
  description: string | null;
  position: number;
  system: boolean;
  displayName?: string;
}

/**
 * `BadgeSerializer`, `BadgeIndexSerializer` and `AdminBadgeSerializer` fields.
 * Every server path sends `id` and `name`; drafts built by the admin form
 * and the "none" title choice supply `name` only.
 */
interface ExpectedBadgeFields {
  id: number;
  name: string;
  /** The model accessor falls back to "", so the wire value is never null. */
  description?: string;
  long_description?: string;
  slug?: string;
  icon?: string | null;
  image_url?: string | null;
  grant_count?: number;
  enabled?: boolean;
  listable?: boolean | null;
  show_in_post_header?: boolean;
  /** Sent only with a current-user grant set; badge normalization defaults it. */
  has_badge?: boolean;
  allow_title?: boolean;
  multiple_grant?: boolean;
  manually_grantable?: boolean;
  system?: boolean;
  badge_type_id?: number;
  badge_grouping_id?: number;
  /** Admin serializer only. */
  query?: string | null;
  trigger?: number | null;
  target_posts?: boolean | null;
  auto_revoke?: boolean;
  show_posts?: boolean;
  i18n_name?: string;
  image_upload_id?: number | null;
  /** Relationship forwarders have no setter. */
  readonly badge_type?: ExpectedBadgeType | null;
  readonly badge_grouping?: ExpectedBadgeGrouping | null;
}

/** A sideloaded `BadgeSerializer` row as the server sends it. */
interface ExpectedBadgePayload {
  id: number;
  name: string;
  description: string;
  grant_count: number;
  allow_title: boolean;
  multiple_grant: boolean;
  icon: string | null;
  image_url: string | null;
  listable: boolean | null;
  enabled: boolean;
  badge_grouping_id: number;
  system: boolean;
  slug: string;
  manually_grantable: boolean;
  show_in_post_header: boolean;
  badge_type_id: number;
  long_description?: string;
  has_badge?: boolean;
}

/** `BasicUserBadgeSerializer#as_json`, one per post-header grant. */
interface ExpectedBadgesGrantedEnvelope {
  basic_user_badge: {
    id: number;
    granted_at: string;
    count?: number;
    grouping_position: number | null;
    badge_id: number;
  };
  badges: ExpectedBadgePayload[];
  badge_types: { id: number; name: string; sort_order: number }[];
}

/** `TopicView#user_badges`, built by hand without `BadgeSerializer`. */
interface ExpectedTopicUserBadges {
  users: Record<string, { id: number; badge_ids: number[] }>;
  badges: Record<
    string,
    {
      id: number;
      name: string;
      slug: string;
      description: string;
      icon: string | null;
      image_url: string | null;
      badge_grouping_id: number;
      badge_type_id: number;
    }
  >;
}

declare module "discourse/models/badge" {
  interface BadgeFields {
    type_test_plugin_flag?: boolean;
  }
}

expectTypeOf(badge).toExtend<RestCompatModel>();
expectTypeOf(badge).not.toBeAny();
expectTypeOf<ModelFor<"badge">>().toEqualTypeOf<Badge>();
expectTypeOf(store.createRecord("badge", { name: "x" })).toEqualTypeOf<Badge>();

/* Fields. */

expectTypeOf<
  Omit<BadgeFields, "type_test_plugin_flag">
>().toEqualTypeOf<ExpectedBadgeFields>();
expectTypeOf<
  Pick<Badge, keyof ExpectedBadgeFields>
>().toEqualTypeOf<ExpectedBadgeFields>();
expectTypeOf(badge.type_test_plugin_flag).toEqualTypeOf<boolean | undefined>();
// Plugins add `display_name`; core does not declare it.
expectTypeOf<BadgeFields>().not.toHaveProperty("display_name");

badge.name = "Renamed";
badge.has_badge = true;
// @ts-expect-error relationship forwarders have no setter
badge.badge_type = null;
// @ts-expect-error names are strings
badge.name = 1;

/* Client state: the user summary copies the grant count onto its badges. */

expectTypeOf<Badge["count"]>().toEqualTypeOf<number | undefined>();
badge.count = 3;

/* Derived state. */

expectTypeOf(badge.image).toEqualTypeOf<string | null | undefined>();
expectTypeOf(badge.url).toEqualTypeOf<string>();
expectTypeOf(badge.newBadge).toEqualTypeOf<boolean>();
expectTypeOf(badge.badgeTypeClassName).toEqualTypeOf<string>();

/** Audit only what Badge adds over its base. */
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
expectTypeOf<OwnAnyKeys<Badge, RestCompatModel>>().toEqualTypeOf<never>();

/* Construction. */

expectTypeOf(Badge.create({ name: "None" })).toEqualTypeOf<Badge>();
expectTypeOf(
  Badge.create({
    name: "New badge",
    enabled: true,
    badge_type_id: 1,
    badge_grouping_id: 5,
    trigger: 0,
  })
).toEqualTypeOf<Badge>();
// @ts-expect-error badge type ids are numbers
Badge.create({ badge_type_id: "1" });

/* Fetching and ingest. */

const listing = Badge.findAll();
expectTypeOf(listing).resolves.toExtend<Badge[]>();
expectTypeOf(Badge.findById(1)).resolves.toEqualTypeOf<Badge>();

declare const badgePayload: ExpectedBadgePayload;
// A `{ badge }` root is one record; anything else is a list.
expectTypeOf(
  Badge.createFromJson({ badge: badgePayload, badge_types: [] })
).toEqualTypeOf<Badge>();
const ingested = Badge.createFromJson({
  badges: [badgePayload],
  badge_types: [],
});
expectTypeOf(ingested).toExtend<Badge[]>();
expectTypeOf(ingested).not.toExtend<Badge>();
expectTypeOf(ingested[0]).toEqualTypeOf<Badge>();

declare const unknownPayload: RestPayload;
expectTypeOf(Badge.createFromJson(unknownPayload)).not.toBeAny();
expectTypeOf(Badge.createFromJson(unknownPayload)).toExtend<Badge | Badge[]>();

/* Post header grants. */

declare const envelope: ExpectedBadgesGrantedEnvelope;
expectTypeOf<
  NonNullable<Post["badges_granted"]>[number]
>().toEqualTypeOf<ExpectedBadgesGrantedEnvelope>();
expectTypeOf(Badge.createFromJson(envelope)).toExtend<Badge[]>();
expectTypeOf(post.badgesGranted).toEqualTypeOf<
  (Badge | undefined)[] | undefined
>();

/* Topic view badge hash, read by post headers. */

expectTypeOf<TopicFields["user_badges"]>().toEqualTypeOf<
  ExpectedTopicUserBadges | null | undefined
>();
expectTypeOf(post.userBadges).toEqualTypeOf<
  ExpectedTopicUserBadges["badges"][string][] | undefined
>();

/* Users hold Badge wrappers. */

// The account route assigns each grant's badge to `user.badges`.
expectTypeOf<UserFields["badges"]>().toEqualTypeOf<Badge[] | undefined>();
// Plugins may send a `BadgeSerializer` payload here; loading wraps it.
expectTypeOf<UserFields["card_badge"]>().toEqualTypeOf<
  Badge | null | undefined
>();
expectTypeOf<UserSummary["badges"]>().toEqualTypeOf<Badge[] | undefined>();
expectTypeOf(user.availableTitles).toEqualTypeOf<
  { name: string; id: string }[]
>();
