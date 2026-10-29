import { cached, tracked } from "@glimmer/tracking";
import EmberObject, { computed, set } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { Promise } from "rsvp";
import { resolveShareUrl } from "discourse/helpers/share-url";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { removeValuesFromArray } from "discourse/lib/array-tools";
import { TOPIC_VISIBILITY_REASONS } from "discourse/lib/constants";
import deprecated from "discourse/lib/deprecated";
import { longDate } from "discourse/lib/formatter";
import getURL from "discourse/lib/get-url";
import {
  clearModelFields,
  registerModelField,
  stampModelClass,
} from "discourse/lib/model-extensions";
import { applyModelTransformations } from "discourse/lib/model-transformers";
import { deepEqual, deepMerge } from "discourse/lib/object";
import PreloadStore from "discourse/lib/preload-store";
import { serializeTags } from "discourse/lib/serialize-tags";
import { emojiUnescape } from "discourse/lib/text";
import { fancyTitle } from "discourse/lib/topic-fancy-title";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import {
  applyBehaviorTransformer,
  applyValueTransformer,
} from "discourse/lib/transformer";
import DiscourseURL, { userPath } from "discourse/lib/url";
import ActionSummary, {
  type ActionSummaryFields,
} from "discourse/models/action-summary";
import type Archetype from "discourse/models/archetype";
import Bookmark from "discourse/models/bookmark";
import type Post from "discourse/models/post";
import type PostStream from "discourse/models/post-stream";
import type PublishedPage from "discourse/models/published-page";
import RestModel, {
  type RestModelAttrs,
  type RestModelClass,
  type RestPayload,
} from "discourse/models/rest";
import Site from "discourse/models/site";
import TopicDetails from "discourse/models/topic-details";
import type User from "discourse/models/user";
import type AppEventsService from "discourse/services/app-events";
import { flushMap } from "discourse/services/store";
import { i18n } from "discourse-i18n";
import Category, { type CategoryFields } from "./category.ts";

/** A tag attached to a topic. */
export interface TopicTag {
  id: number;
  name: string;
  slug: string;
}

/** An original or resized topic image; originals have no maximum dimensions. */
export interface TopicThumbnail {
  max_width: number | null;
  max_height: number | null;
  width: number;
  height: number;
  url: string;
}

/** A scheduled status change; status_type names the timer action. */
export interface TopicTimerData {
  id: number;
  execute_at: string;
  duration_minutes: number | null;
  based_on_last_post: boolean;
  status_type: string;
  category_id: number | null;
}

/** A queued post; raw is included only when available to the viewer. */
export interface TopicPendingPost {
  id: number;
  created_at: string;
  raw?: string;
}

/** Publication settings for a topic; id identifies the topic. */
export interface TopicPublishedPage {
  id: number;
  slug: string;
  public: boolean;
}

/** A bookmark in a topic view; topic-level bookmarks have no post number. */
export interface TopicBookmarkData {
  id: number;
  bookmarkable_id: number;
  bookmarkable_type: "Post" | "Topic";
  reminder_at: string | null;
  name: string | null;
  auto_delete_preference: number;
  post_number: number | null;
}

/** An available topic action before create wraps it in an ActionSummary. */
export interface TopicActionSummaryData {
  id: number;
  count: 0;
  hidden: false;
  can_act: boolean;
}

/** A user summary; name is included only when names are enabled. */
export interface TopicBasicUser {
  id: number;
  username: string;
  name?: string | null;
  avatar_template: string;
}

type TopicTimerValue = TopicTimerData | EmberObject | null;

/**
 * Core payload and client-assigned fields; extensions can augment this interface.
 * Most are optional because routes and bookmark lists create partial topics.
 */
export interface TopicFields {
  id: number;
  bookmarks: (TopicBookmarkData | Bookmark)[];

  actions_summary?: (TopicActionSummaryData | ActionSummary)[];
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
  deleted_by?: TopicBasicUser | User | null;
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
  last_poster?: TopicBasicUser | null;
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
  participants?: TopicParticipant[];
  pending_posts?: TopicPendingPost[];
  pinned?: boolean;
  pinned_at?: string | null;
  pinned_globally?: boolean;
  pinned_until?: string | null;
  pm_with_non_human_user?: boolean;
  post_stream?: object;
  posted?: boolean;
  posters?: TopicPoster[] & {
    /** Present on legacy array wrappers; plain arrays do not supply this property. */
    firstObject?: TopicPoster;
  };
  posts_count?: number;
  published_page?: TopicPublishedPage;
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
  tags?: TopicTag[];
  tags_descriptions?: Record<string, string>;
  thumbnails?: TopicThumbnail[] | null;
  timeline_lookup?: [number, number][];
  title?: string;
  topic_timer?: TopicTimerValue;
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
  original_tags?: TopicTag[] | null;
  original_title?: string | null;
  pinnedGloballyUntil?: string | null;
  pinnedInCategoryUntil?: string | null;
  prevent_sync?: true;
  publishedPage?: PublishedPage | null;
  topic_status_update?: TopicTimerValue;
}

/** A poster reference, with optional list-hydrated user and primary group. */
export interface TopicPoster {
  user_id: number;
  extras: string | null;
  description: string | null;
  primary_group_id: number | null;
  flair_group_id: number | null;
  user?: User;
  primary_group?: EmberObject & { id: number; name: string };
  extraClasses?: string | null;
}

