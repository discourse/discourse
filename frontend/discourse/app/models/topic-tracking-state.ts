/* eslint-disable prefer-const -- Preserve the emitted JavaScript in this types-only port. */
import { tracked } from "@glimmer/tracking";
import EmberObject, { get } from "@ember/object";
import { trackedArray, trackedMap } from "@ember/reactive/collections";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { bind } from "discourse/lib/decorators";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { deepEqual, deepMerge } from "discourse/lib/object";
import PreloadStore from "discourse/lib/preload-store";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import Site from "discourse/models/site";
import type { default as Topic, TopicTag } from "discourse/models/topic";
import type User from "discourse/models/user";
import type MessageBusService from "discourse/services/message-bus";
import type SiteSettingsService from "discourse/services/site-settings";

/** Report/message tags carry only ids; list-derived tags may have additional fields. */
export type TopicTrackingTag = Pick<NonNullable<Topic["tags"]>[number], "id">;

/** Partial, merged state. The map key supplies identity when the payload omits it. */
export interface TopicTrackingStateEntry {
  id?: number;
  topic_id?: number;
  highest_post_number?: number | null;
  last_read_post_number?: number | null;
  notification_level?: number | null;
  category_id?: number;
  is_category_topic?: boolean;
  created_in_new_period?: boolean;
  is_seen?: boolean;
  deleted?: boolean;
  created_at?: string;
  updated_at?: string;
  archetype?: string;
  treat_as_new_topic_start_date?: string;
  /** List-derived tags can also retain their names and slugs. */
  tags?: (TopicTrackingTag & Partial<TopicTag>)[] | null;
  [key: string]: unknown;
}

/** Reports and list synchronization accept partial rows, but require numeric identity. */
export interface TopicTrackingStateRow extends TopicTrackingStateEntry {
  topic_id: number;
}

/** Channel cursors are absent for missing preload metadata. */
export type TopicTrackingChannelCursors = Record<string, number>;

export type TopicTrackingMessage =
  | {
      topic_id: number;
      message_type: "new_topic";
      payload: {
        last_read_post_number: null;
        highest_post_number: number;
        created_at: string;
        category_id: number;
        archetype: string;
        created_in_new_period: boolean;
        tags?: TopicTrackingTag[];
      };
    }
  | {
      topic_id: number;
      message_type: "latest";
      payload: {
        bumped_at: string;
        category_id: number;
        archetype: string;
        tags?: TopicTrackingTag[];
      };
    }
  | {
      topic_id: number;
      message_type: "unread";
      payload: {
        highest_post_number: number;
        updated_at: string;
        created_at: string;
        category_id: number;
        archetype: string;
        tags?: TopicTrackingTag[];
      };
    }
  | {
      topic_id: number;
      message_type: "read";
      payload: {
        last_read_post_number: number | null;
        notification_level: number | null;
        highest_post_number: number | null;
      };
    }
  | {
      topic_id: number;
      message_type: "muted" | "unmuted" | "delete" | "recover" | "destroy";
    }
  | {
      message_type: "dismiss_new" | "dismiss_new_posts";
      payload: { topic_ids: number[] };
    };

/** Predicates receive one partial state, with the tracker as their receiver. */
export interface TopicTrackingCountOptions {
  categoryId?: number | null;
  tagId?: number;
  noSubcategories?: boolean;
  customFilterFn?: (
    this: TopicTrackingState,
    state: TopicTrackingStateEntry
  ) => unknown;
}

export interface TopicTrackingLookupOptions extends Omit<
  TopicTrackingCountOptions,
  "categoryId"
> {
  type: string;
  category?: Pick<Category, "id"> | null;
}

/** Both topic lists and the combined categories page supply this surface. */
export interface TopicTrackingList {
  topics?: Topic[];
  more_topics_url?: string | null;
}

type TopicTrackingKey =
  | number
  | string
  | Pick<TopicTrackingStateEntry, "id" | "topic_id">;
type IncomingMessage = {
  topic_id: number;
  message_type: string;
  payload?: TopicTrackingStateEntry;
};

function isNew(topic: TopicTrackingStateEntry) {
  return (
    !topic.deleted &&
    topic.last_read_post_number === null &&
    ((topic.notification_level !== 0 && !topic.notification_level) ||
      topic.notification_level! >= NotificationLevels.TRACKING) &&
    topic.created_in_new_period &&
    isUnseen(topic)
  );
}

function isUnread(topic: TopicTrackingStateEntry) {
  return (
    !topic.deleted &&
    topic.last_read_post_number !== null &&
    topic.last_read_post_number! < topic.highest_post_number! &&
    topic.notification_level! >= NotificationLevels.TRACKING
  );
}

