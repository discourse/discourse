import { tracked } from "@glimmer/tracking";
import EmberObject, { get } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { TrackedArray, TrackedMap } from "@ember-compat/tracked-built-ins";
import { bind } from "discourse/lib/decorators";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { deepEqual, deepMerge } from "discourse/lib/object";
import PreloadStore from "discourse/lib/preload-store";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import Site from "discourse/models/site";

function isNew(topic) {
  return (
    topic.last_read_post_number === null &&
    ((topic.notification_level !== 0 && !topic.notification_level) ||
      topic.notification_level >= NotificationLevels.TRACKING) &&
    topic.created_in_new_period &&
    isUnseen(topic)
  );
}

function isUnread(topic) {
  return (
    topic.last_read_post_number !== null &&
    topic.last_read_post_number < topic.highest_post_number &&
    topic.notification_level >= NotificationLevels.TRACKING
  );
}

function isNewOrUnread(topic) {
  return isUnread(topic) || isNew(topic);
}

function isUnseen(topic) {
  return !topic.is_seen;
}

function hasMutedTags(topicTags, mutedTags, siteSettings) {
  if (!mutedTags || !topicTags) {
    return false;
  }
  return (
    (siteSettings.remove_muted_tags_from_latest === "always" &&
      topicTags.any((topicTag) => mutedTags.includes(topicTag))) ||
    (siteSettings.remove_muted_tags_from_latest === "only_muted" &&
      topicTags.every((topicTag) => mutedTags.includes(topicTag)))
  );
}

export default class TopicTrackingState extends EmberObject {
  @service currentUser;
  @service messageBus;
  @service siteSettings;

  @tracked messageCount = 0;
  @tracked incomingCount = 0;
  @tracked newIncoming;
  @tracked filterCategory;
  @tracked filterTag;
  @tracked filter;
  states = new TrackedMap();
  stateChangeCallbacks = {};
  _trackedTopicLimit = 4000;

