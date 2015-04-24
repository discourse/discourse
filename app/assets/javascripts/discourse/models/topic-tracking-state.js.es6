import NotificationLevels from 'discourse/lib/notification-levels';

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

  _setup: function() {
    this.unreadSequence = [];
    this.newSequence = [];
    this.states = {};
  }.on('init'),

  establishChannels() {
    const tracker = this;

    const process = function(data){
      if (data.message_type === "delete") {
        tracker.removeTopic(data.topic_id);
        tracker.incrementMessageCount();
      }

      if (data.message_type === "new_topic" || data.message_type === "latest") {
        const ignored_categories = Discourse.User.currentProp("muted_category_ids");
        if(_.include(ignored_categories, data.payload.category_id)){
          return;
        }
      }

      if (data.message_type === "latest"){
        tracker.notify(data);
      }

      if (data.message_type === "new_topic" || data.message_type === "unread" || data.message_type === "read") {
        tracker.notify(data);
        const old = tracker.states["t" + data.topic_id];

        if(!_.isEqual(old, data.payload)){
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
    if(!topicId || !highestSeen) { return; }
    const state = this.states["t" + topicId];
    if(state && (!state.last_read_post_number || state.last_read_post_number < highestSeen)) {
      state.last_read_post_number = highestSeen;
      this.incrementMessageCount();
    }
  },

  notify(data){
    if (!this.newIncoming) { return; }

    const filter = this.get("filter");

    if ((filter === "all" || filter === "latest" || filter === "new") && data.message_type === "new_topic" ) {
      this.addIncoming(data.topic_id);
    }

    if ((filter === "all" || filter === "unread") && data.message_type === "unread") {
      const old = this.states["t" + data.topic_id];
      if(!old || old.highest_post_number === old.last_read_post_number) {
        this.addIncoming(data.topic_id);
      }
    }

    if(filter === "latest" && data.message_type === "latest") {
      this.addIncoming(data.topic_id);
    }

    this.set("incomingCount", this.newIncoming.length);
  },

  addIncoming(topicId) {
    if(this.newIncoming.indexOf(topicId) === -1){
      this.newIncoming.push(topicId);
    }
  },

  resetTracking(){
    this.newIncoming = [];
    this.set("incomingCount", 0);
  },

  // track how many new topics came for this filter
  trackIncoming(filter) {
    this.newIncoming = [];
    this.set("filter", filter);
    this.set("incomingCount", 0);
  },

  hasIncoming: function(){
    const count = this.get('incomingCount');
    return count && count > 0;
  }.property('incomingCount'),

  removeTopic(topic_id) {
    delete this.states["t" + topic_id];
  },

  // If we have a cached topic list, we can update it from our tracking
  // information.
  updateTopics(topics) {
    if (Em.isEmpty(topics)) { return; }

    const states = this.states;
    topics.forEach(function(t) {
      const state = states['t' + t.get('id')];

      if (state) {
        const lastRead = t.get('last_read_post_number');
        if (lastRead !== state.last_read_post_number) {
          const postsCount = t.get('posts_count');
          let newPosts = postsCount - state.highest_post_number,
              unread = postsCount - state.last_read_post_number;

          if (newPosts < 0) { newPosts = 0; }
          if (!state.last_read_post_number) {
            unread = 0;
          }
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
          list.topics[i].unseen = false;
          list.topics[i].dont_sync = true;
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
    if((filter === "new" || filter === "unread") && !list.more_topics_url){

      const ids = {};
      list.topics.forEach(function(r){
        ids["t" + r.id] = true;
      });

      _.each(tracker.states, function(v, k){

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

  countNew(category_id){
    return _.chain(this.states)
      .where(isNew)
      .where(function(topic){ return topic.category_id === category_id || !category_id;})
      .value()
      .length;
  },

  resetNew() {
    const self = this;
    Object.keys(this.states).forEach(function (id) {
      if (self.states[id].last_read_post_number === null) {
        delete self.states[id];
      }
    });
  },

  countUnread(category_id){
    return _.chain(this.states)
      .where(isUnread)
      .where(function(topic){ return topic.category_id === category_id || !category_id;})
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

  lookupCount(name, category){
    let categoryName = category ? Em.get(category, "name") : null;
    if(name === "new") {
      return this.countNew(categoryName);
    } else if(name === "unread") {
      return this.countUnread(categoryName);
    } else {
      categoryName = name.split("/")[1];
      if(categoryName) {
        return this.countCategory(categoryName);
      }
    }
  },
  loadStates(data) {
    // not exposed
    const states = this.states;

    if(data) {
      _.each(data,function(topic){
        states["t" + topic.topic_id] = topic;
      });
    }
  }
});


TopicTrackingState.reopenClass({
  createFromStates(data) {

    // TODO: This should be a model that does injection automatically
    const container = Discourse.__container__,
          messageBus = container.lookup('message-bus:main'),
          currentUser = container.lookup('current-user:main'),
          instance = Discourse.TopicTrackingState.create({ messageBus, currentUser });

    instance.loadStates(data);
    instance.establishChannels();
    return instance;
  },
  current(){
    if (!this.tracker) {
      const data = PreloadStore.get('topicTrackingStates');
      this.tracker = this.createFromStates(data);
      PreloadStore.remove('topicTrackingStates');
    }
    return this.tracker;
  }
});

export default TopicTrackingState;
