import type EmberObject from "@ember/object";
import { expectTypeOf } from "expect-type";
import type ActionSummary from "discourse/models/action-summary";
import type Archetype from "discourse/models/archetype";
import type Bookmark from "discourse/models/bookmark";
import type {
  CategoryFields,
  default as Category,
} from "discourse/models/category";
import type Post from "discourse/models/post";
import type PostStream from "discourse/models/post-stream";
import type PublishedPage from "discourse/models/published-page";
import type { default as RestModel, RestPayload } from "discourse/models/rest";
import Topic, {
  ID_CONSTRAINT,
  loadTopicView,
  mergeTopic,
  movePosts,
  registerCustomLastUnreadUrlCallback,
  type TopicActionSummaryData,
  type TopicBasicUser,
  type TopicBookmarkData,
  type TopicFields,
  type TopicPendingPost,
  type TopicPublishedPage,
  type TopicTag,
  type TopicThumbnail,
  type TopicTimerData,
} from "discourse/models/topic";
import type TopicDetails from "discourse/models/topic-details";
import type User from "discourse/models/user";
import type {
  default as StoreService,
  ModelFor,
} from "discourse/services/store";

// Independent of the model's own definitions, so a wrong export cannot hide here.

/** `TopicTagsMixin#tags`. */
interface ExpectedTag {
  id: number;
  name: string;
  slug: string;
}

/** `Topic#thumbnail_info`: the original has no max size; optimized ones do. */
interface ExpectedThumbnail {
  max_width: number | null;
  max_height: number | null;
  width: number;
  height: number;
  url: string;
}

/** `TopicTimerSerializer`. `status_type` is the timer type's name. */
interface ExpectedTimer {
  id: number;
  execute_at: string;
  duration_minutes: number | null;
  based_on_last_post: boolean;
  status_type: string;
  category_id: number | null;
}

/** `TopicPendingPostSerializer`; `raw` only when the payload has one. */
interface ExpectedPendingPost {
  id: number;
  created_at: string;
  raw?: string;
}

/** `PublishedPageSerializer`; `id` is the topic id. */
interface ExpectedPublishedPage {
  id: number;
  slug: string;
  public: boolean;
}

/**
 * `TopicViewBookmarkSerializer`. `post_number` comes from a left join on
 * posts, so topic bookmarks send null.
 */
interface ExpectedBookmarkData {
  id: number;
  bookmarkable_id: number;
  bookmarkable_type: "Post" | "Topic";
  reminder_at: string | null;
  name: string | null;
  auto_delete_preference: number;
  post_number: number | null;
}

/** `TopicView#actions_summary`, before `create` wraps it. */
interface ExpectedActionSummaryData {
  id: number;
  count: 0;
  hidden: false;
  can_act: boolean;
}

/** `BasicUserSerializer`; `name` only when names are enabled. */
interface ExpectedBasicUser {
  id: number;
  username: string;
  name?: string | null;
  avatar_template: string;
}

type ExpectedTimerValue = ExpectedTimer | EmberObject | null;

expectTypeOf<TopicTag>().toEqualTypeOf<ExpectedTag>();
expectTypeOf<TopicThumbnail>().toEqualTypeOf<ExpectedThumbnail>();
expectTypeOf<TopicTimerData>().toEqualTypeOf<ExpectedTimer>();
expectTypeOf<TopicPendingPost>().toEqualTypeOf<ExpectedPendingPost>();
expectTypeOf<TopicPublishedPage>().toEqualTypeOf<ExpectedPublishedPage>();
expectTypeOf<TopicBookmarkData>().toEqualTypeOf<ExpectedBookmarkData>();
expectTypeOf<TopicActionSummaryData>().toEqualTypeOf<ExpectedActionSummaryData>();
expectTypeOf<TopicBasicUser>().toEqualTypeOf<ExpectedBasicUser>();

