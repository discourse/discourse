/**
  Our data model for interacting with flagged posts.

  @class FlaggedPost
  @extends Discourse.Post
  @namespace Discourse
  @module Discourse
**/
Discourse.FlaggedPost = Discourse.Post.extend({

  flaggers: function() {
    var r,
      _this = this;
    r = [];
    this.post_actions.each(function(a) {
      return r.push(_this.userLookup[a.user_id]);
    });
    return r;
  }.property(),

  messages: function() {
    var r,
      _this = this;
    r = [];
    this.post_actions.each(function(a) {
      if (a.message) {
        return r.push({
          user: _this.userLookup[a.user_id],
          message: a.message,
          permalink: a.permalink
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
      data.users.each(function(u) {
        userLookup[u.id] = Discourse.User.create(u);
      });
      data.posts.each(function(p) {
        var f = Discourse.FlaggedPost.create(p);
        f.userLookup = userLookup;
        result.pushObject(f);
      });
      result.set('loading', false);
    });
    return result;
  }
});


