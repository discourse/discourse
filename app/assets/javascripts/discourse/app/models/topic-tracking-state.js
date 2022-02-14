import EmberObject, { get } from "@ember/object";
import discourseComputed, { bind, on } from "discourse-common/utils/decorators";
import Category from "discourse/models/category";
import { deepEqual, deepMerge } from "discourse-common/lib/object";
import DiscourseURL from "discourse/lib/url";
import { NotificationLevels } from "discourse/lib/notification-levels";
import PreloadStore from "discourse/lib/preload-store";
import User from "discourse/models/user";
import Site from "discourse/models/site";
import { isEmpty } from "@ember/utils";

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
    topic.notification_level >= NotificationLevels.TRACKING &&
    topic.unread_not_too_old
  );
}

function isUnseen(topic) {
  return !topic.is_seen;
}

function hasMutedTags(topicTagIds, mutedTagIds, siteSettings) {
  if (!mutedTagIds || !topicTagIds) {
    return false;
  }
  return (
    (siteSettings.remove_muted_tags_from_latest === "always" &&
      topicTagIds.any((tagId) => mutedTagIds.includes(tagId))) ||
    (siteSettings.remove_muted_tags_from_latest === "only_muted" &&
      topicTagIds.every((tagId) => mutedTagIds.includes(tagId)))
  );
}