function isNewOrUnread(topic: TopicTrackingStateEntry) {
  return isUnread(topic) || isNew(topic);
}

function isUnseen(topic: TopicTrackingStateEntry) {
  return !topic.is_seen;
}

function hasMutedTags(
  topicTagIds: number[] | undefined,
  mutedTags: User["muted_tags"],
  siteSettings: TopicTrackingState["siteSettings"]
) {
  if (!mutedTags || !topicTagIds) {
    return false;
  }
  // String-valued legacy preferences have no id; preserve the original property read.
  const mutedTagIds = mutedTags.map((t) => (t as { id?: number }).id);
  return (
    (siteSettings.remove_muted_tags_from_latest === "always" &&
      topicTagIds.some((tagId) => mutedTagIds.includes(tagId))) ||
    (siteSettings.remove_muted_tags_from_latest === "only_muted" &&
      topicTagIds.every((tagId) => mutedTagIds.includes(tagId)))
  );
}

export default class TopicTrackingState extends EmberObject {
  @service currentUser!: User | null;

  /** TODO(typescript-pending): the message-bus factory returns any; remove this method view when it publishes subscription types. */
  @service
  messageBus!: {
    [K in keyof ReturnType<typeof MessageBusService.create>]: unknown;
  } & {
    subscribe<T>(
      channel: string,
      callback: (data: T) => void,
      lastId: number
    ): void;
    unsubscribe<T>(channel: string, callback: (data: T) => void): void;
  };

  /** TODO(typescript-pending): the settings factory omits setting types; remove this extension when its return declares these keys. */
  @service
  siteSettings!: {
    [K in keyof ReturnType<typeof SiteSettingsService.create>]: unknown;
  } & {
    mute_all_categories_by_default: boolean;
    remove_muted_tags_from_latest: string;
    desktop_category_page_style: string;
  };

  @tracked messageCount = 0;
  @tracked incomingCount = 0;

  /** Undefined until resetTracking or trackIncoming; some mutators assume tracking has started. */
  @tracked newIncoming?: number[];
  @tracked filterCategory?: Category;
  @tracked filterTagName?: string;
  @tracked filterTagId?: number;
  @tracked filter?: string;
  states = trackedMap<string, TopicTrackingStateEntry>();
  stateChangeCallbacks: Record<string, () => void> = {};
  _trackedTopicLimit = 4000;

  willDestroy(...args: Parameters<EmberObject["willDestroy"]>) {
    super.willDestroy(...args);

    this.messageBus.unsubscribe("/latest", this._processChannelPayload);

    if (this.currentUser) {
      this.messageBus.unsubscribe("/new", this._processChannelPayload);
      this.messageBus.unsubscribe(`/unread`, this._processChannelPayload);
      this.messageBus.unsubscribe(
        `/unread/${this.currentUser.id}`,
        this._processChannelPayload
      );
    }

    this.messageBus.unsubscribe("/delete", this.onDeleteMessage);
    this.messageBus.unsubscribe("/recover", this.onRecoverMessage);
    this.messageBus.unsubscribe("/destroy", this.onDestroyMessage);
  }

  get mutedTopics() {
    return this.currentUser?.muted_topics || [];
  }

  get unmutedTopics() {
    return this.currentUser?.unmuted_topics || [];
  }

  /**
   * Used to determine whether to show the message at the top of the topic list
   * e.g. "see 1 new or updated topic"
   */
  get hasIncoming() {
    return this.incomingCount > 0;
  }

  /**
   * Subscribe to MessageBus channels which are used for publishing changes
   * to the tracking state. Each message received will modify state for
   * a particular topic.
   *
   * See app/models/topic_tracking_state.rb for the data payloads published
   * to each of the channels.
   */
  establishChannels(meta?: TopicTrackingChannelCursors | null) {
    meta ??= {};
    const messageBusDefaultNewMessageId = -1;

    this.messageBus.subscribe(
      "/latest",
      this._processChannelPayload,
      meta["/latest"] ?? messageBusDefaultNewMessageId
    );

    if (this.currentUser) {
      this.messageBus.subscribe(
        "/new",
        this._processChannelPayload,
        meta["/new"] ?? messageBusDefaultNewMessageId
      );

      this.messageBus.subscribe(
        `/unread`,
        this._processChannelPayload,
        meta["/unread"] ?? messageBusDefaultNewMessageId
      );

      this.messageBus.subscribe(
        `/unread/${this.currentUser.id}`,
        this._processChannelPayload,
        meta[`/unread/${this.currentUser.id}`] ?? messageBusDefaultNewMessageId
      );
    }

    this.messageBus.subscribe(
      "/delete",
      this.onDeleteMessage,
      meta["/delete"] ?? messageBusDefaultNewMessageId
    );

    this.messageBus.subscribe(
      "/recover",
      this.onRecoverMessage,
      meta["/recover"] ?? messageBusDefaultNewMessageId
    );

    this.messageBus.subscribe(
      "/destroy",
      this.onDestroyMessage,
      meta["/destroy"] ?? messageBusDefaultNewMessageId
    );
  }

