import { cached, tracked } from "@glimmer/tracking";
import EmberObject, { computed, get, set } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { service } from "@ember/service";
import type { TrustedHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { Promise } from "rsvp";
import { resolveShareUrl } from "discourse/helpers/share-url";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  clearModelFields,
  modelFieldNames,
  registerModelField,
  stampModelClass,
} from "discourse/lib/model-extensions";
import { deepEqual } from "discourse/lib/object";
import { cook } from "discourse/lib/text";
import { fancyTitle } from "discourse/lib/topic-fancy-title";
import { enumerateTrackedKeys } from "discourse/lib/tracked-tools";
import { applyValueTransformer } from "discourse/lib/transformer";
import { userPath } from "discourse/lib/url";
import { postUrl } from "discourse/lib/utilities";
import ActionSummary, {
  type ActionSummaryFields,
} from "discourse/models/action-summary";
import Badge from "discourse/models/badge";
import type {
  CategoryFields,
  default as Category,
} from "discourse/models/category";
import Composer from "discourse/models/composer";
import RestModel, {
  type RestModelAttrs,
  type RestModelClass,
  type RestModelSaveResult,
  type RestPayload,
} from "discourse/models/rest";
import Site from "discourse/models/site";
import type { default as Topic, TopicBasicUser } from "discourse/models/topic";
import User from "discourse/models/user";
import type AppEventsService from "discourse/services/app-events";
import { i18n } from "discourse-i18n";

/** Status included only when it is active and visible to the viewer. */
export interface PostUserStatus {
  description: string;
  emoji: string;
  ends_at: string | null;
  message_bus_last_id: number;
}

/** Notices vary by their creator and the viewer's eligibility. */
export type PostNotice =
  | { type: "custom"; raw: string; cooked: string; created_by_user_id?: number }
  | { type: "new_user" }
  | { type: "returning_user"; last_posted_at: string };