/**
 * Every data field core sends or assigns. Only `id` reaches every instance from
 * the server, and `bookmarks` because `munge` defaults it. Bookmark lists build
 * a topic from five fields and the topic route builds one from its URL
 * parameters, so everything else is optional. Large nested payloads stay
 * `object` until their own models are typed.
 */
interface ExpectedTopicFields {
  /** The topic route's stub holds the URL's string id until the topic loads. */
  id: number;
  bookmarks: (ExpectedBookmarkData | Bookmark)[];

  actions_summary?: (ExpectedActionSummaryData | ActionSummary)[];
  allowed_user_count?: number;
  archetype?: string;
  archived?: boolean;
  bookmarked?: boolean | null;
  bumped?: boolean;
  bumped_at?: string;
  can_localize_topic?: true;
  categories?: CategoryFields[];
  category_id?: number | null;
  chunk_size?: number;
  closed?: boolean;
  created_at?: string;
  current_post_number?: number;
  deleted_at?: string | null;
  deleted_by?: ExpectedBasicUser | User | null;
  destination_category_id?: number | null;
  draft?: string | null;
  draft_key?: string;
  draft_sequence?: number | null;
  excerpt?: string | null;
  expandable_first_post?: true;
  external_id?: string;
  fancy_title?: string;
  fancy_title_localized?: boolean;
  featured_link?: string | null;
  featured_link_root_domain?: string | null;
  first_post_id?: number | false;
  has_activity_log?: boolean;
  has_deleted?: boolean;
  has_localized_content?: boolean;
  has_new_replies?: true;
  has_summary?: boolean;
  highest_post_number?: number | null;
  image_url?: string | null;
  is_hot?: boolean;
  is_nested_view?: boolean;
  is_shared_draft?: boolean;
  is_warning?: true;
  last_posted_at?: string | null;
  last_poster?: ExpectedBasicUser | null;
  last_poster_username?: string | null;
  last_read_post_id?: number | null;
  last_read_post_number?: number | null;
  like_count?: number;
  liked?: boolean | null;
  liked_post_numbers?: number[];
  locale?: string | null;
  message_archived?: boolean;
  message_bus_last_id?: number;
  new_posts?: number;
  notification_level?: number;
  op_can_like?: boolean;
  op_like_count?: number | null;
  op_liked?: boolean;
  participant_count?: number | null;
  participant_groups?: string[];
  participants?: object[];
  pending_posts?: ExpectedPendingPost[];
  pinned?: boolean;
  pinned_at?: string | null;
  pinned_globally?: boolean;
  pinned_until?: string | null;
  pm_with_non_human_user?: boolean;
  post_stream?: object;
  posted?: boolean;
  posters?: object[];
  posts_count?: number;
  published_page?: ExpectedPublishedPage;
  queued_posts_count?: number;
  related_messages?: object[];
  reply_count?: number;
  requested_group_name?: string | null;
  show_read_indicator?: boolean;
  slow_mode_enabled_until?: string | null;
  slow_mode_seconds?: number;
  slug?: string;
  suggested_group_name?: string | null;
  suggested_topics?: object[];
  tags?: ExpectedTag[];
  tags_descriptions?: Record<string, string>;
  thumbnails?: ExpectedThumbnail[] | null;
  timeline_lookup?: [number, number][];
  title?: string;
  topic_timer?: ExpectedTimerValue;
  unicode_title?: string;
  unpinned?: boolean | null;
  unread?: 0;
  unread_by_group_member?: boolean;
  unread_posts?: number;
  unseen?: boolean;
  user_badges?: object | null;
  user_id?: number | null;
  user_last_posted_at?: string | null;
  views?: number;
  visibility_reason_id?: number;
  visible?: boolean;
  word_count?: number | null;