  @bind
  onDeleteMessage(msg: { topic_id: number; message_type: "delete" }) {
    this.modifyStateProp(msg, "deleted", true);
    if (this.newIncoming) {
      this.clearIncoming([msg.topic_id]);
    }
    this.messageCount++;
  }

  @bind
  onRecoverMessage(msg: { topic_id: number; message_type: "recover" }) {
    this.modifyStateProp(msg, "deleted", false);
    this.messageCount++;
  }

  @bind
  onDestroyMessage(msg: { topic_id: number; message_type: "destroy" }) {
    this.messageCount++;
    const currentRoute = DiscourseURL.router.currentRoute.parent;

    if (
      currentRoute.name === "topic" &&
      parseInt(currentRoute.params.id, 10) === msg.topic_id
    ) {
      DiscourseURL.redirectTo("/");
    }
  }

  trackMutedOrUnmutedTopic(data: {
    topic_id: number;
    message_type: "muted" | "unmuted";
  }) {
    let topics, key;
    if (data.message_type === "muted") {
      key = "muted_topics";
      topics = this.mutedTopics;
    } else {
      key = "unmuted_topics";
      topics = this.unmutedTopics;
    }

    topics = topics.concat({
      topicId: data.topic_id,
      createdAt: Date.now(),
    });
    this.currentUser?.set(key, topics);
  }

  pruneOldMutedAndUnmutedTopics() {
    const now = Date.now();
    let mutedTopics = this.mutedTopics.filter(
      (mutedTopic) => now - mutedTopic.createdAt < 60000
    );
    let unmutedTopics = this.unmutedTopics.filter(
      (unmutedTopic) => now - unmutedTopic.createdAt < 60000
    );

    this.currentUser?.set("muted_topics", mutedTopics);
    this.currentUser?.set("unmuted_topics", unmutedTopics);
  }

  isMutedTopic(topicId: number | undefined) {
    return !!this.mutedTopics.find((t) => t.topicId === topicId);
  }

  isUnmutedTopic(topicId: number | undefined) {
    return !!this.unmutedTopics.find((t) => t.topicId === topicId);
  }

  /**
   * Updates the topic's last_read_post_number to the highestSeen post
   * number, as long as the topic is being tracked.
   *
   * Calls onStateChange callbacks.
   *
   * @param topicId - The ID of the topic to set last_read_post_number for.
   * @param highestSeen - The post number to use for last_read_post_number.
   */
  updateSeen(
    topicId: number | string | null | undefined,
    highestSeen: number | null | undefined
  ) {
    if (!topicId || !highestSeen) {
      return;
    }
    const state = this.findState(topicId);
    if (!state) {
      return;
    }

    if (
      !state.last_read_post_number ||
      state.last_read_post_number < highestSeen
    ) {
      this.modifyStateProp(topicId, "last_read_post_number", highestSeen);
      this.messageCount++;
    }
  }