/** Server payloads and client state. Identity follows the primary server/staged paths; other fields may be absent on partial posts. */
export interface PostFields {
  id: number;
  post_number: number;
  topic_id?: number;
  post_type?: number;
  version?: number;
  reply_count?: number;
  readers_count?: number;
  reads?: number;
  quote_count?: number;
  incoming_link_count?: number;
  score?: number;
  like_count?: number;
  direct_reply_count?: number;
  total_descendant_count?: number;
  draft_sequence?: number;
  post_localizations_count?: number;
  reviewable_score_count?: number;
  reviewable_score_pending_count?: number;
  typingTime?: number;
  composerTime?: number;
  typing_duration_msecs?: number;
  composer_open_duration_msecs?: number;
  composer_version?: number;
  reply_to_post_number?: number | null;
  user_id?: number | null;
  trust_level?: number | null;
  flair_group_id?: number | null;
  hidden_reason_id?: number | null;
  reviewable_id?: number | null;
  bookmark_id?: number | null;
  bookmark_auto_delete_preference?: number | null;
  category_id?: number | null;
  posts_count?: number | null;
  category?: Category | number | null;
  cooked?: string;
  raw?: string;
  updated_at?: string;
  post_url?: string;
  userPath?: string;
  action_code?: string;
  last_wiki_edit?: string;
  blurb?: string;
  language?: string;
  user_locale?: string;
  editReason?: string;
  title?: string;
  archetype?: string;
  target_recipients?: string;
  draft_key?: string;
  topic_slug?: string | null;
  edit_reason?: string | null;
  username?: string | null;
  name?: string | null;
  display_username?: string | null;
  avatar_template?: string | null;
  user_title?: string | null;
  primary_group_name?: string | null;
  flair_name?: string | null;
  flair_url?: string | null;
  flair_bg_color?: string | null;
  flair_color?: string | null;
  bookmark_name?: string | null;
  bookmark_reminder_at?: string | null;
  topic_title?: string | null;
  topic_html_title?: string | TrustedHTML | null;
  excerpt?: string | null;
  topic_title_headline?: string | null;
  locale?: string | null;
  avatar_color?: string | null;
  expandedExcerpt?: string | null;
  localizedCooked?: string | null;
  oldCooked?: string | null;
  featured_link?: string | null;
  moderator?: boolean;
  admin?: boolean;
  staff?: boolean;
  title_is_group?: boolean;
  yours?: boolean;
  can_delete?: boolean;
  can_recover?: boolean;
  can_permanently_delete?: boolean;
  can_wiki?: boolean;
  can_see_hidden_post?: boolean;
  can_view_edit_history?: boolean;
  read?: boolean;
  hidden?: boolean;
  cooked_hidden?: boolean;
  user_deleted?: boolean;
  wiki?: boolean;
  locked?: boolean;
  via_email?: boolean;
  bookmarked?: boolean;
  truncated?: boolean;
  deleted_post_placeholder?: boolean;
  ignored_post_placeholder?: boolean;
  is_localized?: boolean;
  can_localize_post?: boolean;
  staged?: boolean;
  hasGap?: boolean;
  group_moderator?: true;
  is_auto_generated?: true;
  localization_outdated?: boolean;
  quoted?: unknown;
  user_suspended?: true;
  refreshedPost?: boolean;
  unlist_topic?: boolean;
  is_warning?: boolean;
  whisper?: boolean;
  shared_draft?: boolean;
  no_bump?: boolean;
  nested_post?: boolean;
  oldCanEdit?: boolean;
  _can_edit?: boolean;
  created_at?: string | Date;
  deleted_at?: string | Date | null;
  deleted_by?: TopicBasicUser | User | null;
  topic?: Topic;
  actions_summary?: ActionSummary[];
  likeAction?: ActionSummary | null;
  actionByName?: EmberObject & Record<string, ActionSummary>;
  reply_to_user?:
    | User
    | (Pick<TopicBasicUser, "username" | "avatar_template"> &
        Partial<TopicBasicUser>)
    | null;
  user_status?: PostUserStatus;
  user_custom_fields?: Record<string, unknown>;
  notice?: PostNotice | null;
  notice_created_by_user?: TopicBasicUser | null;
  noticeCreatedByUser?: User;
  mentioned_users?: ((TopicBasicUser & { status?: PostUserStatus }) | User)[];
  link_counts?: {
    url: string;
    internal: boolean;
    reflection: boolean | null;
    clicks: number;
    title?: string | null;
  }[];
  /** TODO(typescript-pending): Badge lacks a typed createFromJson envelope; narrow when Badge is converted. */
  badges_granted?: RestPayload[];
  post_localizations?: unknown[];
  localized_oneboxes?: {
    topic_id: number;
    post_number: number;
    title?: string;
    excerpt?: string;
  }[];
  static_doc?: true;
  /** Custom-field registrations can change the value shape. */
  action_code_who?: unknown;
  /** Custom-field registrations can change the value shape. */
  action_code_path?: unknown;
  /** TODO(typescript-pending): Composer accepts untyped save options beyond its image-dimension map; narrow when Composer is typed. */
  imageSizes?: unknown;
  /** TODO(typescript-pending): Composer metadata is extensible; remove when its metadata contract is typed. */
  metaData?: (EmberObject & Record<string, unknown>) | null;
  tags?: { id?: number; name: string }[];
  replies?: Post[];
  children?: RestPayload[];
}

/** TODO(typescript-pending): TopicDetails forwarders omit these payload fields; remove when TopicDetails is typed. */
type PostTopicDetails = Omit<Topic["details"], "notification_level"> & {
  created_by?: TopicBasicUser;
  can_delete?: boolean;
  can_edit_staff_notes?: boolean;
  can_permanently_delete?: boolean;
  can_publish_page?: boolean;
  can_recover?: boolean;
  can_split_merge_topic?: boolean;
  notification_level?: number;
};

/** TODO(typescript-pending): Topic user_badges is only object; remove when its badge payload and Badge are typed. */
type PostTopicBadges = {
  users: Record<number, { badge_ids: number[] }>;
  badges: Record<
    number,
    {
      id: number;
      name: string;
      slug: string;
      description: string | null;
      icon: string | null;
      image_url: string | null;
      badge_grouping_id: number | null;
      badge_type_id: number;
    }
  >;
};

/** Raw summaries become ActionSummary instances during munge; zero counts may be omitted by the server. */
export type PostActionSummaryData = Pick<ActionSummaryFields, "id"> &
  Partial<
    Pick<ActionSummaryFields, "count" | "acted" | "can_act" | "can_undo">
  >;

/** Creation accepts transport summaries as well as already hydrated action models. */
export type PostCreateAttrs<M> = RestModelAttrs<Omit<M, "actions_summary">> & {
  actions_summary?: (PostActionSummaryData | ActionSummary)[];
};

type PostMungePayload = RestPayload & {
  actions_summary?: (Partial<ActionSummaryFields> & { id: number })[];
  actionByName?: PostFields["actionByName"];
  likeAction?: ActionSummary | null;
  reply_to_user?: PostFields["reply_to_user"];
};

type PostMungedPayload = RestPayload &
  Pick<PostFields, "actions_summary" | "actionByName" | "likeAction">;