  // Assigned by core after creation.
  actionByName?: EmberObject;
  archiving?: boolean;
  bookmarking?: boolean;
  bookmarksWereChanged?: number;
  currentPost?: number;
  featuredLink?: string | null;
  hidden?: true;
  highlight?: boolean;
  inboxGroupName?: string;
  is_seen?: boolean;
  original_tags?: ExpectedTag[] | null;
  original_title?: string | null;
  pinnedGloballyUntil?: string | null;
  pinnedInCategoryUntil?: string | null;
  prevent_sync?: true;
  publishedPage?: PublishedPage | null;
  topic_status_update?: ExpectedTimerValue;
}

declare module "discourse/models/topic" {
  interface TopicFields {
    type_test_plugin_flag?: boolean;
  }
}

expectTypeOf<
  Omit<TopicFields, "type_test_plugin_flag">
>().toEqualTypeOf<ExpectedTopicFields>();

declare const topic: Topic;

// Data fields reach instances; decorated class fields keep these types.
expectTypeOf<
  Pick<Topic, keyof ExpectedTopicFields>
>().toEqualTypeOf<ExpectedTopicFields>();
expectTypeOf(topic.type_test_plugin_flag).toEqualTypeOf<boolean | undefined>();

// Client state the model declares itself.
expectTypeOf(topic.errorLoading).toEqualTypeOf<boolean>();
expectTypeOf(topic.errorHtml).toEqualTypeOf<string | null | undefined>();
expectTypeOf(topic.errorTitle).toEqualTypeOf<string | null | undefined>();
expectTypeOf(topic.errorMessage).toEqualTypeOf<string | null | undefined>();
expectTypeOf(topic.noRetry).toEqualTypeOf<boolean | undefined>();
// Copied from the URL's query parameter by the topic route.
expectTypeOf(topic.replies_to_post_number).toEqualTypeOf<
  string | null | undefined
>();
expectTypeOf(topic.message).not.toBeAny();

// Topic adds no member that is, or returns, `any`, on instances or on the
// class. Ember's own `_super` and `metaForProperty` are excluded.
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
expectTypeOf<OwnAnyKeys<Topic, EmberObject>>().toEqualTypeOf<never>();
// The overridden `create` is generic in `this`, and inferring its return
// through a conditional type gives `any` even though calls resolve to Topic;
// its result is asserted in the create tests below.
expectTypeOf<
  Exclude<OwnAnyKeys<typeof Topic, typeof EmberObject>, "create">
>().toEqualTypeOf<never>();

// Accessors with exact types.
expectTypeOf(topic.details).toEqualTypeOf<TopicDetails>();
expectTypeOf(topic.category).toEqualTypeOf<Category | undefined>();
expectTypeOf(topic.postStream).toEqualTypeOf<PostStream>();
expectTypeOf(topic.bookmarkCount).toEqualTypeOf<number>();
expectTypeOf(topic.deleted).toEqualTypeOf<boolean>();
expectTypeOf(topic.isPrivateMessage).toEqualTypeOf<boolean>();
expectTypeOf(topic.isBanner).toEqualTypeOf<boolean>();
expectTypeOf(topic.isPinnedUncategorized).toEqualTypeOf<boolean | undefined>();
expectTypeOf(topic.hasExcerpt).toEqualTypeOf<boolean>();
expectTypeOf(topic.readLastPost).toEqualTypeOf<boolean>();
expectTypeOf(topic.canClearPin).toEqualTypeOf<boolean | undefined>();
expectTypeOf(topic.visited).toEqualTypeOf<boolean>();
expectTypeOf(topic.invisible).toEqualTypeOf<boolean | undefined>();
expectTypeOf(topic.fancyTitle).toEqualTypeOf<string>();
expectTypeOf(topic.createdAt).toEqualTypeOf<Date>();
expectTypeOf(topic.bumpedAt).toEqualTypeOf<Date>();
expectTypeOf(topic.bumpedAtTitle).toEqualTypeOf<string | undefined>();
expectTypeOf(topic.visibleListTags).toEqualTypeOf<ExpectedTag[] | undefined>();
expectTypeOf(topic.relatedMessages).toEqualTypeOf<Topic[] | undefined>();
expectTypeOf(topic.suggestedTopics).toEqualTypeOf<Topic[] | undefined>();
expectTypeOf(topic.replyCount).toEqualTypeOf<number>();
expectTypeOf(topic.visibilityReasonTranslated).toEqualTypeOf<string>();
expectTypeOf(topic.searchContext).toEqualTypeOf<{
  type: "topic";
  id: number;
}>();
expectTypeOf(topic.totalUnread).toEqualTypeOf<number | undefined>();
expectTypeOf(topic.displayNewPosts).toEqualTypeOf<number | undefined>();
expectTypeOf(topic.viewsHeat).toEqualTypeOf<
  "heatmap-high" | "heatmap-med" | "heatmap-low" | null
