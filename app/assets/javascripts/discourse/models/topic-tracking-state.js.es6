import NotificationLevels from 'discourse/lib/notification-levels';
import computed from "ember-addons/ember-computed-decorators";
import { on } from "ember-addons/ember-computed-decorators";

function isNew(topic) {
  return topic.last_read_post_number === null &&
        ((topic.notification_level !== 0 && !topic.notification_level) ||
        topic.notification_level >= NotificationLevels.TRACKING);
}

function isUnread(topic) {
  return topic.last_read_post_number !== null &&
         topic.last_read_post_number < topic.highest_post_number &&
         topic.notification_level >= NotificationLevels.TRACKING;
}

const TopicTrackingState = Discourse.Model.extend({
  messageCount: 0,

  @on("init")
  _setup() {
    this.unreadSequence = [];
    this.newSequence = [];
    this.states = {};
  },

  establishChannels() {
    const tracker = this;

    const process = data => {
      if (data.message_type === "delete") {
        tracker.removeTopic(data.topic_id);
        tracker.incrementMessageCount();
      }

      if (data.message_type === "new_topic" || data.message_type === "latest") {
        const muted_category_ids = Discourse.User.currentProp("muted_category_ids");
        if (_.include(muted_category_ids, data.payload.category_id)) {
          return;
        }
      }

      // fill parent_category_id we need it for counting new/unread
      if (data.payload && data.payload.category_id) {
        var category = Discourse.Category.findById(data.payload.category_id);

        if (category && category.parent_category_id) {
          data.payload.parent_category_id = category.parent_category_id;
        }
      }

      if (data.message_type === "latest"){
        tracker.notify(data);
      }

      if (data.message_type === "new_topic" || data.message_type === "unread" || data.message_type === "read") {
        tracker.notify(data);
        const old = tracker.states["t" + data.topic_id];

        if (!_.isEqual(old, data.payload)) {
          tracker.states["t" + data.topic_id] = data.payload;
          tracker.incrementMessageCount();
        }
      }
    };

    this.messageBus.subscribe("/new", process);
    this.messageBus.subscribe("/latest", process);
    if (this.currentUser) {
      this.messageBus.subscribe("/unread/" + this.currentUser.get('id'), process);
    }
  },

  updateSeen(topicId, highestSeen) {
    if (!topicId || !highestSeen) { return; }
    const state = this.states["t" + topicId];
    if (state && (!state.last_read_post_number || state.last_read_post_number < highestSeen)) {
      state.last_read_post_number = highestSeen;
      this.incrementMessageCount();
    }
  },

  notify(data) {
    if (!this.newIncoming) { return; }

    const filter = this.get("filter");
    const filterCategory = this.get("filterCategory");
    const categoryId = data.payload && data.payload.category_id;

    if (filterCategory && filterCategory.get("id") !== categoryId) {
      const category = categoryId && Discourse.Category.findById(categoryId);
      if (!category || category.get("parentCategory.id") !== filterCategory.get('id')) {
        return;
      }
    }

    if (filter === Discourse.Utilities.defaultHomepage()) {
      const suppressed_from_homepage_category_ids = Discourse.Site.currentProp("suppressed_from_homepage_category_ids");
      if (_.include(suppressed_from_homepage_category_ids, data.payload.category_id)) {
        return;
      }
    }

    if ((filter === "all" || filter === "latest" || filter === "new") && data.message_type === "new_topic") {
      this.addIncoming(data.topic_id);
    }

    if ((filter === "all" || filter === "unread") && data.message_type === "unread") {
      const old = this.states["t" + data.topic_id];
      if(!old || old.highest_post_number === old.last_read_post_number) {
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
    const split = filter.split('/');

    if (split.length >= 4) {
      filter = split[split.length-1];
      // c/cat/subcat/l/latest
      var category = Discourse.Category.findSingleBySlug(split.splice(1,split.length - 3).join('/'));
      this.set("filterCategory", category);
    } else {
      this.set("filterCategory", null);
    }

    this.set("filter", filter);
    this.set("incomingCount", 0);
  },

  @computed("incomingCount")
  hasIncoming(incomingCount) {
    return incomingCount && incomingCount > 0;
  },

  removeTopic(topic_id) {
    delete this.states["t" + topic_id];
  },

  // If we have a cached topic list, we can update it from our tracking
  // information.
  updateTopics(topics) {
    if (Em.isEmpty(topics)) { return; }

    const states = this.states;
    topics.forEach(t => {
      const state = states['t' + t.get('id')];

      if (state) {
        const lastRead = t.get('last_read_post_number');
        if (lastRead !== state.last_read_post_number) {
          const postsCount = t.get('posts_count');
          let newPosts = postsCount - state.highest_post_number,
              unread = postsCount - state.last_read_post_number;

          if (newPosts < 0) { newPosts = 0; }
          if (!state.last_read_post_number) { unread = 0; }
          if (unread < 0) { unread = 0; }

          t.setProperties({
            highest_post_number: state.highest_post_number,
            last_read_post_number: state.last_read_post_number,
            new_posts: newPosts,
            unread: unread,
            unseen: !state.last_read_post_number
          });
        }
      }
    });
  },

  sync(list, filter) {
    const tracker = this,
          states = tracker.states;

    if (!list || !list.topics) { return; }

    // compensate for delayed "new" topics
    // client side we know they are not new, server side we think they are
    for (let i=list.topics.length-1; i>=0; i--) {
      const state = states["t"+ list.topics[i].id];
      if (state && state.last_read_post_number > 0) {
        if (filter === "new") {
          list.topics.splice(i, 1);
        } else {
          list.topics[i].set('unseen', false);
          list.topics[i].set('dont_sync', true);
        }
      }
    }

    list.topics.forEach(function(topic){
      const row = tracker.states["t" + topic.id] || {};
      row.topic_id = topic.id;
      row.notification_level = topic.notification_level;


      if (topic.unseen) {
        row.last_read_post_number = null;
      } else if (topic.unread || topic.new_posts) {
        row.last_read_post_number = topic.highest_post_number - ((topic.unread||0) + (topic.new_posts||0));
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

      tracker.states["t" + topic.id] = row;
    });

    // Correct missing states, safeguard in case message bus is corrupt
    if ((filter === "new" || filter === "unread") && !list.more_topics_url) {

      const ids = {};
      list.topics.forEach(r => ids["t" + r.id] = true);

      _.each(tracker.states, (v, k) => {

        // we are good if we are on the list
        if (ids[k]) { return; }

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
    this.set("messageCount", this.get("messageCount") + 1);
  },

  countNew(category_id) {
    return _.chain(this.states)
            .where(isNew)
            .where(topic => topic.category_id === category_id || topic.parent_category_id === category_id || !category_id)
            .value()
            .length;
  },

  resetNew() {
    Object.keys(this.states).forEach(id => {
      if (this.states[id].last_read_post_number === null) {
        delete this.states[id];
      }
    });
  },

  countUnread(category_id) {
    return _.chain(this.states)
            .where(isUnread)
            .where(topic => topic.category_id === category_id || topic.parent_category_id === category_id || !category_id)
            .value()
            .length;
  },

  countCategory(category_id) {
    let sum = 0;
    _.each(this.states, function(topic){
      if (topic.category_id === category_id) {
        sum += (topic.last_read_post_number === null ||
                  topic.last_read_post_number < topic.highest_post_number) ? 1 : 0;
      }
    });
    return sum;
  },

  lookupCount(name, category) {
    if (name === "latest") {
      return this.lookupCount("new", category) +
             this.lookupCount("unread", category);
    }

    let categoryId = category ? Em.get(category, "id") : null;
    let categoryName = category ? Em.get(category, "name") : null;

    if (name === "new") {
      return this.countNew(categoryId);
    } else if (name === "unread") {
      return this.countUnread(categoryId);
    } else {
      categoryName = name.split("/")[1];
      if (categoryName) {
        return this.countCategory(categoryId);
      }
    }
  },

  loadStates(data) {
    const states = this.states;
    const idMap = Discourse.Category.idMap();

    // I am taking some shortcuts here to avoid 500 gets for
    // a large list
    if (data) {
      _.each(data,topic => {
        var category = idMap[topic.category_id];
        if (category && category.parent_category_id) {
          topic.parent_category_id = category.parent_category_id;
        }
        states["t" + topic.topic_id] = topic;
      });
    }
  }


});

export function startTracking(tracking) {
  const data = PreloadStore.get('topicTrackingStates');
  tracking.loadStates(data);
  tracking.initialStatesLength = data && data.length;
  tracking.establishChannels();
  PreloadStore.remove('topicTrackingStates');
}

export default TopicTrackingState;