/** Participants receive users, but do not receive poster group or CSS hydration. */
export type TopicParticipant = Pick<
  TopicPoster,
  | "user_id"
  | "extras"
  | "description"
  | "primary_group_id"
  | "flair_group_id"
  | "user"
>;

/** featuredUsers mutates the posters array, inserting participants and a count marker. */
export type TopicFeaturedUser =
  | (TopicParticipant &
      Partial<Pick<TopicPoster, "primary_group" | "extraClasses">>)
  | {
      moreCount: string;
      user?: undefined;
      user_id?: undefined;
      extras?: undefined;
    };

type TopicTagInput =
  | string
  | { name: string; id?: number; slug?: string; isNew?: boolean };

/** Creation attributes for a topic; details may be a plain payload, which the setter wraps in TopicDetails. */
export type TopicCreateAttrs<M> = RestModelAttrs<Omit<M, "details">> & {
  details?: object;
};

type TopicUpdateProperties = Partial<Omit<TopicFields, "tags">> & {
  categoryId?: number | null;
  tags?: TopicTagInput[];
  [key: string]: unknown;
};

type TopicBulkOperation = { type: string; [key: string]: unknown };

type TopicBulkOptions = {
  silent?: boolean;
  asJSON?: boolean;
  categoryId?: number;
  includeSubcategories?: boolean;
  tagName?: string;
  private_message_inbox?: string;
  group_name?: string;
};

/** Payloads may contain response-only keys that do not become declared fields. */
type TopicResponse = Partial<TopicFields> &
  RestPayload & {
    categories?: RestModelAttrs<Category>[];
    details?: object;
  };

/** The ajax promise as the change-owner and change-timestamp bodies treat it. */
// TODO(typescript-pending): those bodies assume a reject method absent from ajax's native Promise; remove this internal cast when they are corrected.
type TopicOperationPromise = globalThis.Promise<RestPayload | undefined> & {
  reject(error: Error): void;
};

export function _addTrackedTopicProperty(propertyKey: string): void {
  stampModelClass(Topic, "topic");
  registerModelField("topic", propertyKey);
}

export function clearAddedTrackedTopicProperties(): void {
  clearModelFields("topic");
}

export function loadTopicView(
  topic: Topic,
  args: RestPayload
): globalThis.Promise<TopicResponse> {
  const data = deepMerge({}, args) as RestPayload;
  const url = `/t/${topic.id}`;
  const jsonUrl = (data.nearPost ? `${url}/${data.nearPost}` : url) + ".json";

  delete data.nearPost;
  delete data.__type;
  delete data.store;

  return PreloadStore.getAndRemove(`topic_${topic.id}`, () =>
    ajax(jsonUrl, { data })
  ).then(async (json: TopicResponse) => {
    json.categories?.forEach((c) => topic.site.updateCategory(c));
    topic.updateFromJson(json);
    await Topic.applyTransformations([topic]);
    return json;
  });
}

export const ID_CONSTRAINT = /^\d+$/;
const _customLastUnreadUrlCallbacks: ((
  topic: Topic
) => string | null | undefined)[] = [];

