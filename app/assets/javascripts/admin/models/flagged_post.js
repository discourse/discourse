/**
  Our data model for interacting with flagged posts.

  @class FlaggedPost
  @extends Discourse.Post
  @namespace Discourse
  @module Discourse
**/
Discourse.FlaggedPost = Discourse.Post.extend({

  summary: function(){
    return _(this.post_actions)
      .groupBy(function(a){ return a.post_action_type_id })
      .map(function(v,k){
        return Em.String.i18n("admin.flags.summary.action_type_" + k, {count: v.length});
      })
      .join(",")
  }.property(),

  flaggers: function() {
    var r,
      _this = this;
    r = [];
    _.each(this.post_actions, function(action) {
      r.push(_this.userLookup[action.user_id]);
    });
    return r;
  }.property(),

  messages: function() {
    var r,
      _this = this;
    r = [];
    _.each(this.post_actions,function(action) {
      if (action.message) {
        r.push({
          user: _this.userLookup[action.user_id],
          message: action.message,
          permalink: action.permalink
        });
      }
    });
    return r;
  }.property(),

  lastFlagged: function() {
    return this.post_actions[0].created_at;
  }.property(),

  user: function() {
    return this.userLookup[this.user_id];
  }.property(),

  topicHidden: function() {
    return this.get('topic_visible') === 'f';
  }.property('topic_hidden'),

  deletePost: function() {
    if (this.get('post_number') === "1") {
      return Discourse.ajax("/t/" + this.topic_id, { type: 'DELETE', cache: false });
    } else {
      return Discourse.ajax("/posts/" + this.id, { type: 'DELETE', cache: false });
    }
  },

  clearFlags: function() {
    return Discourse.ajax("/admin/flags/clear/" + this.id, { type: 'POST', cache: false });
  },

  hiddenClass: function() {
    if (this.get('hidden') === "t") return "hidden-post";
  }.property()
});

Discourse.FlaggedPost.reopenClass({
  findAll: function(filter) {
    var result = Em.A();
    result.set('loading', true);
    Discourse.ajax("/admin/flags/" + filter + ".json").then(function(data) {
      var userLookup = {};
      _.each(data.users,function(user) {
        userLookup[user.id] = Discourse.User.create(user);
      });
      _.each(data.posts,function(post) {
        var f = Discourse.FlaggedPost.create(post);
        f.userLookup = userLookup;
        result.pushObject(f);
      });
      result.set('loading', false);
    });
    return result;
  }
});


