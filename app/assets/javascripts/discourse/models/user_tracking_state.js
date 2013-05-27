Discourse.UserTrackingState = Discourse.Model.extend({
  init: function(){
    this._super();
    this.states = {};

    var _this = this;
    setTimeout(function(){
      console.log("YYYYYYYYYYY");
      _this.loadStates([{
        topic_id: 100,
        last_read_post_number: null
      }]);
      _this.set('messageCount', 100);
    }, 2000);
  },

  establishChannels: function() {


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

    data.each(function(row){
      states["t" + row.topic_id] = row;
    });
  }
});


Discourse.UserTrackingState.reopenClass({
  createFromStates: function(data){
    var instance = Discourse.UserTrackingState.create();
    instance.loadStates(data);
    instance.establishChannels();
    return instance;
  }
});