>();
expectTypeOf(topic.archetypeObject).toEqualTypeOf<Archetype | undefined>();
expectTypeOf(topic.escapedExcerpt).toEqualTypeOf<string>();
expectTypeOf(topic.excerptTruncated).toExtend<
  string | boolean | null | undefined
>();
expectTypeOf(topic.url).toEqualTypeOf<string>();
expectTypeOf(topic.updateUrl).toEqualTypeOf<string>();
expectTypeOf(topic.printUrl).toEqualTypeOf<string>();
expectTypeOf(topic.shareUrl).toEqualTypeOf<string>();
expectTypeOf(topic.lastReadUrl).toEqualTypeOf<string>();
expectTypeOf(topic.lastUnreadUrl).toEqualTypeOf<string>();
expectTypeOf(topic.lastPostUrl).toEqualTypeOf<string>();
expectTypeOf(topic.firstPostUrl).toEqualTypeOf<string>();
expectTypeOf(topic.summaryUrl).toEqualTypeOf<string>();
expectTypeOf(topic.lastPosterUrl).toEqualTypeOf<string>();
expectTypeOf(topic.urlForPostNumber(3)).toEqualTypeOf<string>();

// Poster entries stay untyped until their payload is, but never `any`.
expectTypeOf(topic.featuredUsers).toEqualTypeOf<object[]>();
expectTypeOf(topic.creator).not.toBeAny();
expectTypeOf(topic.lastPoster).not.toBeAny();
expectTypeOf(topic.lastPosterUser).not.toBeAny();
expectTypeOf(topic.lastPosterGroup).not.toBeAny();
expectTypeOf(topic.allowedGroups).not.toBeAny();
expectTypeOf(topic.canEditTags).not.toBeAny();

// Instance methods.
expectTypeOf(topic.removeBookmark(1)).toEqualTypeOf<void>();
expectTypeOf(topic.clearBookmarks()).toEqualTypeOf<number[]>();
expectTypeOf(topic.updateFromJson({ id: 1 })).toEqualTypeOf<Topic>();
expectTypeOf(topic.reload()).resolves.toEqualTypeOf<void>();
expectTypeOf(topic.clearPin()).toEqualTypeOf<void>();
expectTypeOf(topic.rePin()).toEqualTypeOf<void>();
expectTypeOf(topic.togglePinnedForUser()).toEqualTypeOf<void>();

// Statics.
expectTypeOf(Topic.NotificationLevel).toEqualTypeOf<{
  WATCHING: number;
  TRACKING: number;
  REGULAR: number;
  MUTED: number;
}>();
expectTypeOf(
  Topic.update(topic, { title: "New title", categoryId: 2 })
).resolves.toEqualTypeOf<void>();

// Module exports.
expectTypeOf(ID_CONSTRAINT).toEqualTypeOf<RegExp>();
expectTypeOf(loadTopicView(topic, {})).resolves.not.toBeAny();
expectTypeOf(movePosts(1, {})).resolves.not.toBeAny();
expectTypeOf(mergeTopic(1, {})).resolves.not.toBeAny();
registerCustomLastUnreadUrlCallback((t: Topic) =>
  t.is_nested_view ? t.url : undefined
);

