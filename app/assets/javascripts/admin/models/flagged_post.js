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
      .groupBy(function(a){ return a.post_action_type_id; })
      .map(function(v,k){
        return I18n.t('admin.flags.summary.action_type_' + k, {count: v.length});
      })
      .join(',');
  }.property(),

  flaggers: function() {
    var r,
      _this = this;
    r = [];
    _.each(this.post_actions, function(action) {
      var user = _this.userLookup[action.user_id];
      var flagType = I18n.t('admin.flags.summary.action_type_' + action.post_action_type_id, {count: 1});
      r.push({user: user, flagType: flagType, flaggedAt: action.created_at});
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
          permalink: action.permalink,
          bySystemUser: (action.user_id === -1 ? true : false)
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
    return !this.get('topic_visible');
  }.property('topic_hidden'),

  flaggedForSpam: function() {
    return !_.every(this.get('post_actions'), function(action) { return action.name_key !== 'spam'; });
  }.property('post_actions.@each.name_key'),

  canDeleteAsSpammer: function() {
    return (Discourse.User.currentProp('staff') && this.get('flaggedForSpam') && this.get('user.can_delete_all_posts') && this.get('user.can_be_deleted'));
  }.property('flaggedForSpam'),

  deletePost: function() {
    if (this.get('post_number') === 1) {
      return Discourse.ajax('/t/' + this.topic_id, { type: 'DELETE', cache: false });
    } else {
      return Discourse.ajax('/posts/' + this.id, { type: 'DELETE', cache: false });
    }
  },

  disagreeFlags: function() {
    return Discourse.ajax('/admin/flags/disagree/' + this.id, { type: 'POST', cache: false });
  },

  deferFlags: function() {
    return Discourse.ajax('/admin/flags/defer/' + this.id, { type: 'POST', cache: false });
  },

  agreeFlags: function() {
    return Discourse.ajax('/admin/flags/agree/' + this.id, { type: 'POST', cache: false });
  },

  postHidden: Em.computed.alias('hidden'),

  extraClasses: function() {
    var classes = [];
    if (this.get('hidden')) {
      classes.push('hidden-post');
    }
    if (this.get('deleted')){
      classes.push('deleted');
    }
    return classes.join(' ');
  }.property(),

  deleted: Em.computed.or('deleted_at', 'topic_deleted_at')

});

Discourse.FlaggedPost.reopenClass({
  findAll: function(filter, offset) {

    offset = offset || 0;

    var result = Em.A();
    result.set('loading', true);
    return Discourse.ajax('/admin/flags/' + filter + '.json?offset=' + offset).then(function(data) {
      var userLookup = {};
      _.each(data.users,function(user) {
        userLookup[user.id] = Discourse.AdminUser.create(user);
      });
      _.each(data.posts,function(post) {
        var f = Discourse.FlaggedPost.create(post);
        f.userLookup = userLookup;
        result.pushObject(f);
      });
      result.set('loading', false);
      return result;
    });
  }
});


