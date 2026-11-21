import { expectTypeOf } from "expect-type";
import RestCompatModel from "discourse/data/rest-compat";
import type Post from "discourse/models/post";
import type Topic from "discourse/models/topic";
import TopicDetails, {
  type TopicDetailsFields,
} from "discourse/models/topic-details";
import type User from "discourse/models/user";
import type {
  default as StoreService,
  ModelFor,
} from "discourse/services/store";

declare const store: StoreService;
declare const details: TopicDetails;
declare const topic: Topic;
declare const user: User;
declare const post: Post;

/** `BasicUserSerializer`; `name` is sent only when names are enabled. */
interface ExpectedBasicUser {
  id: number;
  username: string;
  name?: string | null;
  avatar_template: string;
}

/** `TopicPostCountSerializer`. */
interface ExpectedParticipantPayload extends ExpectedBasicUser {
  post_count: number;
  primary_group_name: string | null;
  flair_name: string | null;
  flair_url: string | null;
  flair_color: string | null;
  flair_bg_color: string | null;
  flair_group_id: number | null;
  admin?: true;
  moderator?: true;
  trust_level: number;
}

/** `TopicLinkSerializer`; the topic map sends only clicked links. */
interface ExpectedTopicLink {
  url: string;
  title: string | null;
  internal: boolean;
  attachment: boolean;
  reflection: boolean | null;
  clicks: number;
  user_id?: number;
  domain: string;
  /** The public suffix lookup returns nil for hosts it cannot split. */
  root_domain: string | null;
}

/**
 * `TopicViewDetailsSerializer`. Every field is optional because the topic
 * creates its details before they load. Each `can_*` permission is sent only
 * when granted, except `can_edit`, which is always sent.
 */
interface ExpectedTopicDetailsFields {
  can_edit?: boolean;
  can_move_posts?: boolean;
  can_delete?: boolean;
  can_permanently_delete?: boolean;
  can_recover?: boolean;
  can_remove_allowed_users?: boolean;
  can_invite_to?: boolean;
  can_invite_via_email?: boolean;
  can_create_post?: boolean;
  can_reply_as_new_topic?: boolean;
  can_flag_topic?: boolean;
  can_convert_topic?: boolean;
  can_review_topic?: boolean;
  can_edit_tags?: boolean;
  can_publish_page?: boolean;
  can_close_topic?: boolean;
  can_archive_topic?: boolean;
  can_split_merge_topic?: boolean;
  can_edit_staff_notes?: boolean;
  can_toggle_topic_visibility?: boolean;
  can_pin_unpin_topic?: boolean;
  can_banner_topic?: boolean;
  can_moderate_category?: boolean;
  /** The id of the user allowed to remove themselves, not a flag. */
  can_remove_self_id?: number;
  notification_level?: number;
  /** Sent only when the viewer has a topic user row. */
  notifications_reason_id?: number | null;
  created_by?: ExpectedBasicUser | null;
  /** Optimistic posting assigns the current user. */
  last_poster?: ExpectedBasicUser | User | null;
  links?: ExpectedTopicLink[];
  /** Loading wraps these in User; drafts may hold payloads. */
  allowed_users?: (User | ExpectedBasicUser)[];
}

declare module "discourse/models/topic-details" {
  interface TopicDetailsFields {
    type_test_plugin_flag?: boolean;
  }
}

expectTypeOf(details).toExtend<RestCompatModel>();
expectTypeOf(details).not.toBeAny();
expectTypeOf<ModelFor<"topic-details">>().toEqualTypeOf<TopicDetails>();
// Topic creates its details under the camelCase name.
expectTypeOf<ModelFor<"topicDetails">>().toEqualTypeOf<TopicDetails>();
expectTypeOf(
  store.createRecord("topicDetails", { id: topic.id, topic })
).toEqualTypeOf<TopicDetails>();

/* Fields. */

type CheckedKeys =
  | keyof ExpectedTopicDetailsFields
  | "participants"
  | "allowed_groups";
expectTypeOf<
  Exclude<keyof TopicDetailsFields, "type_test_plugin_flag" | CheckedKeys>
>().toEqualTypeOf<never>();
expectTypeOf<
  Exclude<CheckedKeys, keyof TopicDetailsFields>
>().toEqualTypeOf<never>();
expectTypeOf<
  Pick<TopicDetailsFields, keyof ExpectedTopicDetailsFields>
>().toEqualTypeOf<ExpectedTopicDetailsFields>();
expectTypeOf<
  Pick<TopicDetails, keyof ExpectedTopicDetailsFields>
>().toEqualTypeOf<ExpectedTopicDetailsFields>();
expectTypeOf(details.type_test_plugin_flag).toEqualTypeOf<
  boolean | undefined
>();

// Loading wraps participants in EmberObjects that point back at the topic.
type Participant = NonNullable<TopicDetails["participants"]>[number];
expectTypeOf<Participant>().not.toBeAny();
expectTypeOf<Participant>().toExtend<ExpectedParticipantPayload>();

