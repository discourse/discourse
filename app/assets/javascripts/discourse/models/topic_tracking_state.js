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

  notify: function(data){
    if (!this.newIncoming) { return; }

    if ((this.filter === "all" ||this.filter === "latest" || this.filter === "new") && data.message_type === "new_topic" ) {
      this.newIncoming.push(data.topic_id);
    }
    if ((this.filter === "all" || this.filter === "unread") && data.message_type === "unread") {
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
      $.each(this.states, function(){
        if(this.last_read_post_number === null) {
          tracker.removeTopic(this.topic_id);
        }
      });
    }

    if(filter === "unread" && !list.more_topics_url){
      // scrub all new rows and reload from list
      $.each(this.states, function(){
        if(this.last_read_post_number !== null) {
          tracker.removeTopic(this.topic_id);
        }
      });
    }

    $.each(list.topics, function(){
      var row = {};
      var topic = this;

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

  countNew: function(){
    var count = 0;
    $.each(this.states, function(){
      count += this.last_read_post_number === null ? 1 : 0;
    });
    return count;
  },

  countUnread: function(){
    var count = 0;
    $.each(this.states, function(){
      count += (this.last_read_post_number !== null &&
                this.last_read_post_number < this.highest_post_number) ? 1 : 0;
    });
    return count;
  },

  countCategory: function(category) {
    var count = 0;
    $.each(this.states, function(){
      if (this.category_name === category) {
        count += (this.last_read_post_number === null ||
                  this.last_read_post_number < this.highest_post_number) ? 1 : 0;
      }
    });
    return count;
  },

  lookupCount: function(name){
    if(name==="new") {
      return this.countNew();
    } else if(name==="unread") {
      return this.countUnread();
    } else {
      var category = name.split("/")[1];
      if(category) {
        return this.countCategory(category);
      }
    }
  },
  loadStates: function (data) {
    // not exposed
    var states = this.states;

    if(data) {
      data.each(function(row){
        states["t" + row.topic_id] = row;
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