/** Merges in TopicFields so create can assign them without field initializers. */
// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface Topic extends TopicFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class Topic extends RestModel {
  static NotificationLevel = {
    WATCHING: 3,
    TRACKING: 2,
    REGULAR: 1,
    MUTED: 0,
  };

  static override munge(json: RestPayload): RestPayload {
    // ensure we are not overriding category computed property
    delete json.category;
    json.bookmarks = json.bookmarks || [];
    return json;
  }

  static createActionSummary(result: Topic): void {
    if (result.actions_summary) {
      const lookup = EmberObject.create();
      result.actions_summary = result.actions_summary.map(
        (a: ActionSummaryFields) => {
          a.post = result;
          a.actionType = Site.current().postActionTypeById(a.id)!;
          const actionSummary = ActionSummary.create(
            a as typeof a & RestPayload
          );
          lookup.set(a.actionType.get("name_key"), actionSummary);
          return actionSummary;
        }
      );
      result.set("actionByName", lookup);
    }
  }

  static update(
    topic: Topic,
    props: TopicUpdateProperties,
    opts: { fastEdit?: boolean } = {}
  ): globalThis.Promise<void> {
    // We support `category_id` and `categoryId` for compatibility
    if (typeof props.categoryId !== "undefined") {
      props.category_id = props.categoryId;
      delete props.categoryId;
    }

    // Make sure we never change the category for private messages
    if (topic.get("isPrivateMessage")) {
      delete props.category_id;
    }

    const data: RestPayload = { ...props };

    if (Array.isArray(data.tags)) {
      data.tags = serializeTags(data.tags);
    }

    if (opts.fastEdit) {
      data.keep_existing_draft = true;
    }
    return ajax(topic.get("updateUrl") || topic.get("url"), {
      type: "PUT",
      data: JSON.stringify(data),
      contentType: "application/json",
    }).then(
      (result: {
        basic_topic: { title: string; fancy_title: string };
        tags?: TopicTag[];
      }) => {
        // The title can be cleaned up server side
        props.title = result.basic_topic.title;
        props.fancy_title = result.basic_topic.fancy_title;
        if (result.tags) {
          props.tags = result.tags;
        }
        if (topic.is_shared_draft) {
          props.destination_category_id = props.category_id;
          delete props.category_id;
        }
        topic.setProperties(props);
      }
    );
  }

  static override create<C extends RestModelClass>(
    this: C,
    ...args: [attrs?: TopicCreateAttrs<InstanceType<C>>]
  ): InstanceType<C> {
    // TODO(typescript-pending): RestModelAttrs uses getter types for setter inputs; remove when it models creation inputs separately.
    const result = super.create.apply(
      this,
      args as [attrs?: RestModelAttrs<InstanceType<C>>]
    ) as InstanceType<C> & Topic;
    // The polymorphic receiver retains the subclass's static action-summary hook.
    (this as C & Pick<typeof Topic, "createActionSummary">).createActionSummary(
      result
    );
    return result;
  }

  /** Loads a topic, accepting a set of filters. */
  static find(
    topicId: number | string,
    opts: {
      nearPost?: number | string;
      postsAfter?: number;
      postsBefore?: number;
      trackVisit?: boolean;
      userFilters?: string[];
      summary?: boolean;
    }
  ): globalThis.Promise<TopicResponse> {
    let url = getURL("/t/") + topicId;
    if (opts.nearPost) {
      url += `/${opts.nearPost}`;
    }

    const data: RestPayload = {};
    if (opts.postsAfter) {
      data.posts_after = opts.postsAfter;
    }
    if (opts.postsBefore) {
      data.posts_before = opts.postsBefore;
    }
    if (opts.trackVisit) {
      data.track_visit = true;
    }

    // Add username filters if we have them
    if (opts.userFilters && opts.userFilters.length > 0) {
      data.username_filters = [];
      opts.userFilters.forEach(function (username) {
        (data.username_filters as string[]).push(username);
      });
    }

    // Add the summary of filter if we have it
    if (opts.summary === true) {
      data.summary = true;
    }

    // Check the preload store. If not, load it via JSON
    return ajax(`${url}.json`, { data });
  }

  static changeOwners(
    topicId: number,
    opts: object
  ): globalThis.Promise<RestPayload | undefined> {
    const promise = ajax(`/t/${topicId}/change-owner`, {
      type: "POST",
      data: opts,
    }).then((result: RestPayload) => {
      if (result.success) {
        return result;
      }
      promise.reject(new Error("error changing ownership of posts"));
    }) as TopicOperationPromise;
    return promise;
  }

  static changeTimestamp(
    topicId: number,
    timestamp: number
  ): globalThis.Promise<RestPayload | undefined> {
    const promise = ajax(`/t/${topicId}/change-timestamp`, {
      type: "PUT",
      data: { timestamp },
    }).then((result: RestPayload) => {
      if (result.success) {
        return result;
      }
      promise.reject(new Error("error updating timestamp of topic"));
    }) as TopicOperationPromise;
    return promise;
  }

  static bulkOperation(
    topics: Pick<Topic, "id">[],
    operation: TopicBulkOperation,
    options?: TopicBulkOptions,
    isTracked?: boolean
  ): globalThis.Promise<unknown> {
    const data: RestPayload = {
      topic_ids: topics.map((topic) => topic.id),
      operation,
      tracked: isTracked,
    };

    if (options) {
      if (options.silent) {
        data.silent = true;
      }
    }

    const request: {
      type: string;
      data: object | string;
      contentType?: string;
    } = {
      type: "PUT",
      data,
    };

    if (options?.asJSON) {
      request.contentType = "application/json";
      request.data = JSON.stringify(data);
    }

    return ajax("/topics/bulk", request);
  }

  static bulkOperationByFilter(
    filter: string,
    operation: TopicBulkOperation,
    options?: TopicBulkOptions,
    isTracked?: boolean
  ): globalThis.Promise<unknown> {
    const data: RestPayload = { filter, operation, tracked: isTracked };

    if (options) {
      if (options.categoryId) {
        data.category_id = options.categoryId;
      }
      if (options.includeSubcategories) {
        data.include_subcategories = true;
      }
      if (options.tagName) {
        data.tag_name = options.tagName;
      }

      if (options.private_message_inbox) {
        data.private_message_inbox = options.private_message_inbox;

        if (options.group_name) {
          data.group_name = options.group_name;
        }
      }
    }

    return ajax("/topics/bulk", {
      type: "PUT",
      data,
    });
  }

  static resetNew(
    category?: Pick<Category, "id"> | null,
    include_subcategories?: boolean,
    opts: {
      tracked?: boolean;
      tag?: { name: string } | null;
      topicIds?: number[] | null;
      dismissPosts?: boolean;
      dismissTopics?: boolean;
      untrack?: boolean;
    } = {}
  ): globalThis.Promise<unknown> {
    const {
      tracked: isTracked,
      tag,
      topicIds,
    } = {
      tracked: false,
      tag: null,
      topicIds: null,
      ...opts,
    };

    const data: RestPayload = { tracked: isTracked };
    if (category) {
      data.category_id = category.id;
      data.include_subcategories = include_subcategories;
    }
    if (tag) {
      data.tag_name = tag.name;
    }
    if (topicIds) {
      data.topic_ids = topicIds;
    }

    if (opts.dismissPosts) {
      data.dismiss_posts = opts.dismissPosts;
    }

    if (opts.dismissTopics) {
      data.dismiss_topics = opts.dismissTopics;
    }

    if (opts.untrack) {
      data.untrack = opts.untrack;
    }

    return ajax("/topics/reset-new", { type: "PUT", data });
  }

  static pmResetNew(
    opts: {
      topicIds?: number[] | null;
      inbox?: string;
      groupName?: string;
    } = {}
  ): globalThis.Promise<unknown> {
    const data: RestPayload = {};

    if (opts.topicIds) {
      data.topic_ids = opts.topicIds;
    }

    if (opts.inbox) {
      data.inbox = opts.inbox;

      if (opts.groupName) {
        data.group_name = opts.groupName;
      }
    }

    return ajax("/topics/pm-reset-new", { type: "PUT", data });
  }

  static idForSlug(slug: string): globalThis.Promise<unknown> {
    return ajax(`/t/id_for/${slug}`);
  }

  static setSlowMode(
    topicId: number,
    seconds: number,
    enabledUntil?: string | null
  ): globalThis.Promise<unknown> {
    const data: { seconds: number; enabled_until?: string | null } = {
      seconds,
    };
    data.enabled_until = enabledUntil;

    return ajax(`/t/${topicId}/slow_mode`, { type: "PUT", data });
  }

  static async applyTransformations(topics: Topic[]): globalThis.Promise<void> {
    await applyModelTransformations("topic", topics);
  }

  @service declare currentUser: User | null;
  @service declare siteSettings: RestModel["siteSettings"];

  @tracked chunk_size?: TopicFields["chunk_size"];
  @tracked deleted_at?: TopicFields["deleted_at"];
  @tracked deleted_by?: TopicFields["deleted_by"];
  @tracked errorHtml: string | null | undefined;
  @tracked errorLoading = false;
  @tracked errorMessage: string | null | undefined;
  @tracked errorTitle: string | null | undefined;
  @tracked highest_post_number?: TopicFields["highest_post_number"];
  @tracked last_posted_at?: TopicFields["last_posted_at"];
  @tracked last_read_post_number?: TopicFields["last_read_post_number"];
  @tracked noRetry: boolean | undefined;
  @tracked posts_count?: TopicFields["posts_count"];
  @tracked replies_to_post_number: string | null | undefined;
  @tracked suggested_topics?: TopicFields["suggested_topics"];
  @autoTrackedArray declare bookmarks: TopicFields["bookmarks"];
  @autoTrackedArray pending_posts?: TopicFields["pending_posts"];

  message: string | null = null;

  declare appEvents: AppEventsService;

  /** Backing instance for details. */
  // TODO(typescript-pending): store has no topicDetails registry entry; remove when TopicDetails is typed.
  @tracked
  _details = this.store.createRecord("topicDetails", {
    id: this.id,
    topic: this,
  }) as unknown as TopicDetails;

  @computed("lastPoster.user")
  get lastPosterUser(): TopicBasicUser | undefined {
    return this.lastPoster?.user;
  }

  set lastPosterUser(value: TopicBasicUser | undefined) {
    set(this, "lastPoster.user", value);
  }

  @computed("lastPoster.primary_group")
  get lastPosterGroup(): object | null | undefined {
    return this.lastPoster?.primary_group;
  }

  set lastPosterGroup(value: object | null | undefined) {
    set(this, "lastPoster.primary_group", value);
  }

  @computed("details.allowed_groups")
  get allowedGroups(): object[] | undefined {
    // TODO(typescript-pending): TopicDetails forwarders are undeclared; remove when TopicDetails is typed.
    return (this.details as TopicDetails & { allowed_groups?: object[] })
      ?.allowed_groups;
  }

  set allowedGroups(value: object[] | undefined) {
    set(this, "details.allowed_groups", value);
  }

  @computed("bookmarks.length")
  get bookmarkCount(): number {
    return this.bookmarks?.length;
  }

  set bookmarkCount(value: number) {
    set(this, "bookmarks.length", value);
  }

  get details(): TopicDetails {
    return this._details;
  }

  set details(value: TopicDetails | object) {
    if (value instanceof TopicDetails) {
      this._details = value;
      return;
    }

    // we need to ensure that details is an instance of TopicDetails
    // TODO(typescript-pending): store has no topicDetails registry entry; remove when TopicDetails is typed.
    this._details = this.store.createRecord(
      "topicDetails",
      value as RestPayload
    ) as unknown as TopicDetails;
  }

  @computed("category_id", "site.categoriesById.[]")
  get category(): Category | undefined {
    return Category.findById(this.category_id);
  }

  set category(newCategory: Category | undefined) {
    this.set("category_id", newCategory?.id);
  }

  @computed("deleted_at")
  get deleted() {
    return !isEmpty(this.deleted_at);
  }

  @computed("url")
  get printUrl() {
    return `${this.url}/print`;
  }

  @computed("archetype")
  get isPrivateMessage() {
    return this.archetype === "private_message";
  }

  @computed("archetype")
  get isBanner() {
    return this.archetype === "banner";
  }

  @computed("pinned", "category.isUncategorizedCategory")
  get isPinnedUncategorized() {
    return this.pinned && this.category?.isUncategorizedCategory;
  }

  @computed("excerpt")
  get hasExcerpt() {
    return !isEmpty(this.excerpt);
  }

  @dependentKeyCompat
  get readLastPost() {
    return deepEqual(this.last_read_post_number, this.highest_post_number);
  }

  @computed("pinned", "readLastPost")
  get canClearPin() {
    return this.pinned && this.readLastPost;
  }

  @computed("details.can_edit", "details.can_edit_tags")
  get canEditTags(): boolean | undefined {
    // TODO(typescript-pending): TopicDetails forwarders are undeclared; remove when TopicDetails is typed.
    return (
      (this.details as TopicDetails & { can_edit?: boolean })?.can_edit ||
      (this.details as TopicDetails & { can_edit_tags?: boolean })
        ?.can_edit_tags
    );
  }

  @computed("last_read_post_number", "highest_post_number")
  get visited() {
    // >= to handle case where there are deleted posts at the end of the topic
    return this.last_read_post_number! >= this.highest_post_number!;
  }

  @computed("posters.firstObject")
  get creator(): TopicBasicUser | undefined {
    return this.posters?.firstObject && this.posters?.firstObject?.user;
  }

  @computed("posters.[]")
  get lastPoster(): TopicPoster | undefined {
    if (this.posters && this.posters?.length > 0) {
      const latest = this.posters?.filter((p) =>
        p.extras?.includes("latest")
      )[0];
      return latest || this.posters?.firstObject;
    }
  }

  @computed("posters.[]", "participants.[]", "allowed_user_count")
  get featuredUsers(): TopicFeaturedUser[] {
    // This aliases posters: participant insertion and the count marker mutate that same array.
    const users = this.posters as TopicFeaturedUser[];
    const maxUserCount = 5;
    const posterCount = users.length;

    if (
      this.isPrivateMessage &&
      this.participants &&
      posterCount < maxUserCount
    ) {
      let pushOffset = 0;
      if (posterCount > 1) {
        const lastUser = users[posterCount - 1];
        if (lastUser.extras && lastUser.extras.includes("latest")) {
          pushOffset = 1;
        }
      }

      const poster_ids = this.posters
        ?.map((p) => p.user && p.user.id)
        ?.filter((id) => id);
      this.participants?.some((p) => {
        if (!poster_ids!.includes(p.user_id)) {
          users.splice(users.length - pushOffset, 0, p);
          if (users.length === maxUserCount) {
            return true;
          }
        }
        return false;
      });
    }

    if (this.isPrivateMessage && this.allowed_user_count! > maxUserCount) {
      users.splice(maxUserCount - 2, 1); // remove second-last avatar
      users.push({
        moreCount: `+${this.allowed_user_count! - maxUserCount + 1}`,
      });
    }

    return users;
  }

  @computed("fancy_title")
  get fancyTitle(): string {
    return fancyTitle(
      this.fancy_title,
      this.siteSettings.support_mixed_text_direction
    );
  }

  /** Returns createdAt if there's no bumped date. */
  @computed("bumped_at", "createdAt")
  get bumpedAt() {
    if (this.bumped_at) {
      return new Date(this.bumped_at);
    } else {
      return this.createdAt;
    }
  }

  @computed("bumpedAt", "createdAt")
  get bumpedAtTitle(): string | undefined {
    const BUMPED_FORMAT = "YYYY-MM-DDTHH:mm:ss";
    if (moment(this.bumpedAt).isValid() && moment(this.createdAt).isValid()) {
      const bumpedAtStr = moment(this.bumpedAt).format(BUMPED_FORMAT);
      const createdAtStr = moment(this.createdAt).format(BUMPED_FORMAT);

      return bumpedAtStr !== createdAtStr
        ? `${i18n("topic.created_at", {
            date: longDate(this.createdAt),
          })}\n${i18n("topic.bumped_at", { date: longDate(this.bumpedAt) })}`
        : i18n("topic.created_at", { date: longDate(this.createdAt) });
    }
  }

  @computed("created_at")
  get createdAt(): Date {
    return new Date(this.created_at!);
  }

  @computed
  get postStream(): PostStream {
    return this.store.createRecord("postStream", {
      id: this.id,
      topic: this,
    });
  }

  @computed("tags")
  get visibleListTags(): TopicTag[] | undefined {
    if (!this.tags || !this.siteSettings.suppress_overlapping_tags_in_list) {
      return this.tags;
    }

    const title = this.title!.toLowerCase();
    const newTags: TopicTag[] = [];

    this.tags.forEach(function (tag) {
      const tagName = typeof tag === "string" ? tag : tag.name;
      if (!title.includes(tagName.toLowerCase())) {
        newTags.push(tag);
      }
    });

    return newTags;
  }

  @dependentKeyCompat
  @cached
  get relatedMessages(): Topic[] | undefined {
    // TODO(typescript-pending): related payloads are only object[]; remove when their topic fields are typed.
    return this.get("related_messages")?.map((data) =>
      Topic.create(data as RestModelAttrs<Topic>)
    );
  }

  @dependentKeyCompat
  @cached
  get suggestedTopics(): Topic[] | undefined {
    // TODO(typescript-pending): suggested payloads are only object[]; remove when their topic fields are typed.
    return this.get("suggested_topics")?.map((data) =>
      Topic.create(data as RestModelAttrs<Topic>)
    );
  }

  @computed("posts_count")
  get replyCount(): number {
    return applyValueTransformer("topic-reply-count", this.posts_count! - 1, {
      topic: this,
    });
  }

  @computed("visible")
  get invisible() {
    return this.visible !== undefined ? !this.visible : undefined;
  }

  @computed("visibility_reason_id")
  get visibilityReasonTranslated(): string {
    if (
      this.visibility_reason_id &&
      this.visibility_reason_id !== TOPIC_VISIBILITY_REASONS.unknown
    ) {
      const reasonKey = Object.keys(TOPIC_VISIBILITY_REASONS).find(
        (key) =>
          TOPIC_VISIBILITY_REASONS[
            key as keyof typeof TOPIC_VISIBILITY_REASONS
          ] === this.visibility_reason_id
      );
      return i18n(`topic_statuses.visibility_reasons.${reasonKey}`);
    }

    return "";
  }

  @computed("id")
  get searchContext(): { type: "topic"; id: number } {
    return { type: "topic", id: this.id };
  }

  @computed("url")
  get shareUrl(): string {
    return resolveShareUrl(this.url, this.currentUser);
  }

  @computed("id", "slug")
  get updateUrl() {
    let slug = this.slug || "";
    if (slug.trim().length === 0) {
      slug = "topic";
    }
    return `${getURL("/t/")}${slug}/${this.id}`;
  }

  @computed("id", "slug")
  get url() {
    let slug = this.slug || "";
    if (slug.trim().length === 0) {
      slug = "topic";
    }
    return `${getURL("/t/")}${slug}/${this.id}`;
  }

  @computed("unread_posts", "new_posts")
  get totalUnread() {
    deprecated("The totalUnread property of the topic model is deprecated", {
      id: "discourse.topic.totalUnread",
    });
    return this.unread_posts || this.new_posts;
  }

  @computed("unread_posts", "new_posts")
  get displayNewPosts() {
    deprecated(
      "The displayNewPosts property of the topic model is deprecated",
      { id: "discourse.topic.totalUnread" }
    );
    return this.unread_posts || this.new_posts;
  }

  @computed("last_read_post_number", "url", "is_nested_view")
  get lastReadUrl() {
    if (this.is_nested_view) {
      return this.url;
    }
    return this.urlForPostNumber(this.last_read_post_number);
  }

  @computed(
    "last_read_post_number",
    "highest_post_number",
    "url",
    "is_nested_view"
  )
  get lastUnreadUrl() {
    if (this.is_nested_view) {
      return this.url;
    }

    let customUrl: string | null = null;
    _customLastUnreadUrlCallbacks.some((cb) => {
      const result = cb(this);
      if (result) {
        customUrl = result;
        return true;
      }
    });

    if (customUrl) {
      return customUrl;
    }

    if (
      this.last_read_post_number! >= this.highest_post_number! &&
      this.get("category.navigate_to_first_post_after_read")
    ) {
      return this.urlForPostNumber(1);
    }

    let postNumber = this.last_read_post_number! + 1;
    if (postNumber > this.highest_post_number!) {
      postNumber = this.highest_post_number!;
    }

    return this.urlForPostNumber(postNumber);
  }

  @computed("highest_post_number", "url", "is_nested_view")
  get lastPostUrl() {
    if (this.is_nested_view) {
      return this.url;
    }
    return this.urlForPostNumber(this.highest_post_number);
  }

  @computed("url")
  get firstPostUrl() {
    return this.urlForPostNumber(1);
  }

  @computed("url")
  get summaryUrl() {
    const summaryQueryString = this.has_summary ? "?filter=summary" : "";
    return `${this.urlForPostNumber(1)}${summaryQueryString}`;
  }

  @computed("last_poster.username")
  get lastPosterUrl(): string {
    return userPath(this.last_poster?.username);
  }

  @computed("views")
  get viewsHeat(): "heatmap-high" | "heatmap-med" | "heatmap-low" | null {
    if (this.views! >= (this.siteSettings.topic_views_heat_high as number)) {
      return "heatmap-high";
    }
    if (this.views! >= (this.siteSettings.topic_views_heat_medium as number)) {
      return "heatmap-med";
    }
    if (this.views! >= (this.siteSettings.topic_views_heat_low as number)) {
      return "heatmap-low";
    }
    return null;
  }

  @computed("archetype")
  get archetypeObject(): Archetype | undefined {
    // TODO(typescript-pending): Archetype omits its id field; remove when Archetype is typed.
    return Site.currentProp("archetypes")!.find(
      (item) => (item as Archetype & { id: string }).id === this.archetype
    );
  }

  @computed("excerpt")
  get escapedExcerpt(): string {
    return applyValueTransformer(
      "topic-escaped-excerpt",
      emojiUnescape(this.excerpt),
      { topic: this }
    );
  }

  @computed("excerpt")
  get excerptTruncated() {
    return this.excerpt && this.excerpt.slice(-8) === "&hellip;";
  }

  urlForPostNumber(postNumber: number | null | undefined): string {
    let url = this.url;
    if (postNumber! > 0) {
      url += `/${postNumber}`;
    }
    return url;
  }

  toggleStatus(property: keyof Topic & string): globalThis.Promise<unknown> {
    this.toggleProperty(property);
    return this.saveStatus(property, !!this.get(property));
  }

  saveStatus(
    property: string,
    value: boolean,
    until?: string | null
  ): globalThis.Promise<unknown> {
    if (property === "closed") {
      this.incrementProperty("posts_count");
    }
    return ajax(`${this.updateUrl}/status`, {
      type: "PUT",
      data: {
        status: property,
        enabled: !!value,
        until,
      },
    });
  }

  makeBanner() {
    return ajax(`/t/${this.id}/make-banner`, { type: "PUT" }).then(() =>
      this.set("archetype", "banner")
    );
  }

  removeBanner() {
    return ajax(`/t/${this.id}/remove-banner`, {
      type: "PUT",
    }).then(() => this.set("archetype", "regular"));
  }

  afterPostBookmarked(
    post: Pick<Post, "set">,
    savedData?: Partial<TopicBookmarkData>
  ): void;

  afterPostBookmarked(post: Pick<Post, "set">): void {
    post.set("bookmarked", true);
  }

  firstPost(): globalThis.Promise<Post> {
    const postStream = this.postStream;
    const firstPost = postStream.posts[0];

    if (firstPost && firstPost.post_number === 1) {
      return Promise.resolve(firstPost);
    }

    const postId = postStream.findPostIdForPostNumber(1);
    if (postId) {
      return this.postById(postId);
    } else {
      return this.postStream.loadPostByPostNumber(1);
    }
  }

  postById(id: number): globalThis.Promise<Post> {
    const loaded = this.postStream.findLoadedPost(id);
    if (loaded) {
      return Promise.resolve(loaded);
    }

    return this.postStream.loadPost(id);
  }

  deleteBookmarks(): globalThis.Promise<unknown> {
    return ajax(`/t/${this.id}/remove_bookmarks`, { type: "PUT" });
  }

  removeBookmark(id: number): void {
    if (!this.bookmarks) {
      this.set("bookmarks", []);
    }
    this.set(
      "bookmarks",
      this.bookmarks.filter((bookmark) => {
        // TODO(typescript-pending): Bookmark forwarders omit payload fields; remove when Bookmark is typed.
        if (
          (bookmark as TopicBookmarkData).id === id &&
          (bookmark as TopicBookmarkData).bookmarkable_type === "Topic"
        ) {
          this.appEvents.trigger(
            "bookmarks:changed",
            null,
            (bookmark as Bookmark).attachedTo()
          );
        }

        return (bookmark as TopicBookmarkData).id !== id;
      })
    );
    this.set("bookmarked", this.bookmarks.length > 0);
    this.incrementProperty("bookmarksWereChanged");
  }

  clearBookmarks(): number[] {
    this.toggleProperty("bookmarked");

    // TODO(typescript-pending): Bookmark forwarders omit payload fields; remove when Bookmark is typed.
    const postIds = this.bookmarks
      .filter(
        (bookmark) =>
          (bookmark as TopicBookmarkData).bookmarkable_type === "Post"
      )
      .map((bookmark) => (bookmark as TopicBookmarkData).bookmarkable_id);
    postIds.forEach((postId) => {
      const loadedPost = this.postStream.findLoadedPost(postId);
      if (loadedPost) {
        loadedPost.clearBookmark();
      }
    });
    this.set("bookmarks", []);

    return postIds;
  }

  createGroupInvite(group: string): globalThis.Promise<unknown> {
    return ajax(`/t/${this.id}/invite-group`, {
      type: "POST",
      data: { group },
    });
  }

  createInvite(
    user: string,
    group_ids?: number[] | null,
    custom_message?: string
  ): globalThis.Promise<unknown> {
    return ajax(`/t/${this.id}/invite`, {
      type: "POST",
      data: { user, group_ids, custom_message },
    });
  }

  generateInviteLink(
    email: string,
    group_ids: number[] | null | undefined,
    topic_id: number | undefined
  ): globalThis.Promise<unknown> {
    return ajax("/invites", {
      type: "POST",
      data: { email, skip_email: true, group_ids, topic_id },
    });
  }

  /** The sentinel preserves EmberObject assignability without exposing synchronous destruction. */
  destroy(this: never, ...args: never[]): never;

  /** Deletes this topic. */
  destroy(
    deleted_by: User,
    opts?: { force_destroy?: boolean; [key: string]: unknown }
  ): globalThis.Promise<void>;

  destroy(
    deleted_by: User,
    opts: { force_destroy?: boolean; [key: string]: unknown } = {}
  ): globalThis.Promise<void> {
    return ajax(`/t/${this.id}`, {
      data: { context: window.location.pathname, ...opts },
      type: "DELETE",
    })
      .then(() => {
        this.setProperties({
          deleted_at: new Date().toISOString(),
          deleted_by,
          "details.can_delete": false,
          "details.can_recover": true,
          "details.can_permanently_delete":
            this.siteSettings.can_permanently_delete && deleted_by.admin,
        });
        if (
          opts.force_destroy ||
          (!deleted_by.staff &&
            !deleted_by.visibleGroups!.some((group) =>
              this.category?.moderating_group_ids?.includes(group.id)
            ) &&
            !deleted_by.can_delete_all_posts_and_topics)
        ) {
          DiscourseURL.redirectTo("/");
        }
      })
      .catch(popupAjaxError);
  }

  /** Recovers this topic if it was deleted. */
  recover(): globalThis.Promise<unknown> {
    this.setProperties({
      deleted_at: null,
      deleted_by: null,
      "details.can_delete": true,
      "details.can_recover": false,
    });
    return ajax(`/t/${this.id}/recover`, {
      data: { context: window.location.pathname },
      type: "PUT",
    });
  }

  /** Updates this topic's attributes from a JSON result. */
  updateFromJson(json: TopicResponse): this {
    // Middleware may short-circuit, but callers consume the default callback's model.
    return applyBehaviorTransformer(
      "topic-update-from-json",
      () => {
        const keys = Object.keys(json);
        if (!json.view_hidden) {
          this.details.updateFromJson(json.details);

          removeValuesFromArray(keys, ["details", "post_stream"]);

          if (json.published_page) {
            this.set(
              "publishedPage",
              this.store.createRecord(
                "published-page",
                json.published_page as TopicPublishedPage & RestPayload
              )
            );
          }
        }
        keys.forEach((key) => this.set(key, json[key]));

        if (this.bookmarks.length) {
          this.set(
            "bookmarks",
            this.bookmarks.map((bm) => Bookmark.create(bm))
          );
        }

        return this;
      },
      { topic: this, json }
    ) as this;
  }

  reload(opts: { post_number?: number } = {}): globalThis.Promise<void> {
    const url = opts.post_number
      ? `/t/${this.id}?post_number=${opts.post_number}`
      : `/t/${this.id}`;

    return ajax(url, { type: "GET" }).then((topic_json: TopicResponse) => {
      this.updateFromJson(topic_json);
    });
  }

  clearPin() {
    // Clear the pin optimistically from the object
    this.setProperties({ pinned: false, unpinned: true });

    ajax(`/t/${this.id}/clear-pin`, {
      type: "PUT",
    }).then(null, () => {
      // On error, put the pin back
      this.setProperties({ pinned: true, unpinned: false });
    });
  }

  togglePinnedForUser() {
    if (this.pinned) {
      this.clearPin();
    } else {
      this.rePin();
    }
  }

  rePin() {
    // Clear the pin optimistically from the object
    this.setProperties({ pinned: true, unpinned: false });

    ajax(`/t/${this.id}/re-pin`, {
      type: "PUT",
    }).then(null, () => {
      // On error, put the pin back
      this.setProperties({ pinned: true, unpinned: false });
    });
  }

  archiveMessage(): globalThis.Promise<{ group_name?: string } | null> {
    this.set("archiving", true);
    const promise: globalThis.Promise<{ group_name?: string } | null> = ajax(
      `/t/${this.id}/archive-message`,
      {
        type: "PUT",
      }
    );

    promise
      .then((msg) => {
        this.set("message_archived", true);
        if (msg && msg.group_name) {
          this.set("inboxGroupName", msg.group_name);
        }
      })
      .finally(() => this.set("archiving", false));

    return promise;
  }

  moveToInbox(): globalThis.Promise<{ group_name?: string } | null> {
    this.set("archiving", true);
    const promise: globalThis.Promise<{ group_name?: string } | null> = ajax(
      `/t/${this.id}/move-to-inbox`,
      { type: "PUT" }
    );

    promise
      .then((msg) => {
        this.set("message_archived", false);
        if (msg && msg.group_name) {
          this.set("inboxGroupName", msg.group_name);
        }
      })
      .finally(() => this.set("archiving", false));

    return promise;
  }

  publish(): globalThis.Promise<unknown> {
    return ajax(`/t/${this.id}/publish`, {
      type: "PUT",
      data: this.getProperties("destination_category_id"),
    })
      .then(() => this.set("destination_category_id", null))
      .catch(popupAjaxError);
  }

  updateDestinationCategory(
    categoryId: number | null
  ): globalThis.Promise<unknown> {
    this.set("destination_category_id", categoryId);
    return ajax(`/t/${this.id}/shared-draft`, {
      type: "PUT",
      data: { category_id: categoryId },
    });
  }

  convertTopic(
    type: string,
    opts?: { categoryId?: number }
  ): globalThis.Promise<unknown> {
    const args: { type: string; data?: { category_id: number } } = {
      type: "PUT",
    };
    if (opts && opts.categoryId) {
      args.data = { category_id: opts.categoryId };
    }
    return ajax(`/t/${this.id}/convert-topic/${type}`, args);
  }

  resetBumpDate(): globalThis.Promise<unknown> {
    return ajax(`/t/${this.id}/reset-bump-date`, { type: "PUT" }).catch(
      popupAjaxError
    );
  }

  updateTags(
    tags: TopicTagInput[] | null | undefined
  ): globalThis.Promise<{ tags?: TopicTag[] } | null> {
    return ajax(`/t/${this.id}/tags`, {
      type: "PUT",
      data: { tags: tags || [] },
    }).then((result: { tags?: TopicTag[] } | null) => {
      if (result?.tags) {
        this.set("tags", result.tags);
      }
      return result;
    });
  }
}

function moveResult(result: RestPayload): RestPayload {
  if (result.success) {
    // We should be hesitant to flush the map but moving ids is one rare case
    flushMap();
    return result;
  }
  throw new Error("error moving posts topic");
}

export function movePosts(
  topicId: number,
  data: object
): globalThis.Promise<RestPayload> {
  return ajax(`/t/${topicId}/move-posts`, { type: "POST", data }).then(
    moveResult
  );
}

export function mergeTopic(
  topicId: number,
  data: object
): globalThis.Promise<RestPayload> {
  return ajax(`/t/${topicId}/merge-topic`, { type: "POST", data }).then(
    moveResult
  );
}

export function registerCustomLastUnreadUrlCallback(
  fn: (topic: Topic) => string | null | undefined
): void {
  _customLastUnreadUrlCallbacks.push(fn);
}

/** Clears registered callbacks. Should only be used in tests. */
export function clearCustomLastUnreadUrlCallbacks() {
  _customLastUnreadUrlCallbacks.length = 0;
}

/** The application provides moment globally. */
declare const moment: typeof import("moment");