  /**
   * Used to count incoming topics which will be displayed in a message
   * at the top of the topic list, if hasIncoming is true (which is if
   * `incomingCount > 0`).
   *
   * This will do nothing unless resetTracking or trackIncoming has been
   * called; newIncoming will be undefined instead of an array. trackIncoming
   * is called by various topic routes, as is resetTracking.
   *
   * @param data - The incoming message, including its type, payload, and topic ID.
   */
  notifyIncoming(data: IncomingMessage) {
    if (!this.newIncoming) {
      return;
    }

    const filter = this.filter;
    const filterCategory = this.filterCategory;
    const categoryId = data.payload && data.payload.category_id;

    // if we have a filter category currently and it is not the
    // same as the topic category from the payload, then do nothing
    // because it doesn't need to be counted as incoming
    if (filterCategory && filterCategory.get("id") !== categoryId) {
      const category = categoryId && Category.findById(categoryId);
      if (
        !category ||
        category.get("parentCategory.id") !== filterCategory.get("id")
      ) {
        return;
      }
    }

    if (
      this.filterTagId &&
      !data.payload!.tags?.some((t) => t.id === this.filterTagId)
    ) {
      return;
    }

    // always count a new_topic as incoming
    if (
      ["all", "latest", "new", "unseen"].includes(filter!) &&
      data.message_type === "new_topic"
    ) {
      this._addIncoming(data.topic_id);
    }

    const unreadRecipients = ["all", "unread", "unseen"];
    if (this.currentUser?.unified_new_enabled) {
      unreadRecipients.push("new");
    }
    // count an unread topic as incoming
    if (unreadRecipients.includes(filter!) && data.message_type === "unread") {
      const old = this.findState(data);

      // the highest post number is equal to last read post number here
      // because the state has already been modified based on the /unread
      // messageBus message
      if (!old || old.highest_post_number === old.last_read_post_number) {
        this._addIncoming(data.topic_id);
      }
    }

    // always add incoming if looking at the latest list and a latest channel
    // message comes through
    if (filter === "latest" && data.message_type === "latest") {
      this._addIncoming(data.topic_id);
    }

    // Add incoming to the 'categories and latest topics' desktop view
    if (
      filter === "categories" &&
      data.message_type === "latest" &&
      Site.current().desktopView &&
      (this.siteSettings.desktop_category_page_style ===
        "categories_and_latest_topics" ||
        this.siteSettings.desktop_category_page_style ===
          "categories_and_latest_topics_created_date")
    ) {
      this._addIncoming(data.topic_id);
    }

    // hasIncoming relies on this count
    this.incomingCount = this.newIncoming.length;
  }

  /**
   * Resets the number of incoming topics to 0 and flushes the new topics
   * from the array. Without calling this or trackIncoming the notifyIncoming
   * method will do nothing.
   */
  resetTracking() {
    this.newIncoming = trackedArray();
    this.incomingCount = 0;
  }

  /**
   * Removes the given topic IDs from the list of incoming topics.
   */
  clearIncoming(topicIds: number[]) {
    const toRemove = new Set(topicIds);
    this.newIncoming = trackedArray(
      this.newIncoming!.filter((topicId) => !toRemove.has(topicId))
    );
    this.incomingCount = this.newIncoming.length;
  }