  willDestroy() {
    super.willDestroy(...arguments);

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

  /**
   * Subscribe to MessageBus channels which are used for publishing changes
   * to the tracking state. Each message received will modify state for
   * a particular topic.
   *
   * See app/models/topic_tracking_state.rb for the data payloads published
   * to each of the channels.
   *
   * @method establishChannels
   */
  establishChannels(meta) {
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
  onDeleteMessage(msg) {
    this.modifyStateProp(msg, "deleted", true);
    this.messageCount++;
  }

  @bind
  onRecoverMessage(msg) {
    this.modifyStateProp(msg, "deleted", false);
    this.messageCount++;
  }

  @bind
  onDestroyMessage(msg) {
    this.messageCount++;
    const currentRoute = DiscourseURL.router.currentRoute.parent;

    if (
      currentRoute.name === "topic" &&
      parseInt(currentRoute.params.id, 10) === msg.topic_id
    ) {
      DiscourseURL.redirectTo("/");
    }
  }

  get mutedTopics() {
    return this.currentUser?.muted_topics || [];
  }

  get unmutedTopics() {
    return this.currentUser?.unmuted_topics || [];
  }

  trackMutedOrUnmutedTopic(data) {
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

  isMutedTopic(topicId) {
    return !!this.mutedTopics.findBy("topicId", topicId);
  }

  isUnmutedTopic(topicId) {
    return !!this.unmutedTopics.findBy("topicId", topicId);
  }

  /**
   * Updates the topic's last_read_post_number to the highestSeen post
   * number, as long as the topic is being tracked.
   *
   * Calls onStateChange callbacks.
   *
   * @params {Number|String} topicId - The ID of the topic to set last_read_post_number for.
   * @params {Number} highestSeen - The post number of the topic that should be
   *                                used for last_read_post_number.
   * @method updateSeen
   */
  updateSeen(topicId, highestSeen) {
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
   * incomingCount > 0).
   *
   * This will do nothing unless resetTracking or trackIncoming has been
   * called; newIncoming will be null instead of an array. trackIncoming
   * is called by various topic routes, as is resetTracking.
   *
   * @method notifyIncoming
   * @param {Object} data - The data sent by TopicTrackingState to MessageBus
   *                        which includes the message_type, payload of the topic,
   *                        and the topic_id.
   */
  notifyIncoming(data) {
    if (!this.newIncoming) {
      return;
    }

    const filter = this.filter;
    const filterCategory = this.filterCategory;
    const filterTag = this.filterTag;
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

    if (filterTag && !data.payload.tags?.includes(filterTag)) {
      return;
    }

    // always count a new_topic as incoming
    if (
      ["all", "latest", "new", "unseen"].includes(filter) &&
      data.message_type === "new_topic"
    ) {
      this._addIncoming(data.topic_id);
    }

    const unreadRecipients = ["all", "unread", "unseen"];
    if (this.currentUser?.new_new_view_enabled) {
      unreadRecipients.push("new");
    }
    // count an unread topic as incoming
    if (unreadRecipients.includes(filter) && data.message_type === "unread") {
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
   *
   * @method resetTracking
   */
  resetTracking() {
    this.newIncoming = new TrackedArray();
    this.incomingCount = 0;
  }

  /**
   * Removes the given topic IDs from the list of incoming topics.
   *
   * @method clearIncoming
   */
  clearIncoming(topicIds) {
    const toRemove = new Set(topicIds);
    this.newIncoming = new TrackedArray(
      this.newIncoming.filter((topicId) => !toRemove.has(topicId))
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
   * @method trackIncoming
   * @param {String} filter - Valid values are all, categories, and any topic list
   *                          filters e.g. latest, unread, new. As well as this
   *                          specific category and tag URLs like tag/test/l/latest,
   *                          c/cat/sub-cat/6/l/latest or tags/c/cat/sub-cat/6/test/l/latest.
   */
  trackIncoming(filter) {
    this.newIncoming = new TrackedArray();

    let category, tag;

    if (filter.startsWith("c/") || filter.startsWith("tags/c/")) {
      const categoryId = filter.match(/\/(\d*)\//);
      category = Category.findById(parseInt(categoryId[1], 10));
      const split = filter.split("/");

      if (filter.startsWith("tags/c/")) {
        tag = split[split.indexOf(categoryId[1]) + 1];
      }

      if (split.length >= 4) {
        filter = split[split.length - 1];
      }
    } else if (filter.startsWith("tag/")) {
      const split = filter.split("/");
      filter = split[split.length - 1];
      tag = split[1];
    }

    this.filterCategory = category;
    this.filterTag = tag;
    this.filter = filter;
    this.incomingCount = 0;
  }

  /**
   * Used to determine whether to show the message at the top of the topic list
   * e.g. "see 1 new or updated topic"
   *
   * @method hasIncoming
   */
  get hasIncoming() {
    return this.incomingCount > 0;
  }

  /**
   * Removes the topic ID provided from the tracker state.
   *
   * Calls onStateChange callbacks.
   *
   * @param {Number|String} topicId - The ID of the topic to remove from state.
   * @method removeTopic
   */
  removeTopic(topicId) {
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
   * @param {Array} topicIds - The IDs of the topic to removes from state.
   * @method removeTopics
   */
  removeTopics(topicIds) {
    topicIds.forEach((topicId) => this.removeTopic(topicId));
    this.messageCount++;
    this._afterStateChange();
  }

  /**
   * If we have a cached topic list, we can update it from our tracking information
   * if the last_read_post_number or is_seen property does not match what the
   * cached topic has.
   *
   * @method updateTopics
   * @param {Array} topics - An array of Topic models.
   */
  updateTopics(topics) {
    if (isEmpty(topics)) {
      return;
    }

    topics.forEach((topic) => {
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
          unread = postsCount - state.last_read_post_number;
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
   * @method sync
   * @param {TopicList} list
   * @param {String} filter - The filter used for the list e.g. new/unread
   * @param {Object} queryParams - The query parameters for the list e.g. page
   */
  sync(list, filter, queryParams) {
    if (!list || !list.topics) {
      return;
    }

    // make sure any server-side state matches reality in the client side
    this._fixDelayedServerState(list, filter);

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
      this._correctMissingState(list, filter);
    }

    this.messageCount++;
  }

  _generateCallbackId() {
    return Math.random().toString(12).slice(2, 11);
  }

  onStateChange(cb) {
    let callbackId = this._generateCallbackId();
    this.stateChangeCallbacks[callbackId] = cb;
    return callbackId;
  }

  offStateChange(callbackId) {
    delete this.stateChangeCallbacks[callbackId];
  }

  getSubCategoryIds(categoryId) {
    const result = [categoryId];
    const categories = Category.list();

    for (let i = 0; i < result.length; ++i) {
      for (let j = 0; j < categories.length; ++j) {
        if (result[i] === categories[j].parent_category_id) {
          result[result.length] = categories[j].id;
        }
      }
    }

    return new Set(result);
  }

  countCategoryByState({
    type,
    categoryId,
    tagId,
    noSubcategories,
    customFilterFn,
  }) {
    const subcategoryIds = noSubcategories
      ? new Set([categoryId])
      : this.getSubCategoryIds(categoryId);

    const mutedCategoryIds = this.currentUser?.muted_category_ids?.concat(
      this.currentUser.indirectly_muted_category_ids
    );

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

      if (categoryId && !subcategoryIds.has(topic.category_id)) {
        return false;
      }

      if (
        categoryId &&
        topic.is_category_topic &&
        categoryId !== topic.category_id
      ) {
        return false;
      }

      if (tagId && !topic.tags?.includes(tagId)) {
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

  countNew({ categoryId, tagId, noSubcategories, customFilterFn } = {}) {
    return this.countCategoryByState({
      type: "new",
      categoryId,
      tagId,
      noSubcategories,
      customFilterFn,
    });
  }

  countUnread({ categoryId, tagId, noSubcategories, customFilterFn } = {}) {
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
  } = {}) {
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
   * @method forEachTracked
   * @param {Function} fn - The callback function to call with the topic,
   *                        newTopic which is a boolean result of isNew,
   *                        and unreadTopic which is a boolean result of
   *                        isUnread.
   */
  forEachTracked(fn, opts = {}) {
    this._trackedTopics(opts).forEach((trackedTopic) => {
      fn(trackedTopic.topic, trackedTopic.newTopic, trackedTopic.unreadTopic);
    });
  }

  /**
   * Using the array of tags provided, tallies up all topics via forEachTracked
   * that we are tracking, separated into new/unread/total.
   *
   * Total is only counted if opts.includeTotal is specified.
   *
   * Output (from input ["pending", "bug"]):
   *
   * {
   *   pending: { unreadCount: 6, newCount: 1, totalCount: 10 },
   *   bug: { unreadCount: 0, newCount: 4, totalCount: 20 }
   * }
   *
   * @method countTags
   * @param opts - Valid options:
   *                 * includeTotal - When true, a totalCount is incremented for
   *                                all topics matching a tag.
   */
  countTags(tags, opts = {}) {
    let counts = {};

    tags.forEach((tag) => {
      counts[tag] = { unreadCount: 0, newCount: 0 };
      if (opts.includeTotal) {
        counts[tag].totalCount = 0;
      }
    });

    this.forEachTracked(
      (topic, newTopic, unreadTopic) => {
        if (topic.tags && topic.tags.length > 0) {
          tags.forEach((tag) => {
            if (topic.tags.includes(tag)) {
              if (unreadTopic) {
                counts[tag].unreadCount++;
              }
              if (newTopic) {
                counts[tag].newCount++;
              }

              if (opts.includeTotal) {
                counts[tag].totalCount++;
              }
            }
          });
        }
      },
      { includeAll: opts.includeTotal }
    );

    return counts;
  }

  countCategory(category_id, tagId) {
    let sum = 0;
    for (let topic of this.states.values()) {
      if (
        topic.category_id === category_id &&
        !topic.deleted &&
        (!tagId || topic.tags?.includes(tagId))
      ) {
        sum +=
          topic.last_read_post_number === null ||
          topic.last_read_post_number < topic.highest_post_number
            ? 1
            : 0;
      }
    }
    return sum;
  }

  lookupCount({ type, category, tagId, noSubcategories, customFilterFn } = {}) {
    if (type === "latest") {
      let count = this.lookupCount({
        type: "new",
        category,
        tagId,
        noSubcategories,
        customFilterFn,
      });
      if (!this.currentUser?.new_new_view_enabled) {
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
      if (this.currentUser?.new_new_view_enabled) {
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
      const categoryName = type.split("/")[1];
      if (categoryName) {
        return this.countCategory(categoryId, tagId);
      }
    }
  }

  loadStates(data) {
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

  _setState({ topic, data, skipAfterStateChange }) {
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

  modifyState(topic, data) {
    this._setState({ topic, data });
  }

  modifyStateProp(topic, prop, data) {
    const state = this.findState(topic);
    if (state) {
      state[prop] = data;
      this._afterStateChange();
    }
  }

  findState(topicOrId) {
    return this.states.get(this._stateKey(topicOrId));
  }

  /*
   * private
   */

  // fix delayed "new" topics by removing the now seen
  // topic from the list (for the "new" list) or setting the topic
  // to "seen" for other lists.
  //
  // client side we know they are not new, server side we think they are.
  // this can happen if the list is cached or the update to the state
  // for a particular seen topic has not yet reached the server.
  _fixDelayedServerState(list, filter) {
    for (let index = list.topics.length - 1; index >= 0; index--) {
      const topic = list.topics[index];
      const state = this.findState(topic.id);
      if (
        state &&
        state.last_read_post_number > 0 &&
        (topic.last_read_post_number === 0 ||
          !this.currentUser?.new_new_view_enabled)
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

  // this updates the topic in the state to match the
  // topic from the list (e.g. updates category, highest read post
  // number, tags etc.)
  @bind
  _newStateFromListTopic(topic) {
    const state = this.findState(topic.id) || {};

    // make a new copy so we aren't modifying the state object directly while
    // we make changes
    const newState = { ...state };

    // see ListableTopicSerializer for unread_posts/unseen and other
    // topic property logic
    if (topic.unseen) {
      newState.last_read_post_number = null;
    } else if (topic.unread_posts) {
      newState.last_read_post_number =
        topic.highest_post_number - (topic.unread_posts || 0);
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

    return newState;
  }

  // this stops sync of tracking state when list is filtered, in the past this
  // would cause the tracking state to become inconsistent.
  _shouldCompensateState(list, filter, queryParams) {
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

  // any state that is not in the provided list must be updated
  // based on the filter selected so we do not have any incorrect
  // state in the list
  _correctMissingState(list, filter) {
    const ids = {};
    list.topics.forEach((topic) => (ids[this._stateKey(topic.id)] = true));

    for (let topicKey of this.states.keys()) {
      // if the topic is already in the list then there is
      // no compensation needed; we already have latest state
      // from the backend
      if (ids[topicKey]) {
        return;
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

  // processes the data sent via messageBus, called by establishChannels
  @bind
  _processChannelPayload(data) {
    if (["muted", "unmuted"].includes(data.message_type)) {
      this.trackMutedOrUnmutedTopic(data);
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
      const mutedCategoryIds = this.currentUser?.muted_category_ids?.concat(
        this.currentUser?.indirectly_muted_category_ids
      );

      if (
        mutedCategoryIds?.includes(data.payload.category_id) &&
        !this.isUnmutedTopic(data.topic_id)
      ) {
        return;
      }
    }

    if (["new_topic", "latest"].includes(data.message_type)) {
      if (
        hasMutedTags(
          data.payload.tags,
          this.currentUser?.muted_tags,
          this.siteSettings
        )
      ) {
        return;
      }
    }

    const old = { ...this.findState(data) };

    if (data.message_type === "latest") {
      this.notifyIncoming(data);

      if (old.tags !== data.payload.tags) {
        this.modifyStateProp(data, "tags", data.payload.tags);
        this.messageCount++;
      }
    }

    if (data.message_type === "dismiss_new") {
      this._dismissNewTopics(data.payload.topic_ids);
    }

    if (data.message_type === "dismiss_new_posts") {
      this._dismissNewPosts(data.payload.topic_ids);
    }

    if (["new_topic", "unread", "read"].includes(data.message_type)) {
      this.notifyIncoming(data);
      if (!deepEqual(old, data.payload)) {
        // The 'unread' and 'read' payloads are deliberately incomplete
        // for efficiency. We rebuild them by using any existing state
        // we have, and then substitute inferred values for last_read_post_number
        // and notification_level. Any errors will be corrected when a
        // topic-list is loaded which includes the topic.
        let payload = data.payload;

        if (old) {
          payload = deepMerge(old, data.payload);
        }

        if (data.message_type === "unread") {
          if (payload.last_read_post_number === undefined) {
            // If we didn't already have state for this topic,
            // we're probably only 1 post behind.
            payload.last_read_post_number = payload.highest_post_number - 1;
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

  _dismissNewTopics(topicIds) {
    topicIds.forEach((topicId) => {
      this.modifyStateProp(topicId, "is_seen", true);
    });

    this.messageCount++;
  }

  _dismissNewPosts(topicIds) {
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

  _addIncoming(topicId) {
    if (!this.newIncoming.includes(topicId)) {
      this.newIncoming.push(topicId);
    }
  }

  _trackedTopics(opts = {}) {
    return Array.from(this.states.values())
      .map((topic) => {
        let newTopic = isNew(topic);
        let unreadTopic = isUnread(topic);
        if (newTopic || unreadTopic || opts.includeAll) {
          return { topic, newTopic, unreadTopic };
        }
      })
      .compact();
  }

  _stateKey(topicOrId) {
    if (typeof topicOrId === "number") {
      return `t${topicOrId}`;
    } else if (typeof topicOrId === "string" && topicOrId.includes("t")) {
      return topicOrId;
    } else {
      return `t${topicOrId.topic_id}`;
    }
  }

  _afterStateChange() {
    Object.values(this.stateChangeCallbacks).forEach((cb) => cb());
  }

  _maxStateSizeReached() {
    return this.states.size >= this._trackedTopicLimit;
  }
}

export function startTracking(tracking) {
  PreloadStore.getAndRemove("topicTrackingStates").then((data) =>
    tracking.loadStates(data)
  );

  PreloadStore.getAndRemove("topicTrackingStateMeta").then((meta) =>
    tracking.establishChannels(meta)
  );
}
