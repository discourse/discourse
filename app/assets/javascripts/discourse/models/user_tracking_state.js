Discourse.UserTrackingState = Discourse.Model.extend({
  unreadPosts: function(){
    return 10;
  }.property(),

  newPosts: function() {
    return 10;
  }.property()
});


Discourse.UserTrackingState.reopenClass({
  init: function(data){

  }
});