  /**
   * Track how many new topics came for the specified filter.
   *
   * Related/intertwined with notifyIncoming; the filter and filterCategory
   * set here is used to determine whether or not to add incoming counts
   * based on message types of incoming MessageBus messages (via establishChannels)
   *
   * @param filter - Valid values are all, categories, and any topic list
   *                          filters e.g. latest, unread, new. As well as this
   *                          specific category and tag URLs like tag/test/l/latest,
   *                          c/cat/sub-cat/6/l/latest or tags/c/cat/sub-cat/6/test/l/latest.
   * @param opts - Optionally restrict incoming topics to the given tag ID.
   */
  trackIncoming(filter: string, { tagId }: { tagId?: number } = {}) {
    this.newIncoming = trackedArray();

    let category, tagName;

    if (filter.startsWith("c/") || filter.startsWith("tags/c/")) {
      const categoryId = filter.match(/\/(\d*)\//);
      category = Category.findById(parseInt(categoryId![1], 10));
      const split = filter.split("/");

      if (filter.startsWith("tags/c/")) {
        tagName = split[split.indexOf(categoryId![1]) + 1];
      }

      if (split.length >= 4) {
        filter = split[split.length - 1];
      }
    } else if (filter.startsWith("tag/")) {
      const split = filter.split("/");
      filter = split[split.length - 1];
      tagName = split[1];
    }

    this.filterCategory = category;
    this.filterTagName = tagName;
    this.filterTagId = tagId;
    this.filter = filter;
    this.incomingCount = 0;
  }

  /**
   * Removes the topic ID provided from the tracker state.
   *
   * Calls onStateChange callbacks.
   *
   * @param topicId - The ID of the topic to remove from state.
   */
  removeTopic(topicId: TopicTrackingKey) {
    if (this.states.delete(this._stateKey(topicId))) {
      this._afterStateChange();
    }
  }

  /**
   * Removes multiple topics from the state at once, and increments
   * the message count.
   *
   * Calls onStateChange callbacks.
   *
   * @param topicIds - The IDs of the topic to removes from state.
   */
  removeTopics(topicIds: (number | string)[]) {
    topicIds.forEach((topicId) => this.removeTopic(topicId));
    this.messageCount++;
    this._afterStateChange();
  }

  /**
   * If we have a cached topic list, we can update it from our tracking information
   * if the last_read_post_number or is_seen property does not match what the
   * cached topic has.
   *
   * @param topics - An array of Topic models.
   */
  updateTopics(topics: Topic[] | null | undefined) {
    if (isEmpty(topics)) {
      return;
    }

    topics!.forEach((topic) => {
      const state = this.findState(topic.get("id"));

      if (!state) {
        return;
      }

      const lastRead = topic.get("last_read_post_number");
      const isSeen = topic.get("is_seen");

      if (
        lastRead !== state.last_read_post_number ||
        isSeen !== state.is_seen
      ) {
        const postsCount = topic.get("posts_count");
        let unread;

        if (state.last_read_post_number) {
          unread = postsCount! - state.last_read_post_number;
        } else {
          unread = 0;
        }

        if (unread < 0) {
          unread = 0;
        }

        topic.setProperties({
          highest_post_number: state.highest_post_number,
          last_read_post_number: state.last_read_post_number,
          unread_posts: unread,
          is_seen: state.is_seen,
          unseen: !state.last_read_post_number && isUnseen(state),
        });
      }
    });
  }

  /**
   * Uses the provided topic list to apply changes to the in-memory topic
   * tracking state, remove state as required, and also compensate for missing
   * in-memory state.
   *
   * Any state changes will make a callback to all state change callbacks defined
   * via onStateChange.
   *
   * @param filter - The filter used for the list e.g. new/unread
   * @param queryParams - The query parameters for the list e.g. page
   */
  sync(
    list: TopicTrackingList | null | undefined,
    filter: string,
    queryParams?: object
  ) {
    if (!list || !list.topics) {
      return;
    }

    // make sure any server-side state matches reality in the client side
    this._fixDelayedServerState(
      list as TopicTrackingList & { topics: Topic[] },
      filter
    );

    // make sure all the state is up to date with what is accurate
    // from the server
    const newStates = [];

    for (const topic of list.topics) {
      const newState = this._newStateFromListTopic(topic);

      if (newState) {
        newStates.push(newState);
      }
    }

    this.loadStates(newStates);

    // correct missing states, safeguard in case message bus is corrupt
    if (this._shouldCompensateState(list, filter, queryParams)) {
      this._correctMissingState(
        list as TopicTrackingList & { topics: Topic[] },
        filter
      );
    }

    this.messageCount++;
  }

  onStateChange(cb: () => void) {
    let callbackId = this._generateCallbackId();
    this.stateChangeCallbacks[callbackId] = cb;
    return callbackId;
  }

  offStateChange(callbackId: string) {
    delete this.stateChangeCallbacks[callbackId];
  }

  /** Assumes a category exists for every truthy id. */
  getSubCategoryIds(categoryId?: number | null): number[] | Set<number> {
    if (!categoryId) {
      return [];
    }

    const descendants = Category.findById(categoryId)!.descendants.map(
      (c) => c.id
    );

    return new Set([categoryId, ...descendants]);
  }

  countCategoryByState({
    type,
    categoryId,
    tagId,
    noSubcategories,
    customFilterFn,
  }: TopicTrackingCountOptions & {
    type: "new" | "unread" | "new_and_unread" | "unread_and_new";
  }) {
    const subcategoryIds = noSubcategories
      ? new Set([categoryId])
      : this.getSubCategoryIds(categoryId);

    const mutedCategoryIds = (
      this.currentUser?.muted_category_ids as (number | undefined)[] | undefined
    )?.concat(this.currentUser!.indirectly_muted_category_ids);

    let filterFn;
    switch (type) {
      case "new":
        filterFn = isNew;
        break;
      case "unread":
        filterFn = isUnread;
        break;
      case "new_and_unread":
      case "unread_and_new":
        filterFn = isNewOrUnread;
        break;
      default:
        throw new Error(`Unknown filter type ${type}`);
    }

    return Array.from(this.states.values()).filter((topic) => {
      if (!filterFn(topic)) {
        return false;
      }

      if (
        categoryId &&
        !(subcategoryIds as Set<number | undefined>).has(topic.category_id)
      ) {
        return false;
      }

      if (
        categoryId &&
        topic.is_category_topic &&
        categoryId !== topic.category_id
      ) {
        return false;
      }

      if (tagId && !topic.tags?.some((t) => t.id === tagId)) {
        return false;
      }

      if (type === "new" && mutedCategoryIds?.includes(topic.category_id)) {
        return false;
      }

      if (customFilterFn && !customFilterFn.call(this, topic)) {
        return false;
      }

      return true;
    }).length;
  }

  countNew({
    categoryId,
    tagId,
    noSubcategories,
    customFilterFn,
  }: TopicTrackingCountOptions = {}) {
    return this.countCategoryByState({
      type: "new",
      categoryId,
      tagId,
      noSubcategories,
      customFilterFn,
    });
  }

  countUnread({
    categoryId,
    tagId,
    noSubcategories,
    customFilterFn,
  }: TopicTrackingCountOptions = {}) {
    return this.countCategoryByState({
      type: "unread",
      categoryId,
      tagId,
      noSubcategories,
      customFilterFn,
    });
  }

  countNewAndUnread({
    categoryId,
    tagId,
    noSubcategories,
    customFilterFn,
  }: TopicTrackingCountOptions = {}) {
    return this.countCategoryByState({
      type: "new_and_unread",
      categoryId,
      tagId,
      noSubcategories,
      customFilterFn,
    });
  }

  /**
   * Calls the provided callback for each of the currently tracked topics
   * we have in state.
   *
   * @param fn - Receives state and classifier results; the new classifier can
   * return undefined for partial state.
   */
  forEachTracked(
    fn: (
      state: TopicTrackingStateEntry,
      isNew: boolean | undefined,
      isUnread: boolean
    ) => void,
    opts: { includeAll?: boolean } = {}
  ) {
    this._trackedTopics(opts).forEach((trackedTopic) => {
      fn(trackedTopic.topic, trackedTopic.newTopic, trackedTopic.unreadTopic);
    });
  }

  countCategory(category_id: number | null | undefined, tagId?: number) {
    let sum = 0;
    for (let topic of this.states.values()) {
      if (
        topic.category_id === category_id &&
        !topic.deleted &&
        (!tagId || topic.tags?.some((t) => t.id === tagId))
      ) {
        sum +=
          topic.last_read_post_number === null ||
          topic.last_read_post_number! < topic.highest_post_number!
            ? 1
            : 0;
      }
    }
    return sum;
  }

  lookupCount(
    options: TopicTrackingLookupOptions & { type: "new" | "unread" }
  ): number;

  lookupCount(options?: TopicTrackingLookupOptions): number | undefined;
  lookupCount({
    type,
    category,
    tagId,
    noSubcategories,
    customFilterFn,
  }: Partial<TopicTrackingLookupOptions> = {}): number | undefined {
    if (type === "latest") {
      let count = this.lookupCount({
        type: "new",
        category,
        tagId,
        noSubcategories,
        customFilterFn,
      });
      if (!this.currentUser?.unified_new_enabled) {
        count += this.lookupCount({
          type: "unread",
          category,
          tagId,
          noSubcategories,
          customFilterFn,
        });
      }
      return count;
    }

    let categoryId = category ? get(category, "id") : null;

    if (type === "new") {
      let count = this.countNew({
        categoryId,
        tagId,
        noSubcategories,
        customFilterFn,
      });
      if (this.currentUser?.unified_new_enabled) {
        count += this.countUnread({
          categoryId,
          tagId,
          noSubcategories,
          customFilterFn,
        });
      }
      return count;
    } else if (type === "unread") {
      return this.countUnread({
        categoryId,
        tagId,
        noSubcategories,
        customFilterFn,
      });
    } else {
      const categoryName = type!.split("/")[1];
      if (categoryName) {
        return this.countCategory(categoryId, tagId);
      }
    }
  }

  /** Stops at the first unchanged row because the existing update uses Array.every. */
  loadStates(data: TopicTrackingStateRow[] | null | undefined) {
    if (!data || data.length === 0) {
      return;
    }

    const modified = data.every((topic) => {
      return this._setState({ topic, data: topic, skipAfterStateChange: true });
    });

    if (modified) {
      this._afterStateChange();
    }
  }

  modifyState(topic: TopicTrackingKey, data: TopicTrackingStateEntry) {
    this._setState({ topic, data });
  }

  modifyStateProp(topic: TopicTrackingKey, prop: string, data: unknown) {
    const state = this.findState(topic);
    if (state) {
      state[prop] = data;
      this._afterStateChange();
    }
  }

  findState(topicOrId: TopicTrackingKey) {
    return this.states.get(this._stateKey(topicOrId));
  }

  _generateCallbackId() {
    return Math.random().toString(12).slice(2, 11);
  }

  _setState({
    topic,
    data,
    skipAfterStateChange,
  }: {
    topic: TopicTrackingKey;
    data: TopicTrackingStateEntry;
    skipAfterStateChange?: boolean;
  }) {
    const stateKey = this._stateKey(topic);
    const oldState = this.states.get(stateKey);

    if (!oldState || JSON.stringify(oldState) !== JSON.stringify(data)) {
      this.states.set(stateKey, data);

      if (!skipAfterStateChange) {
        this._afterStateChange();
      }

      return true;
    } else {
      return false;
    }
  }

  /** Removes seen topics from new lists, or marks them seen, while server state is delayed. */
  _fixDelayedServerState(
    list: TopicTrackingList & { topics: Topic[] },
    filter: string
  ) {
    for (let index = list.topics.length - 1; index >= 0; index--) {
      const topic = list.topics[index];
      const state = this.findState(topic.id);
      if (
        state &&
        state.last_read_post_number! > 0 &&
        (topic.last_read_post_number === 0 ||
          !this.currentUser?.unified_new_enabled)
      ) {
        if (filter === "new") {
          list.topics.splice(index, 1);
        } else {
          list.topics[index].set("unseen", false);
          list.topics[index].set("prevent_sync", true);
        }
      }
    }
  }

  /** Updates tracked state from the list's category, read position, and tags. */
  @bind
  _newStateFromListTopic(topic: Topic): TopicTrackingStateRow | undefined {
    const state = this.findState(topic.id) || {};

    // make a new copy so we aren't modifying the state object directly while
    // we make changes
    const newState: TopicTrackingStateEntry = { ...state };

    // see ListableTopicSerializer for unread_posts/unseen and other
    // topic property logic
    if (topic.unseen) {
      newState.last_read_post_number = null;
    } else if (topic.unread_posts) {
      newState.last_read_post_number =
        topic.highest_post_number! - (topic.unread_posts || 0);
    } else {
      // remove the topic if it is no longer unread/new (it has been seen)
      // and if there are too many topics in memory
      if (!topic.prevent_sync && this._maxStateSizeReached()) {
        this.removeTopic(topic.id);
      }
      return;
    }

    newState.topic_id = topic.id;

    if (topic.notification_level) {
      newState.notification_level = topic.notification_level;
    }

    if (topic.highest_post_number) {
      newState.highest_post_number = topic.highest_post_number;
    }

    if (topic.category) {
      newState.category_id = topic.category.id;
    }

    if (topic.tags) {
      newState.tags = topic.tags;
    }

    return newState as TopicTrackingStateRow;
  }

  /** Filtered lists cannot establish that missing topics have been read. */
  _shouldCompensateState(
    list: TopicTrackingList,
    filter: string,
    queryParams?: object
  ) {
    let shouldCompensate =
      (filter === "new" || filter === "unread") && !list.more_topics_url;

    if (shouldCompensate && queryParams) {
      Object.keys(queryParams).forEach((k) => {
        if (k !== "ascending" && k !== "order") {
          shouldCompensate = false;
        }
      });
    }

    return shouldCompensate;
  }

  /** Compensates for missing messages using a complete new or unread list. */
  _correctMissingState(
    list: TopicTrackingList & { topics: Topic[] },
    filter: string
  ) {
    const ids: Record<string, boolean> = {};
    list.topics.forEach((topic) => (ids[this._stateKey(topic.id)] = true));

    for (let topicKey of this.states.keys()) {
      // if the topic is already in the list then there is
      // no compensation needed; we already have latest state
      // from the backend
      if (ids[topicKey]) {
        continue;
      }

      const newState = { ...this.findState(topicKey) };
      if (filter === "unread" && isUnread(newState)) {
        // pretend read. if unread, the highest_post_number will be greater
        // than the last_read_post_number
        newState.last_read_post_number = newState.highest_post_number;
      }

      if (filter === "new" && isNew(newState)) {
        // pretend not new. if the topic is new, then last_read_post_number
        // will be null.
        newState.last_read_post_number = 1;
      }

      this.modifyState(topicKey, newState);
    }
  }

  /** The implementation view preserves the existing includes-based message dispatch. */
  _processChannelPayload(data: TopicTrackingMessage): void;
  @bind
  _processChannelPayload(data: {
    topic_id?: number;
    message_type: TopicTrackingMessage["message_type"];
    payload?: TopicTrackingStateEntry & { topic_ids?: number[] };
  }) {
    if (["muted", "unmuted"].includes(data.message_type)) {
      this.trackMutedOrUnmutedTopic(
        data as { topic_id: number; message_type: "muted" | "unmuted" }
      );
      return;
    }

    this.pruneOldMutedAndUnmutedTopics();

    if (this.isMutedTopic(data.topic_id)) {
      return;
    }

    if (
      this.siteSettings.mute_all_categories_by_default &&
      !this.isUnmutedTopic(data.topic_id)
    ) {
      return;
    }

    if (["new_topic", "latest"].includes(data.message_type)) {
      const mutedCategoryIds = (
        this.currentUser?.muted_category_ids as
          | (number | undefined)[]
          | undefined
      )?.concat(this.currentUser?.indirectly_muted_category_ids);

      if (
        mutedCategoryIds?.includes(data.payload!.category_id) &&
        !this.isUnmutedTopic(data.topic_id)
      ) {
        return;
      }
    }

    if (["new_topic", "latest"].includes(data.message_type)) {
      if (
        hasMutedTags(
          data.payload!.tags?.map((t) => t.id),
          this.currentUser?.muted_tags,
          this.siteSettings
        )
      ) {
        return;
      }
    }

    const old = { ...this.findState(data) };

    if (data.message_type === "latest") {
      this.notifyIncoming(data as IncomingMessage);
    }

    if (data.message_type === "dismiss_new") {
      this._dismissNewTopics(data.payload!.topic_ids!);
    }

    if (data.message_type === "dismiss_new_posts") {
      this._dismissNewPosts(data.payload!.topic_ids!);
    }

    if (["new_topic", "unread", "read"].includes(data.message_type)) {
      this.notifyIncoming(data as IncomingMessage);
      if (!deepEqual(old, data.payload)) {
        // The 'unread' and 'read' payloads are deliberately incomplete
        // for efficiency. We rebuild them by using any existing state
        // we have, and then substitute inferred values for last_read_post_number
        // and notification_level. Any errors will be corrected when a
        // topic-list is loaded which includes the topic.
        let payload = data.payload!;

        if (old) {
          // TODO(typescript-pending): deepMerge does not preserve argument types; remove when generic.
          payload = deepMerge(old, data.payload) as TopicTrackingStateEntry;
        }

        if (data.message_type === "unread") {
          if (payload.last_read_post_number === undefined) {
            // If we didn't already have state for this topic,
            // we're probably only 1 post behind.
            payload.last_read_post_number = payload.highest_post_number! - 1;
          }

          if (payload.notification_level === undefined) {
            // /unread messages will only have been published to us
            // if we are tracking or watching the topic.
            // Let's guess TRACKING for now:
            payload.notification_level = NotificationLevels.TRACKING;
          }
        }

        this.modifyState(data, payload);
        this.messageCount++;
      }
    }
  }

  _dismissNewTopics(topicIds: number[]) {
    topicIds.forEach((topicId) => {
      this.modifyStateProp(topicId, "is_seen", true);
    });

    this.messageCount++;
  }

  _dismissNewPosts(topicIds: number[]) {
    topicIds.forEach((topicId) => {
      const state = this.findState(topicId);

      if (state) {
        this.modifyStateProp(
          topicId,
          "last_read_post_number",
          state.highest_post_number
        );
      }
    });

    this.messageCount++;
  }

  _addIncoming(topicId: number) {
    if (!this.newIncoming!.includes(topicId)) {
      this.newIncoming!.push(topicId);
    }
  }

  _trackedTopics(opts: { includeAll?: boolean } = {}) {
    return Array.from(this.states.values())
      .map((topic) => {
        let newTopic = isNew(topic);
        let unreadTopic = isUnread(topic);
        if (newTopic || unreadTopic || opts.includeAll) {
          return { topic, newTopic, unreadTopic };
        }
      })
      .filter((item) => item != null);
  }

  /** Any string containing "t" passes through; numeric strings still read topic_id. */
  _stateKey(topicOrId: TopicTrackingKey) {
    if (typeof topicOrId === "number") {
      return `t${topicOrId}`;
    } else if (typeof topicOrId === "string" && topicOrId.includes("t")) {
      return topicOrId;
    } else {
      return `t${(topicOrId as Pick<TopicTrackingStateEntry, "topic_id">).topic_id}`;
    }
  }

  _afterStateChange() {
    Object.values(this.stateChangeCallbacks).forEach((cb) => cb());
  }

  _maxStateSizeReached() {
    return this.states.size >= this._trackedTopicLimit;
  }
}

export function startTracking(tracking: TopicTrackingState) {
  // TODO(typescript-pending): PreloadStore does not type keyed payloads; remove the assertions when it does.
  PreloadStore.getAndRemove("topicTrackingStates").then((data) =>
    tracking.loadStates(data as TopicTrackingStateRow[] | null)
  );

  PreloadStore.getAndRemove("topicTrackingStateMeta").then((meta) =>
    tracking.establishChannels(meta as TopicTrackingChannelCursors | null)
  );
}