// The `destroy` overload sentinel keeps Topic assignable to RestModel, so the
// typed `create` still applies.
declare const deletedBy: User;
expectTypeOf(topic.destroy(deletedBy)).resolves.toEqualTypeOf<void>();
expectTypeOf(topic).toExtend<RestModel>();
expectTypeOf(Topic.create()).toEqualTypeOf<Topic>();
expectTypeOf(
  Topic.create({ id: 1, title: "Hello", extra_server_field: true })
).toEqualTypeOf<Topic>();
// @ts-expect-error a declared field keeps its type in create attrs
Topic.create({ posts_count: "3" });
// @ts-expect-error unread is only ever sent as 0
Topic.create({ unread: 1 });
// @ts-expect-error is_warning is only ever sent as true
Topic.create({ is_warning: false });

// `create` returns the subclass it is called on.
class SpecializedTopic extends Topic {
  declare clientLabel: string;
}
expectTypeOf(SpecializedTopic.create()).toEqualTypeOf<SpecializedTopic>();
expectTypeOf(
  SpecializedTopic.create({ id: 1, clientLabel: "Example" })
).toEqualTypeOf<SpecializedTopic>();
// @ts-expect-error subclass fields keep their types in create attrs
SpecializedTopic.create({ clientLabel: 1 });

expectTypeOf(topic.firstPost()).resolves.toEqualTypeOf<Post>();
expectTypeOf(topic.postById(1)).resolves.toEqualTypeOf<Post>();

// The store registry maps "topic" to Topic.
declare const store: StoreService;
expectTypeOf<ModelFor<"topic">>().toEqualTypeOf<Topic>();
expectTypeOf(store.createRecord("topic")).toEqualTypeOf<Topic>();

// Signatures accept what core callers pass at runtime.
declare const findResult: Awaited<ReturnType<typeof Topic.find>>;
declare const viewResult: Awaited<ReturnType<typeof loadTopicView>>;
declare const post: Post;
Topic.bulkOperation([topic], { type: "dismiss_posts" }, {}, true);
Topic.bulkOperationByFilter(
  "unread",
  { type: "change_notification_level", notification_level_id: 1 },
  {},
  false
);
Topic.bulkOperation([topic], {
  type: "close",
  silent: true,
  message: "Closing",
});
// @ts-expect-error an operation names its type
Topic.bulkOperation([topic], { silent: true });
expectTypeOf(Topic.create(findResult)).toEqualTypeOf<Topic>();
expectTypeOf(store.createRecord("topic", viewResult)).toEqualTypeOf<Topic>();
Topic.update(topic, { tags: ["a", "b"] });
topic.updateTags([{ name: "new-tag" }]);
topic.updateTags([{ id: 1, name: "existing", slug: "existing" }]);
topic.updateTags(["a"]);
Topic.pmResetNew({ inbox: "user", topicIds: null });
topic.afterPostBookmarked(post, { reminder_at: null });
topic.createInvite("user", null, "Hello");
topic.generateInviteLink("user@example.com", null, undefined);
// @ts-expect-error the returned promise has no reject method
void Topic.changeOwners(1, {}).reject;
expectTypeOf(Topic.changeTimestamp(1, 0)).resolves.toEqualTypeOf<
  RestPayload | undefined
>();
expectTypeOf(Topic.changeOwners(1, {})).resolves.toEqualTypeOf<
  RestPayload | undefined
>();
expectTypeOf(
  store.createRecord("topic", { details: { can_edit: true } })
).toEqualTypeOf<Topic>();
expectTypeOf(
  SpecializedTopic.create({ clientLabel: "Example", details: {} })
).toEqualTypeOf<SpecializedTopic>();
Topic.update(topic, { tags: ["existing", { name: "new", isNew: true }] });
topic.updateTags(["existing", { name: "new", isNew: true }]);