const TopicTrackingState = EmberObject.extend({
  messageCount: 0,

  @on("init")
  _setup() {
    this.states = new Map();
    this.stateChangeCallbacks = {};
    this._trackedTopicLimit = 4000;
  },

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
  establishChannels() {
    this.messageBus.subscribe("/new", this._processChannelPayload);
    this.messageBus.subscribe("/latest", this._processChannelPayload);
    if (this.currentUser) {
      this.messageBus.subscribe(
        `/unread/${this.currentUser.id}`,
        this._processChannelPayload
      );
    }

    this.messageBus.subscribe("/delete", (msg) => {
      this.modifyStateProp(msg, "deleted", true);
      this.incrementMessageCount();
    });

    this.messageBus.subscribe("/recover", (msg) => {
      this.modifyStateProp(msg, "deleted", false);
      this.incrementMessageCount();
    });

    this.messageBus.subscribe("/destroy", (msg) => {
      this.incrementMessageCount();
      const currentRoute = DiscourseURL.router.currentRoute.parent;
      if (
        currentRoute.name === "topic" &&
        parseInt(currentRoute.params.id, 10) === msg.topic_id
      ) {
        DiscourseURL.redirectTo("/");
      }
    });
  },

  mutedTopics() {
    return (this.currentUser && this.currentUser.muted_topics) || [];
  },

  unmutedTopics() {
    return (this.currentUser && this.currentUser.unmuted_topics) || [];
  },

  trackMutedOrUnmutedTopic(data) {
    let topics, key;
    if (data.message_type === "muted") {
      key = "muted_topics";
      topics = this.mutedTopics();
    } else {
      key = "unmuted_topics";
      topics = this.unmutedTopics();
    }
    topics = topics.concat({
      topicId: data.topic_id,
      createdAt: Date.now(),
    });
    this.currentUser && this.currentUser.set(key, topics);
  },

  pruneOldMutedAndUnmutedTopics() {
    const now = Date.now();
    let mutedTopics = this.mutedTopics().filter(
      (mutedTopic) => now - mutedTopic.createdAt < 60000
    );
    let unmutedTopics = this.unmutedTopics().filter(
      (unmutedTopic) => now - unmutedTopic.createdAt < 60000
    );
    this.currentUser &&
      this.currentUser.set("muted_topics", mutedTopics) &&
      this.currentUser.set("unmuted_topics", unmutedTopics);
  },

  isMutedTopic(topicId) {
    return !!this.mutedTopics().findBy("topicId", topicId);
  },

  isUnmutedTopic(topicId) {
    return !!this.unmutedTopics().findBy("topicId", topicId);
  },

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
      this.incrementMessageCount();
    }
  },

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
    if (data.payload && data.payload.archetype === "private_message") {
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

    if (filterTag && !data.payload.tags.includes(filterTag)) {
      return;
    }

    // always count a new_topic as incoming
    if (
      ["all", "latest", "new", "unseen"].includes(filter) &&
      data.message_type === "new_topic"
    ) {
      this._addIncoming(data.topic_id);
    }

    // count an unread topic as incoming
    if (
      ["all", "unread", "unseen"].includes(filter) &&
      data.message_type === "unread"
    ) {
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
      !Site.current().mobileView &&
      this.siteSettings.desktop_category_page_style ===
        "categories_and_latest_topics"
    ) {
      this._addIncoming(data.topic_id);
    }

    // hasIncoming relies on this count
    this.set("incomingCount", this.newIncoming.length);
  },

  /**
   * Resets the number of incoming topics to 0 and flushes the new topics
   * from the array. Without calling this or trackIncoming the notifyIncoming
   * method will do nothing.
   *
   * @method resetTracking
   */
  resetTracking() {
    this.newIncoming = [];
    this.set("incomingCount", 0);
  },

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
   *                          c/cat/subcat/6/l/latest or tags/c/cat/subcat/6/test/l/latest.
   */
  trackIncoming(filter) {
    this.newIncoming = [];

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

    this.set("filterCategory", category);
    this.set("filterTag", tag);
    this.set("filter", filter);
    this.set("incomingCount", 0);
  },

  /**
   * Used to determine whether toshow the message at the top of the topic list
   * e.g. "see 1 new or updated topic"
   *
   * @method incomingCount
   */
  @discourseComputed("incomingCount")
  hasIncoming(incomingCount) {
    return incomingCount && incomingCount > 0;
  },

  /**
   * Removes the topic ID provided from the tracker state.
   *
   * Calls onStateChange callbacks.
   *
   * @param {Number|String} topicId - The ID of the topic to remove from state.
   * @method removeTopic
   */
  removeTopic(topicId) {
    this.states.delete(this._stateKey(topicId));
    this._afterStateChange();
  },

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
    this.incrementMessageCount();
    this._afterStateChange();
  },

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
  },

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
    list.topics.forEach(this._syncStateFromListTopic);

    // correct missing states, safeguard in case message bus is corrupt
    if (this._shouldCompensateState(list, filter, queryParams)) {
      this._correctMissingState(list, filter);
    }

    this.incrementMessageCount();
  },

  incrementMessageCount() {
    this.incrementProperty("messageCount");
  },

  _generateCallbackId() {
    return Math.random().toString(12).substr(2, 9);
  },

  onStateChange(cb) {
    let callbackId = this._generateCallbackId();
    this.stateChangeCallbacks[callbackId] = cb;
    return callbackId;
  },

  offStateChange(callbackId) {
    delete this.stateChangeCallbacks[callbackId];
  },

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
  },

  countCategoryByState(type, categoryId, tagId, noSubcategories) {
    const subcategoryIds = noSubcategories
      ? new Set([categoryId])
      : this.getSubCategoryIds(categoryId);
    const mutedCategoryIds =
      this.currentUser && this.currentUser.muted_category_ids;
    let filterFn = type === "new" ? isNew : isUnread;

    return Array.from(this.states.values()).filter(
      (topic) =>
        filterFn(topic) &&
        topic.archetype !== "private_message" &&
        !topic.deleted &&
        (!categoryId || subcategoryIds.has(topic.category_id)) &&
        (!tagId || (topic.tags && topic.tags.indexOf(tagId) > -1)) &&
        (type !== "new" ||
          !mutedCategoryIds ||
          mutedCategoryIds.indexOf(topic.category_id) === -1)
    ).length;
  },

  countNew(categoryId, tagId, noSubcategories) {
    return this.countCategoryByState("new", categoryId, tagId, noSubcategories);
  },

  countUnread(categoryId, tagId, noSubcategories) {
    return this.countCategoryByState(
      "unread",
      categoryId,
      tagId,
      noSubcategories
    );
  },

  /**
   * Calls the provided callback for each of the currenty tracked topics
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
  },

  /**
   * Using the array of tags provided, tallys up all topics via forEachTracked
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
            if (topic.tags.indexOf(tag) > -1) {
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
  },

  countCategory(category_id, tagId) {
    let sum = 0;
    for (let topic of this.states.values()) {
      if (
        topic.category_id === category_id &&
        !topic.deleted &&
        (!tagId || (topic.tags && topic.tags.indexOf(tagId) > -1))
      ) {
        sum +=
          topic.last_read_post_number === null ||
          topic.last_read_post_number < topic.highest_post_number
            ? 1
            : 0;
      }
    }
    return sum;
  },

  lookupCount(name, category, tagId, noSubcategories) {
    if (name === "latest") {
      return (
        this.lookupCount("new", category, tagId, noSubcategories) +
        this.lookupCount("unread", category, tagId, noSubcategories)
      );
    }

    let categoryId = category ? get(category, "id") : null;

    if (name === "new") {
      return this.countNew(categoryId, tagId, noSubcategories);
    } else if (name === "unread") {
      return this.countUnread(categoryId, tagId, noSubcategories);
    } else {
      const categoryName = name.split("/")[1];
      if (categoryName) {
        return this.countCategory(categoryId, tagId);
      }
    }
  },

  loadStates(data) {
    (data || []).forEach((topic) => {
      this.modifyState(topic, topic);
    });
  },

  modifyState(topic, data) {
    this.states.set(this._stateKey(topic), data);
    this._afterStateChange();
  },

  modifyStateProp(topic, prop, data) {
    const state = this.findState(topic);
    if (state) {
      state[prop] = data;
      this._afterStateChange();
    }
  },

  findState(topicOrId) {
    return this.states.get(this._stateKey(topicOrId));
  },

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
      const state = this.findState(list.topics[index].id);
      if (state && state.last_read_post_number > 0) {
        if (filter === "new") {
          list.topics.splice(index, 1);
        } else {
          list.topics[index].set("unseen", false);
          list.topics[index].set("prevent_sync", true);
        }
      }
    }
  },

  // this updates the topic in the state to match the
  // topic from the list (e.g. updates category, highest read post
  // number, tags etc.)
  @bind
  _syncStateFromListTopic(topic) {
    const state = this.findState(topic.id) || {};

    // make a new copy so we aren't modifying the state object directly while
    // we make changes
    const newState = { ...state };

    newState.topic_id = topic.id;
    newState.notification_level = topic.notification_level;

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

    newState.highest_post_number = topic.highest_post_number;
    if (topic.category) {
      newState.category_id = topic.category.id;
    }

    if (topic.tags) {
      newState.tags = topic.tags;
    }

    this.modifyState(topic.id, newState);
  },

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
  },

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
  },

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
      const muted_category_ids = User.currentProp("muted_category_ids");
      if (
        muted_category_ids &&
        muted_category_ids.includes(data.payload.category_id)
      ) {
        return;
      }
    }

    if (["new_topic", "latest"].includes(data.message_type)) {
      const mutedTagIds = User.currentProp("muted_tag_ids");
      if (
        hasMutedTags(data.payload.topic_tag_ids, mutedTagIds, this.siteSettings)
      ) {
        return;
      }
    }

    const old = this.findState(data);

    if (data.message_type === "latest") {
      this.notifyIncoming(data);

      if ((old && old.tags) !== data.payload.tags) {
        this.modifyStateProp(data, "tags", data.payload.tags);
        this.incrementMessageCount();
      }
    }

    if (data.message_type === "dismiss_new") {
      this._dismissNewTopics(data.payload.topic_ids);
    }

    if (["new_topic", "unread", "read"].includes(data.message_type)) {
      this.notifyIncoming(data);
      if (!deepEqual(old, data.payload)) {
        if (data.message_type === "read") {
          let mergeData = {};

          // we have to do this because the "read" event does not
          // include tags; we don't want them to be overridden
          if (old) {
            mergeData = {
              tags: old.tags,
              topic_tag_ids: old.topic_tag_ids,
            };
          }

          this.modifyState(data, deepMerge(data.payload, mergeData));
        } else {
          this.modifyState(data, data.payload);
        }
        this.incrementMessageCount();
      }
    }
  },

  _dismissNewTopics(topicIds) {
    topicIds.forEach((topicId) => {
      this.modifyStateProp(topicId, "is_seen", true);
    });
    this.incrementMessageCount();
  },

  _addIncoming(topicId) {
    if (this.newIncoming.indexOf(topicId) === -1) {
      this.newIncoming.push(topicId);
    }
  },

  _trackedTopics(opts = {}) {
    return Array.from(this.states.values())
      .map((topic) => {
        if (topic.archetype !== "private_message" && !topic.deleted) {
          let newTopic = isNew(topic);
          let unreadTopic = isUnread(topic);
          if (newTopic || unreadTopic || opts.includeAll) {
            return { topic, newTopic, unreadTopic };
          }
        }
      })
      .compact();
  },

  _stateKey(topicOrId) {
    if (typeof topicOrId === "number") {
      return `t${topicOrId}`;
    } else if (typeof topicOrId === "string" && topicOrId.indexOf("t") > -1) {
      return topicOrId;
    } else {
      return `t${topicOrId.topic_id}`;
    }
  },

  _afterStateChange() {
    this.notifyPropertyChange("states");
    Object.values(this.stateChangeCallbacks).forEach((cb) => cb());
  },

  _maxStateSizeReached() {
    return this.states.size >= this._trackedTopicLimit;
  },
});

export function startTracking(tracking) {
  const data = PreloadStore.get("topicTrackingStates");
  tracking.loadStates(data);
  tracking.establishChannels();
  PreloadStore.remove("topicTrackingStates");
}

export default TopicTrackingState;
