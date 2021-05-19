import EmberObject, { get } from "@ember/object";
import discourseComputed, { on } from "discourse-common/utils/decorators";
import Category from "discourse/models/category";
import DiscourseURL from "discourse/lib/url";
import { NotificationLevels } from "discourse/lib/notification-levels";
import PreloadStore from "discourse/lib/preload-store";
import User from "discourse/models/user";
import { deepEqual } from "discourse-common/lib/object";
import { isEmpty } from "@ember/utils";

function isNew(topic) {
  return (
    topic.last_read_post_number === null &&
    ((topic.notification_level !== 0 && !topic.notification_level) ||
      topic.notification_level >= NotificationLevels.TRACKING) &&
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
    this.unreadSequence = [];
    this.newSequence = [];
    this.states = {};
  },

  establishChannels() {
    const tracker = this;

    const process = (data) => {
      if (["muted", "unmuted"].includes(data.message_type)) {
        tracker.trackMutedOrUnmutedTopic(data);
        return;
      }

      tracker.pruneOldMutedAndUnmutedTopics();

      if (tracker.isMutedTopic(data.topic_id)) {
        return;
      }

      if (
        this.siteSettings.mute_all_categories_by_default &&
        !tracker.isUnmutedTopic(data.topic_id)
      ) {
        return;
      }

      if (data.message_type === "delete") {
        tracker.removeTopic(data.topic_id);
        tracker.incrementMessageCount();
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
          hasMutedTags(
            data.payload.topic_tag_ids,
            mutedTagIds,
            this.siteSettings
          )
        ) {
          return;
        }
      }

      if (data.message_type === "latest") {
        tracker.notify(data);
      }

      if (data.message_type === "dismiss_new") {
        tracker.dismissNewTopic(data);
      }

      if (["new_topic", "unread", "read"].includes(data.message_type)) {
        tracker.notify(data);
        const old = tracker.states["t" + data.topic_id];
        if (!deepEqual(old, data.payload)) {
          tracker.states["t" + data.topic_id] = data.payload;
          tracker.notifyPropertyChange("states");
          tracker.incrementMessageCount();
        }
      }
    };

    this.messageBus.subscribe("/new", process);
    this.messageBus.subscribe("/latest", process);
    if (this.currentUser) {
      this.messageBus.subscribe(
        "/unread/" + this.currentUser.get("id"),
        process
      );
    }

    this.messageBus.subscribe("/delete", (msg) => {
      const old = tracker.states["t" + msg.topic_id];
      if (old) {
        old.deleted = true;
      }
      tracker.incrementMessageCount();
    });

    this.messageBus.subscribe("/recover", (msg) => {
      const old = tracker.states["t" + msg.topic_id];
      if (old) {
        delete old.deleted;
      }
      tracker.incrementMessageCount();
    });

    this.messageBus.subscribe("/destroy", (msg) => {
      tracker.incrementMessageCount();
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

  dismissNewTopic(data) {
    data.payload.topic_ids.forEach((k) => {
      const topic = this.states[`t${k}`];
      this.states[`t${k}`] = Object.assign({}, topic, {
        is_seen: true,
      });
    });
    this.notifyPropertyChange("states");
    this.incrementMessageCount();
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

  updateSeen(topicId, highestSeen) {
    if (!topicId || !highestSeen) {
      return;
    }
    const state = this.states["t" + topicId];
    if (
      state &&
      (!state.last_read_post_number ||
        state.last_read_post_number < highestSeen)
    ) {
      state.last_read_post_number = highestSeen;
      this.incrementMessageCount();
    }
  },

  notify(data) {
    if (!this.newIncoming) {
      return;
    }
    if (data.payload && data.payload.archetype === "private_message") {
      return;
    }

    const filter = this.filter;
    const filterCategory = this.filterCategory;
    const categoryId = data.payload && data.payload.category_id;

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
      ["all", "latest", "new"].includes(filter) &&
      data.message_type === "new_topic"
    ) {
      this.addIncoming(data.topic_id);
    }

    if (["all", "unread"].includes(filter) && data.message_type === "unread") {
      const old = this.states["t" + data.topic_id];
      if (!old || old.highest_post_number === old.last_read_post_number) {
        this.addIncoming(data.topic_id);
      }
    }

    if (filter === "latest" && data.message_type === "latest") {
      this.addIncoming(data.topic_id);
    }

    this.set("incomingCount", this.newIncoming.length);
  },

  addIncoming(topicId) {
    if (this.newIncoming.indexOf(topicId) === -1) {
      this.newIncoming.push(topicId);
    }
  },

  resetTracking() {
    this.newIncoming = [];
    this.set("incomingCount", 0);
  },

  // track how many new topics came for this filter
  trackIncoming(filter) {
    this.newIncoming = [];
    const split = filter.split("/");

    if (split.length >= 4) {
      filter = split[split.length - 1];
      // c/cat/subcat/6/l/latest
      let category = Category.findSingleBySlug(
        split.splice(1, split.length - 4).join("/")
      );
      this.set("filterCategory", category);
    } else {
      this.set("filterCategory", null);
    }

    this.set("filter", filter);
    this.set("incomingCount", 0);
  },

  @discourseComputed("incomingCount")
  hasIncoming(incomingCount) {
    return incomingCount && incomingCount > 0;
  },

  removeTopic(topic_id) {
    delete this.states["t" + topic_id];
  },

  // If we have a cached topic list, we can update it from our tracking information.
  updateTopics(topics) {
    if (isEmpty(topics)) {
      return;
    }

    const states = this.states;
    topics.forEach((t) => {
      const state = states["t" + t.get("id")];

      if (state) {
        const lastRead = t.get("last_read_post_number");
        const isSeen = t.get("is_seen");
        if (
          lastRead !== state.last_read_post_number ||
          isSeen !== state.is_seen
        ) {
          const postsCount = t.get("posts_count");
          let newPosts = postsCount - state.highest_post_number,
            unread = postsCount - state.last_read_post_number;

          if (newPosts < 0) {
            newPosts = 0;
          }
          if (!state.last_read_post_number) {
            unread = 0;
          }
          if (unread < 0) {
            unread = 0;
          }

          t.setProperties({
            highest_post_number: state.highest_post_number,
            last_read_post_number: state.last_read_post_number,
            new_posts: newPosts,
            unread: unread,
            is_seen: state.is_seen,
            unseen: !state.last_read_post_number && isUnseen(state),
          });
        }
      }
    });
  },

  sync(list, filter, queryParams) {
    const tracker = this,
      states = tracker.states;

    if (!list || !list.topics) {
      return;
    }

    // compensate for delayed "new" topics
    // client side we know they are not new, server side we think they are
    for (let i = list.topics.length - 1; i >= 0; i--) {
      const state = states["t" + list.topics[i].id];
      if (state && state.last_read_post_number > 0) {
        if (filter === "new") {
          list.topics.splice(i, 1);
        } else {
          list.topics[i].set("unseen", false);
          list.topics[i].set("dont_sync", true);
        }
      }
    }

    list.topics.forEach(function (topic) {
      const row = tracker.states["t" + topic.id] || {};
      row.topic_id = topic.id;
      row.notification_level = topic.notification_level;

      if (topic.unseen) {
        row.last_read_post_number = null;
      } else if (topic.unread || topic.new_posts) {
        row.last_read_post_number =
          topic.highest_post_number -
          ((topic.unread || 0) + (topic.new_posts || 0));
      } else {
        if (!topic.dont_sync) {
          delete tracker.states["t" + topic.id];
        }
        return;
      }

      row.highest_post_number = topic.highest_post_number;
      if (topic.category) {
        row.category_id = topic.category.id;
      }

      if (topic.tags) {
        row.tags = topic.tags;
      }

      tracker.states["t" + topic.id] = row;
    });

    // Correct missing states, safeguard in case message bus is corrupt
    let shouldCompensate =
      (filter === "new" || filter === "unread") && !list.more_topics_url;

    if (shouldCompensate && queryParams) {
      Object.keys(queryParams).forEach((k) => {
        if (k !== "ascending" && k !== "order") {
          shouldCompensate = false;
        }
      });
    }

    if (shouldCompensate) {
      const ids = {};
      list.topics.forEach((r) => (ids["t" + r.id] = true));

      Object.keys(tracker.states).forEach((k) => {
        // we are good if we are on the list
        if (ids[k]) {
          return;
        }

        const v = tracker.states[k];

        if (filter === "unread" && isUnread(v)) {
          // pretend read
          v.last_read_post_number = v.highest_post_number;
        }

        if (filter === "new" && isNew(v)) {
          // pretend not new
          v.last_read_post_number = 1;
        }
      });
    }

    this.incrementMessageCount();
  },

  incrementMessageCount() {
    this.incrementProperty("messageCount");
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
    let filter = type === "new" ? isNew : isUnread;

    return Object.values(this.states).filter(
      (topic) =>
        filter(topic) &&
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

  forEachTracked(fn) {
    Object.values(this.states).forEach((topic) => {
      if (topic.archetype !== "private_message" && !topic.deleted) {
        let newTopic = isNew(topic);
        let unreadTopic = isUnread(topic);
        if (newTopic || unreadTopic) {
          fn(topic, newTopic, unreadTopic);
        }
      }
    });
  },

  countTags(tags) {
    let counts = {};

    tags.forEach((tag) => {
      counts[tag] = { unreadCount: 0, newCount: 0 };
    });

    this.forEachTracked((topic, newTopic, unreadTopic) => {
      if (topic.tags) {
        tags.forEach((tag) => {
          if (topic.tags.indexOf(tag) > -1) {
            if (unreadTopic) {
              counts[tag].unreadCount++;
            }
            if (newTopic) {
              counts[tag].newCount++;
            }
          }
        });
      }
    });

    return counts;
  },

  countCategory(category_id, tagId) {
    let sum = 0;
    Object.values(this.states).forEach((topic) => {
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
    });
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
    const states = this.states;

    // I am taking some shortcuts here to avoid 500 gets for a large list
    if (data) {
      data.forEach((topic) => {
        states["t" + topic.topic_id] = topic;
      });
    }
  },
});

export function startTracking(tracking) {
  const data = PreloadStore.get("topicTrackingStates");
  tracking.loadStates(data);
  tracking.initialStatesLength = data && data.length;
  tracking.establishChannels();
  PreloadStore.remove("topicTrackingStates");
}

export default TopicTrackingState;