/** `BasicGroupSerializer`; nullability follows the `groups` columns. */
interface ExpectedBasicGroup {
  id: number;
  name: string;
  automatic: boolean;
  /** Automatic groups only; unknown automatic ids have no name. */
  display_name?: string | null;
  /** Only when the viewer can see members. */
  user_count?: number;
  mentionable_level: number | null;
  messageable_level: number | null;
  visibility_level: number;
  primary_group: boolean;
  title: string | null;
  grant_trust_level: number | null;
  /** Staff only. */
  incoming_email?: string | null;
  /** Staff, or viewers who can see the group's messages. */
  has_messages?: boolean;
  flair_url: string | null;
  flair_bg_color: string | null;
  flair_color: string | null;
  /** Staff, or group owners. */
  bio_raw?: string | null;
  bio_cooked: string | null;
  bio_excerpt: string | null;
  public_admission: boolean;
  public_exit: boolean;
  allow_membership_requests: boolean;
  full_name: string | null;
  default_notification_level: number;
  membership_request_template: string | null;
  /** Only when the serializer is given the viewer's group ids. */
  is_group_user?: boolean;
  is_group_owner?: boolean;
  members_visibility_level: number;
  can_see_members: boolean;
  can_admin_group?: true;
  can_edit_group?: true;
  publish_read_state: boolean;
}

type AllowedGroup = NonNullable<TopicDetails["allowed_groups"]>[number];
expectTypeOf<AllowedGroup>().toEqualTypeOf<ExpectedBasicGroup>();

details.notification_level = 2;
details.notifications_reason_id = null;
details.can_delete = false;
details.last_poster = user;
// @ts-expect-error notification levels are numbers
details.notification_level = "2";

/* Client state. */

expectTypeOf(details.id).toEqualTypeOf<string | null>();
expectTypeOf(details.loaded).toEqualTypeOf<boolean>();
expectTypeOf(details.topic).toEqualTypeOf<Topic | null>();
// @ts-expect-error the id comes from the topic
details.id = "1";

/** Audit only what TopicDetails adds over its base. */
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
expectTypeOf<
  OwnAnyKeys<TopicDetails, RestCompatModel>
>().toEqualTypeOf<never>();

/* Construction. */

expectTypeOf(
  TopicDetails.create({ id: 1, topic })
).toEqualTypeOf<TopicDetails>();
expectTypeOf(TopicDetails.create()).toEqualTypeOf<TopicDetails>();
expectTypeOf(TopicDetails.create({ id: "1" })).toEqualTypeOf<TopicDetails>();
// Assigning plain details to a topic keeps the extra attributes as a draft.
declare const allowedUser: ExpectedBasicUser;
expectTypeOf(
  TopicDetails.create({ allowed_users: [allowedUser], can_edit: true })
).toEqualTypeOf<TopicDetails>();
// @ts-expect-error topics are Topic models
TopicDetails.create({ topic: { id: 1 } });

/* Ingest: the topic view's `details` object. */

declare const detailsPayload: Omit<
  ExpectedTopicDetailsFields,
  "allowed_users" | "last_poster"
> & {
  allowed_users?: ExpectedBasicUser[];
  last_poster?: ExpectedBasicUser | null;
  participants?: ExpectedParticipantPayload[];
};
expectTypeOf(details.updateFromJson(detailsPayload)).toEqualTypeOf<undefined>();
details.updateFromJson(null);
details.updateFromJson(undefined);

/* Actions. */

expectTypeOf(details.updateNotifications(3)).resolves.toEqualTypeOf<void>();
declare const group: AllowedGroup;
expectTypeOf(details.removeAllowedGroup(group)).resolves.toEqualTypeOf<void>();
expectTypeOf(details.removeAllowedUser(user)).resolves.toEqualTypeOf<void>();
details.removeAllowedUser(allowedUser);

/* Consumers: topics read their details without casts. */

expectTypeOf(topic.details).toEqualTypeOf<TopicDetails>();
expectTypeOf(topic.allowedGroups).toEqualTypeOf<
  TopicDetails["allowed_groups"]
>();
expectTypeOf(topic.canEditTags).toEqualTypeOf<boolean | undefined>();

// Post permissions read the topic's details.
expectTypeOf(post.topicCreatedById).toEqualTypeOf<number | undefined>();
expectTypeOf(post.topicNotificationLevel).toEqualTypeOf<number | undefined>();
expectTypeOf(post.canDeleteTopic).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.canEditStaffNotes).toEqualTypeOf<boolean>();
expectTypeOf(post.canPublishPage).toEqualTypeOf<boolean>();
expectTypeOf(post.canSplitMergeTopic).toEqualTypeOf<boolean>();
expectTypeOf(user.pmPath(topic)).toEqualTypeOf<string | undefined>();
