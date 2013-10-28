Discourse.TopicTrackingState = Discourse.Model.extend({
  messageCount: 0,

  init: function(){
    this._super();
    this.unreadSequence = [];
    this.newSequence = [];

    this.states = {};
  },

  establishChannels: function() {
    var tracker = this;

    var process = function(data){
      if (data.message_type === "delete") {
        tracker.removeTopic(data.topic_id);
      }

      if (data.message_type === "new_topic" || data.message_type === "unread" || data.message_type === "read") {
        tracker.notify(data);
        tracker.states["t" + data.topic_id] = data.payload;
      }

      tracker.incrementMessageCount();
    };

    Discourse.MessageBus.subscribe("/new", process);
    var currentUser = Discourse.User.current();
    if(currentUser) {
      Discourse.MessageBus.subscribe("/unread/" + currentUser.id, process);
    }
  },

  updateSeen: function(topicId, highestSeen) {
    var state = this.states["t" + topicId];
    if(state && state.last_read_post_number < highestSeen) {
      state.last_read_post_number = highestSeen;
      this.incrementMessageCount();
    }
  },

  notify: function(data){
    if (!this.newIncoming) { return; }

    if ((this.filter === "all" ||this.filter === "latest" || this.filter === "new") && data.message_type === "new_topic" ) {
      this.newIncoming.push(data.topic_id);
    }
    if ((this.filter === "all" ||this.filter === "latest" || this.filter === "unread") && data.message_type === "unread") {
      var old = this.states["t" + data.topic_id];
      if(!old) {
        this.newIncoming.push(data.topic_id);
      }
    }
    this.set("incomingCount", this.newIncoming.length);
  },

  resetTracking: function(){
    this.newIncoming = [];
    this.set("incomingCount", 0);
  },

  // track how many new topics came for this filter
  trackIncoming: function(filter) {
    this.newIncoming = [];
    this.filter = filter;
    this.set("incomingCount", 0);
  },

  hasIncoming: function(){
    var count = this.get('incomingCount');
    return count && count > 0;
  }.property('incomingCount'),

  removeTopic: function(topic_id) {
    delete this.states["t" + topic_id];
  },

  sync: function(list, filter){
    var tracker = this;

    if(!list || !list.topics) { return; }

    if(filter === "new" && !list.more_topics_url){
      // scrub all new rows and reload from list
      _.each(this.states, function(state){
        if(state.last_read_post_number === null) {
          tracker.removeTopic(state.topic_id);
        }
      });
    }

    if(filter === "unread" && !list.more_topics_url){
      // scrub all new rows and reload from list
      _.each(this.states, function(state){
        if(state.last_read_post_number !== null) {
          tracker.removeTopic(state.topic_id);
        }
      });
    }

    _.each(list.topics, function(topic){
      var row = {};

      row.topic_id = topic.id;
      if(topic.unseen) {
        row.last_read_post_number = null;
      } else if (topic.unread || topic.new_posts){
        // subtle issue here
        row.last_read_post_number = topic.highest_post_number - ((topic.unread||0) + (topic.new_posts||0));
      } else {
        delete tracker.states["t" + topic.id];
        return;
      }

      row.highest_post_number = topic.highest_post_number;
      if (topic.category) {
        row.category_name = topic.category.name;
      }

      tracker.states["t" + topic.id] = row;

    });

    this.incrementMessageCount();
  },

  incrementMessageCount: function() {
    this.set("messageCount", this.get("messageCount") + 1);
  },

  countNew: function(category_name){
    return _.chain(this.states)
      .where({last_read_post_number: null})
      .where(function(topic){ return topic.category_name === category_name || !category_name;})
      .value()
      .length;
  },

  countUnread: function(category_name){
    return _.chain(this.states)
      .where(function(topic){
        return topic.last_read_post_number !== null &&
               topic.last_read_post_number < topic.highest_post_number;
      })
      .where(function(topic){ return topic.category_name === category_name || !category_name;})
      .value()
      .length;
  },

  countCategory: function(category) {
    var count = 0;
    _.each(this.states, function(topic){
      if (topic.category_name === category) {
        count += (topic.last_read_post_number === null ||
                  topic.last_read_post_number < topic.highest_post_number) ? 1 : 0;
      }
    });
    return count;
  },

  lookupCount: function(name, category){
    var categoryName = Em.get(category, "name");
    if(name==="new") {
      return this.countNew(categoryName);
    } else if(name==="unread") {
      return this.countUnread(categoryName);
    } else {
      categoryName = name.split("/")[1];
      if(categoryName) {
        return this.countCategory(categoryName);
      }
    }
  },
  loadStates: function (data) {
    // not exposed
    var states = this.states;

    if(data) {
      _.each(data,function(topic){
        states["t" + topic.topic_id] = topic;
      });
    }
  }
});


Discourse.TopicTrackingState.reopenClass({
  createFromStates: function(data){
    var instance = Discourse.TopicTrackingState.create();
    instance.loadStates(data);
    instance.establishChannels();
    return instance;
  },
  current: function(){
    if (!this.tracker) {
      var data = PreloadStore.get('topicTrackingStates');
      this.tracker = this.createFromStates(data);
      PreloadStore.remove('topicTrackingStates');
    }
    return this.tracker;
  }
});