/**
 * @internal
 * Adds a tracked property to the post model.
 *
 * Intended to be used only in the plugin API.
 *
 * @param propertyKey - The key of the property to track.
 */
export function _addTrackedPostProperty(propertyKey: string): void {
  stampModelClass(Post, "post");
  registerModelField("post", propertyKey);
}

/**
 * Clears all tracked properties added using the API
 *
 * USE ONLY FOR TESTING PURPOSES.
 */
export function clearAddedTrackedPostProperties(): void {
  clearModelFields("post");
}

/** Declares data without emitting own properties that would shadow plugin accessors. */
// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface Post extends PostFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class Post extends RestModel {
  /** Types the inherited factory's transport inputs without adding a runtime override. */
  declare static create: <C extends RestModelClass>(
    this: C,
    attrs?: PostCreateAttrs<InstanceType<C>>
  ) => InstanceType<C>;

  static override munge(json: RestPayload): PostMungedPayload;
  static override munge(json: PostMungePayload): PostMungedPayload {
    json.likeAction ??= null;
    if (json.actions_summary) {
      const lookup = EmberObject.create() as EmberObject &
        Record<string, ActionSummary>;

      // this area should be optimized, it is creating way too many objects per post
      json.actions_summary = json.actions_summary.map((a) => {
        a.actionType = Site.current().postActionTypeById(a.id)!;
        a.count = a.count || 0;
        const actionSummary = ActionSummary.create(
          a as ActionSummaryFields & RestPayload
        );
        lookup[a.actionType!.name_key] = actionSummary;

        if (a.actionType!.name_key === "like") {
          json.likeAction = actionSummary;
        }
        return actionSummary;
      });

      json.actionByName = lookup;
    }

    if (json && json.reply_to_user) {
      json.reply_to_user = User.create(json.reply_to_user);
    }

    return json as PostMungedPayload;
  }

  /** TODO(typescript-pending): ajax has no typed response contract; opaque action results stay unknown until ajax is typed. */
  static updateBookmark(
    postId: number,
    bookmarked: boolean
  ): globalThis.Promise<unknown> {
    return ajax(`/posts/${postId}/bookmark`, {
      type: "PUT",
      data: { bookmarked },
    });
  }

  static destroyBookmark(postId: number): globalThis.Promise<unknown> {
    return ajax(`/posts/${postId}/bookmark`, {
      type: "DELETE",
    });
  }

  static deleteMany(
    post_ids: number[],
    {
      agreeWithFirstReplyFlag = true,
    }: { agreeWithFirstReplyFlag?: boolean } = {}
  ): globalThis.Promise<unknown> {
    return ajax("/posts/destroy_many", {
      type: "DELETE",
      data: { post_ids, agree_with_first_reply_flag: agreeWithFirstReplyFlag },
    });
  }

  static mergePosts(post_ids: number[]): globalThis.Promise<unknown> {
    return ajax("/posts/merge_posts", {
      type: "PUT",
      data: { post_ids },
    }).catch(popupAjaxError);
  }

  static loadRevision(
    postId: number,
    version: number
  ): globalThis.Promise<EmberObject> {
    return ajax(`/posts/${postId}/revisions/${version}.json`).then(
      (result: RestPayload & { categories?: CategoryFields[] }) => {
        result.categories?.forEach((c: CategoryFields) =>
          Site.current().updateCategory(c)
        );
        return EmberObject.create(result as object);
      }
    );
  }

  static hideRevision(
    postId: number,
    version: number
  ): globalThis.Promise<unknown> {
    return ajax(`/posts/${postId}/revisions/${version}/hide`, {
      type: "PUT",
    });
  }

  static permanentlyDeleteRevisions(
    postId: number
  ): globalThis.Promise<unknown> {
    return ajax(`/posts/${postId}/revisions/permanently_delete`, {
      type: "DELETE",
    });
  }

  static showRevision(
    postId: number,
    version: number
  ): globalThis.Promise<unknown> {
    return ajax(`/posts/${postId}/revisions/${version}/show`, {
      type: "PUT",
    });
  }

  static loadRawEmail(postId: number): globalThis.Promise<unknown> {
    return ajax(`/posts/${postId}/raw-email.json`);
  }

  @service declare currentUser: User | null;
  @service declare site: Site;

  @tracked action_code?: string;

  @tracked action_code_path: unknown;
  @tracked action_code_who: unknown;
  @tracked actions_summary?: ActionSummary[];
  @tracked admin?: boolean;
  @tracked badges_granted?: RestPayload[];
  @tracked bookmarked?: boolean;
  @tracked can_delete?: boolean;
  @tracked can_permanently_delete?: boolean;
  @tracked can_recover?: boolean;
  @tracked can_see_hidden_post?: boolean;
  @tracked can_view_edit_history?: boolean;
  @tracked cooked?: string;
  @tracked cooked_hidden?: boolean;
  @tracked created_at?: string | Date;
  @tracked customShare: string | null = null;

  @tracked deleted_at?: string | Date | null;
  @tracked deleted_by?: TopicBasicUser | User | null;
  @tracked deleted_post_placeholder?: boolean;
  @tracked excerpt?: string | null;
  @tracked expandedExcerpt?: string | null;
  @tracked group_moderator?: true;
  @tracked hasGap?: boolean;
  @tracked hidden?: boolean;
  @tracked id!: number;
  @tracked is_auto_generated?: true;
  @tracked is_localized?: boolean;
  @tracked language?: string;
  @tracked last_wiki_edit?: string;
  @tracked likeAction?: ActionSummary | null;
  @tracked
  link_counts?: {
    url: string;
    internal: boolean;
    reflection: boolean | null;
    clicks: number;
    title?: string | null;
  }[];
  @tracked localization_outdated?: boolean;
  @tracked localizedCooked?: string | null;
  @tracked
  localized_oneboxes?: {
    topic_id: number;
    post_number: number;
    title?: string;
    excerpt?: string;
  }[];
  @tracked locked?: boolean;
  @tracked moderator?: boolean;
  @tracked name?: string | null;
  @tracked notice?: PostNotice | null;
  @tracked notice_created_by_user?: TopicBasicUser | null;
  @tracked post_localizations?: unknown[];
  @tracked post_number!: number;
  @tracked post_type?: number;
  @tracked primary_group_name?: string | null;
  @tracked quoted?: unknown;
  @tracked read?: boolean;
  @tracked readers_count?: number;
  @tracked reply_count?: number;
  @tracked
  reply_to_user?:
    | User
    | (Pick<TopicBasicUser, "username" | "avatar_template"> &
        Partial<TopicBasicUser>)
    | null;
  @tracked staff?: boolean;
  @tracked staged?: boolean;
  @tracked title_is_group?: boolean;
  @tracked topic?: Topic;
  @tracked topic_id?: number;
  @tracked trust_level?: number | null;
  @tracked updated_at?: string;
  @tracked user_custom_fields?: Record<string, unknown>;
  @tracked user_deleted?: boolean;
  @tracked user_id?: number | null;
  @tracked user_locale?: string;
  @tracked user_suspended?: true;
  @tracked user_title?: string | null;
  @tracked username?: string | null;
  @tracked version?: number;
  @tracked via_email?: boolean;
  @tracked wiki?: boolean;
  @tracked yours?: boolean;
  declare appEvents: AppEventsService;
  @tracked _can_edit?: boolean;

  @dependentKeyCompat
  get can_edit(): boolean | undefined {
    return applyValueTransformer("post-can-edit", this._can_edit, {
      post: this,
    });
  }

  set can_edit(value: boolean | undefined) {
    this._can_edit = value;
  }

  @dependentKeyCompat
  get canEdit(): boolean | undefined {
    return this.can_edit;
  }

  set canEdit(value: boolean | undefined) {
    this.can_edit = value;
  }

  @computed("topic.details.created_by.id")
  get topicCreatedById() {
    return (this.topic?.details as PostTopicDetails | undefined)?.created_by
      ?.id;
  }

  set topicCreatedById(value: number | undefined) {
    set(this, "topic.details.created_by.id", value);
  }

  @dependentKeyCompat
  get new_user() {
    return this.trust_level === 0;
  }

  @dependentKeyCompat
  get firstPost() {
    return this.post_number === 1;
  }

  /** Treats the first post as deleted with its topic, while allowing recovery. */
  @computed("firstPost", "topic.deleted_at")
  get deletedViaTopic() {
    return this.firstPost && this.topic?.deleted_at;
  }

  @computed("deleted_at", "deletedViaTopic")
  get deleted() {
    return this.deleted_at || this.deletedViaTopic;
  }

  @computed("deleted")
  get notDeleted() {
    return !this.deleted;
  }

  @dependentKeyCompat
  get recoverable() {
    return this.deleted_at || this.user_deleted;
  }

  @computed("topic.details.created_by.id", "user_id")
  get topicOwner() {
    return deepEqual(
      (this.topic?.details as PostTopicDetails | undefined)?.created_by?.id,
      this.user_id
    );
  }

  get shareUrl() {
    return this.customShare || resolveShareUrl(this.url, this.currentUser);
  }

  @computed("name", "username")
  get showName() {
    return (
      this.name &&
      this.name !== this.username &&
      this.siteSettings.display_name_on_posts
    );
  }

  get deletedBy() {
    return this.firstPost ? this.topic?.deleted_by : this.deleted_by;
  }

  get deletedAt() {
    return this.firstPost ? this.topic?.deleted_at : this.deleted_at;
  }

  @computed("post_number", "topic_id", "topic.slug")
  get url(): string {
    return postUrl(
      this.topic?.slug || this.topic_slug,
      this.topic_id || this.get("topic.id"),
      this.post_number
    );
  }

  /** Keeps the /1 on first-post URLs. */
  @computed("post_number", "url")
  get urlWithNumber() {
    return this.post_number === 1 ? `${this.url}/1` : this.url;
  }

  @computed("username")
  get usernameUrl(): string {
    return userPath(this.username);
  }

  get internalLinks() {
    if (isEmpty(this.link_counts)) {
      return null;
    }

    return this.link_counts!.filter((link) => link.internal && link.title);
  }

  @computed("actions_summary.@each.can_act")
  get flagsAvailable() {
    // TODO: Investigate why `this.site` is sometimes null when running
    // Search - Search with context
    if (!this.site) {
      return [];
    }

    return this.site.flagTypes.filter((item) =>
      this.get(`actionByName.${item.name_key}.can_act`)
    );
  }

  @computed("siteSettings.use_pg_headlines_for_excerpt", "topic_title_headline")
  get useTopicTitleHeadline() {
    return (
      this.siteSettings?.use_pg_headlines_for_excerpt &&
      this.topic_title_headline
    );
  }

  @computed("topic_title_headline")
  get topicTitleHeadline(): string {
    return fancyTitle(
      this.topic_title_headline,
      this.siteSettings.support_mixed_text_direction
    );
  }

  get canBookmark() {
    return !!this.currentUser;
  }

  get canDelete() {
    return (
      this.can_delete &&
      !this.deleted_at &&
      this.currentUser &&
      (this.currentUser.staff || !this.user_deleted)
    );
  }

  get canDeleteTopic() {
    return (
      this.firstPost &&
      !this.deleted &&
      (this.topic!.details as PostTopicDetails).can_delete
    );
  }

  get canEditStaffNotes() {
    return !!(this.topic!.details as PostTopicDetails).can_edit_staff_notes;
  }

  get canFlag() {
    return !this.topic!.deleted && !isEmpty(this.flagsAvailable);
  }

  get canManage() {
    return this.currentUser?.canManageTopic;
  }

  get canPermanentlyDelete() {
    return (
      this.deleted &&
      (this.firstPost
        ? (this.topic!.details as PostTopicDetails).can_permanently_delete
        : this.can_permanently_delete)
    );
  }

  get canPublishPage() {
    return (
      this.firstPost &&
      !!(this.topic!.details as PostTopicDetails).can_publish_page
    );
  }

  get canRecoverTopic() {
    return (
      this.firstPost &&
      (this.deleted || this.user_deleted) &&
      (this.topic!.details as PostTopicDetails).can_recover
    );
  }

  get isRecoveringTopic() {
    return (
      this.firstPost &&
      !this.deleted &&
      !this.user_deleted &&
      (this.topic!.details as PostTopicDetails).can_recover
    );
  }

  get canRecover() {
    return !this.canRecoverTopic && this.recoverable && this.can_recover;
  }

  get isRecovering() {
    return !this.isRecoveringTopic && !this.recoverable && this.can_recover;
  }

  get canSplitMergeTopic() {
    return !!(this.topic?.details as PostTopicDetails | undefined)
      ?.can_split_merge_topic;
  }

  get canToggleLike() {
    return !!this.likeAction?.get("canToggle");
  }

  get filteredRepliesPostNumber() {
    return this.topic!.get("postStream.filterRepliesToPostNumber");
  }

  get hasReplies() {
    return this.reply_count! > 0;
  }

  get isWhisper() {
    return this.post_type === this.site.post_types!.whisper;
  }

  get isModeratorAction() {
    return this.post_type === this.site.post_types!.moderator_action;
  }

  get isWarning() {
    return this.topic?.is_warning;
  }

  get isSmallAction() {
    return applyValueTransformer(
      "post-is-small-action",
      this.post_type === this.site.post_types!.small_action ||
        this.action_code === "split_topic",
      { post: this }
    );
  }

  get liked() {
    return !!this.likeAction?.get("acted");
  }

  get likeCount() {
    return this.likeAction?.get("count");
  }

  /**
   * Show a "Flag to delete" message if not staff and you can't otherwise delete it.
   */
  get showFlagDelete() {
    return (
      !this.canDelete &&
      this.yours &&
      this.canFlag &&
      this.currentUser &&
      !this.currentUser.staff
    );
  }

  get showLike() {
    if (
      !this.currentUser ||
      (this.topic?.get("archived") && this.user_id !== this.currentUser.id)
    ) {
      return true;
    }

    return this.likeAction && (this.liked || this.canToggleLike);
  }

  @cached
  get user(): User | null {
    if (!this.user_id || !this.username) {
      // If we don't have at least user_id and username, we can't create a User instance.
      return null;
    }

    // Using store.createRecord can lead to issues when updating existing models in the cache, potentially causing
    // rendering errors if the cached model is currently being rendered.
    // Instead, User.create ensures we get a fresh instance every time without affecting the cache.
    // The @cached decorator ensures this computation only happens once and is cached until dependencies are updated.
    return User.create({
      id: this.user_id,
      username: this.username,
      name: this.name,
      admin: this.admin,
      avatar_template: this.avatar_template,
      flair_bg_color: this.flair_bg_color,
      flair_color: this.flair_color,
      flair_group_id: this.flair_group_id,
      flair_name: this.flair_name,
      flair_url: this.flair_url,
      locale: this.user_locale,
      moderator: this.moderator,
      primary_group_name: this.primary_group_name,
      status: this.user_status,
      title: this.user_title,
      trust_level: this.trust_level,
      custom_fields: this.user_custom_fields,
    });
  }

  get topicNotificationLevel() {
    return (this.topic!.details as PostTopicDetails).notification_level;
  }

  get userBadges() {
    if (!this.topic?.user_badges) {
      return;
    }
    const badgeIds = (this.topic.user_badges as PostTopicBadges).users[
      this.user_id!
    ]?.badge_ids;
    if (badgeIds) {
      return badgeIds.map(
        (badgeId) =>
          (this.topic!.user_badges as PostTopicBadges).badges[badgeId]
      );
    }
  }

  /** TODO(typescript-pending): Badge.createFromJson infers WarpRestModel wrappers; remove the cast when Badge returns its own type. */
  @cached
  get badgesGranted(): (Badge | undefined)[] | undefined {
    return this.badges_granted?.map((json) => {
      const badges = Badge.createFromJson(json);
      return (Array.isArray(badges) ? badges[0] : badges) as Badge | undefined;
    });
  }

  get requestedGroupName() {
    return this.post_number === 1 ? this.topic?.requested_group_name : null;
  }

  get expandablePost() {
    return this.post_number === 1 && !!this.topic?.expandable_first_post;
  }

  get topicUrl() {
    return this.topic?.url;
  }

  @cached
  get actionsSummary() {
    return this.actions_summary
      ?.filter((postAction) => {
        return postAction.actionType!.name_key !== "like" && postAction.acted;
      })
      ?.map((postAction) => {
        return {
          id: postAction.id,
          postId: this.id,
          action: postAction.actionType!.name_key,
          canUndo: postAction.can_undo,
          description: postAction.actionType!.translatedDescription,
        };
      });
  }

  get displayDate() {
    if (this.wiki && this.last_wiki_edit) {
      return this.last_wiki_edit;
    } else {
      return this.created_at;
    }
  }

  updatePostField(field: string, value: unknown): globalThis.Promise<unknown> {
    const data: RestPayload = {};
    data[field] = value;

    return ajax(`/posts/${this.id}/${field}`, { type: "PUT", data })
      .then((response: unknown) => {
        this.set(field, value);
        return response;
      })
      .catch(popupAjaxError);
  }

  override afterUpdate(
    res: RestModelSaveResult & { category?: CategoryFields }
  ) {
    if (res.category) {
      this.site.updateCategory(res.category);
    }
  }

  updateProperties() {
    return {
      post: { raw: this.raw, edit_reason: this.editReason },
      image_sizes: this.imageSizes,
    };
  }

  override createProperties(): RestPayload {
    // composer only used once, defer the dependency
    // TODO(typescript-pending): Composer serialization is extensible and has no typed field map; remove when Composer is converted.
    const data = this.getProperties(
      Composer.serializedFieldsForCreate() as (keyof this)[]
    ) as RestPayload & { meta_data?: RestPayload };
    data.reply_to_post_number = this.reply_to_post_number;
    data.image_sizes = this.imageSizes;

    const metaData = this.metaData;

    // Put the metaData into the request
    if (metaData) {
      data.meta_data = {};
      Object.keys(metaData).forEach(
        (key) => (data.meta_data![key] = metaData[key])
      );
    }

    return data;
  }

  /** Expands the first post's content, if embedded and shortened. */
  async expand() {
    try {
      const post = (await ajax(`/posts/${this.id}/expand-embed`)) as {
        cooked: string;
      };
      this.cooked = `<section class="expanded-embed">${post.cooked}</section>`;
    } catch (error) {
      popupAjaxError.call(this, error);
      throw error;
    }
  }

  /** Recovers a deleted post, restoring its state if the request fails. */
  recover() {
    const initProperties = this.getProperties(
      "deleted_at",
      "deleted_by",
      "user_deleted",
      "can_delete"
    );

    this.setProperties({
      deleted_at: null,
      deleted_by: null,
      user_deleted: false,
      can_delete: false,
    });

    return ajax(`/posts/${this.id}/recover`, {
      type: "PUT",
    })
      .then((data: { cooked: string; raw: string; version: number }) => {
        this.setProperties({
          cooked: data.cooked,
          raw: data.raw,
          user_deleted: false,
          can_delete: true,
          version: data.version,
        });
      })
      .catch((error) => {
        popupAjaxError(error);
        this.setProperties(initProperties);
      });
  }

  /**
   Changes the state of the post to be deleted. Does not call the server, that should be
   done elsewhere.
   **/
  setDeletedState(deletedBy: User) {
    let promise;
    this.set("oldCooked", this.cooked);
    this.set("oldCanEdit", this.can_edit);

    // Moderators can delete posts. Users can only trigger a deleted at message, unless delete_removed_posts_after is 0.
    if (deletedBy.staff || this.siteSettings.delete_removed_posts_after === 0) {
      this.setProperties({
        deleted_at: new Date(),
        deleted_by: deletedBy,
        can_delete: false,
        can_permanently_delete:
          this.siteSettings.can_permanently_delete && deletedBy.admin,
        can_recover: true,
      });
    } else {
      const key =
        this.post_number === 1
          ? "topic.deleted_by_author_simple"
          : "post.deleted_by_author_simple";
      promise = cook(i18n(key)).then((cooked) => {
        this.setProperties({
          cooked,
          can_delete: false,
          can_permanently_delete: false,
          version: this.version! + 1,
          can_recover: true,
          can_edit: false,
          user_deleted: true,
        });
      });
    }

    return promise || Promise.resolve();
  }

  /**
   Changes the state of the post to NOT be deleted. Does not call the server.
   This can only be called after setDeletedState was called, but the delete
   failed on the server.
   **/
  undoDeleteState({ force_destroy = false }: { force_destroy?: boolean } = {}) {
    if (force_destroy || !this.oldCooked) {
      return;
    }

    this.setProperties({
      deleted_at: null,
      deleted_by: null,
      cooked: this.oldCooked,
      version: this.version! - 1,
      can_recover: false,
      can_delete: true,
      user_deleted: false,
      can_edit: this.oldCanEdit ?? false,
    });
  }

  /** Preserves EmberObject assignability without exposing its synchronous destroy API. */
  destroy(this: never, ...args: never[]): never;
  destroy(
    deletedBy: User,
    opts?: { force_destroy?: boolean; [key: string]: unknown }
  ): globalThis.Promise<unknown>;

  destroy(
    deletedBy: User,
    opts: { force_destroy?: boolean; [key: string]: unknown } | undefined
  ) {
    const maybeSetDeletedState = opts?.force_destroy
      ? Promise.resolve()
      : this.setDeletedState(deletedBy);

    return maybeSetDeletedState.then(() => {
      return ajax(`/posts/${this.id}`, {
        data: { context: window.location.pathname, ...opts },
        type: "DELETE",
      });
    });
  }

  /**
   * Updates a post from another's attributes. This will normally happen when a post is loading but
   * is already found in an identity map.
   **/
  updateFromPost(otherPost: Post) {
    [
      ...Object.keys(otherPost),
      ...enumerateTrackedKeys(otherPost),
      ...modelFieldNames("post"),
    ].forEach((key) => {
      // Plugin field names are open-ended; the reply-user branch is the only structural read.
      // TODO(typescript-pending): plugin-registered field names have no typed map; remove these structural casts when that map is typed.
      let value = (otherPost as unknown as Record<string, unknown>)[key],
        oldValue = (this as unknown as Record<string, unknown>)[key];

      if (!value) {
        value = null;
      }
      if (!oldValue) {
        oldValue = null;
      }

      let skip = false;
      if (typeof value !== "function" && oldValue !== value) {
        // wishing for an identity map
        if (key === "reply_to_user" && value && oldValue) {
          skip =
            (value as Pick<TopicBasicUser, "username">).username ===
              (oldValue as Pick<TopicBasicUser, "username">).username ||
            get(value as object, "username") ===
              get(oldValue as object, "username");
        } else if (key === "topic" && !value && oldValue) {
          // if `topic` is already set in the new instance we don't want to overwrite it with null, because the old
          // instance wasn't fully initialized yet.
          skip = true;
        }

        if (!skip) {
          this.set(key as keyof this, value as this[keyof this]);
        }
      }
    });
  }

  expandHidden() {
    return ajax(`/posts/${this.id}/cooked.json`).then(
      (result: { cooked: string }) => {
        this.setProperties({ cooked: result.cooked, cooked_hidden: false });
      }
    );
  }

  async toggleLocalizedContent() {
    if (this.localizedCooked) {
      this.setProperties({
        cooked: this.localizedCooked,
        localizedCooked: null,
      });
    } else {
      const result = (await ajax(`/posts/${this.id}/cooked.json`)) as {
        cooked: string;
      };

      this.setProperties({
        localizedCooked: this.cooked,
        cooked: result.cooked,
      });
    }
  }

  rebake(): globalThis.Promise<unknown> {
    return ajax(`/posts/${this.id}/rebake`, { type: "PUT" }).catch(
      popupAjaxError
    );
  }

  unhide(): globalThis.Promise<unknown> {
    return ajax(`/posts/${this.id}/unhide`, { type: "PUT" });
  }

  createBookmark(data: {
    id?: number;
    name?: string | null;
    reminder_at: string | null;
    auto_delete_preference: number;
  }) {
    this.setProperties({
      "topic.bookmarked": true,
      bookmarked: true,
      bookmark_reminder_at: data.reminder_at,
      bookmark_auto_delete_preference: data.auto_delete_preference,
      bookmark_name: data.name,
      bookmark_id: data.id,
    });
    this.topic!.incrementProperty("bookmarksWereChanged");
    this.appEvents.trigger("bookmarks:changed", data, {
      target: "post",
      targetId: this.id,
    });
  }

  deleteBookmark(bookmarked: boolean) {
    this.set("topic.bookmarked", bookmarked);
    this.clearBookmark();
  }

  clearBookmark() {
    this.setProperties({
      bookmark_reminder_at: null,
      bookmark_name: null,
      bookmark_id: null,
      bookmarked: false,
      bookmark_auto_delete_preference: null,
    });
    this.topic!.incrementProperty("bookmarksWereChanged");
    this.appEvents.trigger("bookmarks:changed", null, {
      target: "post",
      targetId: this.id,
    });
  }

  updateActionsSummary(json: unknown) {
    if (json && (json as RestPayload).id === this.id) {
      json = Post.munge(json as RestPayload);
      this.set("actions_summary", (json as PostMungedPayload).actions_summary);
    }
  }

  /* eslint-disable prefer-const -- Preserve the JavaScript emitted before this types-only port. */
  updateLikeCount(count: number, userId: number, eventType: string) {
    let ownAction = this.currentUser?.id === userId;
    let ownLike = ownAction && eventType === "liked";
    let current_actions_summary = this.get("actions_summary");
    let likeActionID = Site.current().post_action_types!.find(
      (a) => a.name_key === "like"
    )!.id;
    const newActionObject: {
      id: number;
      count: number;
      acted: boolean | undefined;
    } = { id: likeActionID, count, acted: ownLike };

    if (!this.actions_summary!.find((entry) => entry.id === likeActionID)) {
      let json = Post.munge({
        id: this.id,
        actions_summary: [newActionObject],
      });
      this.set(
        "actions_summary",
        Object.assign(current_actions_summary!, json.actions_summary)
      );
      this.set("actionByName", json.actionByName);
      this.set("likeAction", json.likeAction);
    } else {
      newActionObject.acted =
        (ownLike || this.likeAction!.acted) &&
        !(eventType === "unliked" && ownAction);

      Object.assign(
        this.actions_summary!.find((entry) => entry.id === likeActionID)!,
        newActionObject
      );
      Object.assign(this.actionByName!["like"], newActionObject);
      Object.assign(this.likeAction!, newActionObject);
    }
  }

  /* eslint-enable prefer-const */

  revertToRevision(version: number): globalThis.Promise<unknown> {
    return ajax(`/posts/${this.id}/revisions/${version}/revert`, {
      type: "PUT",
    });
  }
}
