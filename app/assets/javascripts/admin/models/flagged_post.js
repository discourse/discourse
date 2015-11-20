/**
  Our data model for interacting with flagged posts.

  @class FlaggedPost
  @extends Discourse.Post
  @namespace Discourse
  @module Discourse
**/
Discourse.FlaggedPost = Discourse.Post.extend({

  summary: function () {
    return _(this.post_actions)
      .groupBy(function (a) { return a.post_action_type_id; })
      .map(function (v,k) { return I18n.t('admin.flags.summary.action_type_' + k, { count: v.length }); })
      .join(',');
  }.property(),

  flaggers: function () {
    var self = this;
    var flaggers = [];

    _.each(this.post_actions, function (postAction) {
      flaggers.push({
        user: self.userLookup[postAction.user_id],
        topic: self.topicLookup[postAction.topic_id],
        flagType: I18n.t('admin.flags.summary.action_type_' + postAction.post_action_type_id, { count: 1 }),
        flaggedAt: postAction.created_at,
        disposedBy: postAction.disposed_by_id ? self.userLookup[postAction.disposed_by_id] : null,
        disposedAt: postAction.disposed_at,
        dispositionIcon: self.dispositionIcon(postAction.disposition),
        tookAction: postAction.staff_took_action
      });
    });

    return flaggers;
  }.property(),

  dispositionIcon: function (disposition) {
    if (!disposition) { return null; }
    var icon, title = I18n.t('admin.flags.dispositions.' + disposition);
    switch (disposition) {
      case "deferred": { icon = "fa-external-link"; break; }
      case "agreed": { icon = "fa-thumbs-o-up"; break; }
      case "disagreed": { icon = "fa-thumbs-o-down"; break; }
    }
    return "<i class='fa " + icon + "' title='" + title + "'></i>";
  },

  wasEdited: function () {
    if (Ember.isEmpty(this.get("last_revised_at"))) { return false; }
    var lastRevisedAt = Date.parse(this.get("last_revised_at"));
    return _.some(this.get("post_actions"), function (postAction) {
      return Date.parse(postAction.created_at) < lastRevisedAt;
    });
  }.property("last_revised_at", "post_actions.@each.created_at"),

  conversations: function () {
    var self = this;
    var conversations = [];

    _.each(this.post_actions, function (postAction) {
      if (postAction.conversation) {
        var conversation = {
          permalink: postAction.permalink,
          hasMore: postAction.conversation.has_more,
          response: {
            excerpt: postAction.conversation.response.excerpt,
            user: self.userLookup[postAction.conversation.response.user_id]
          }
        };

        if (postAction.conversation.reply) {
          conversation["reply"] = {
            excerpt: postAction.conversation.reply.excerpt,
            user: self.userLookup[postAction.conversation.reply.user_id]
          };
        }

        conversations.push(conversation);
      }
    });

    return conversations;
  }.property(),

  user: function() {
    return this.userLookup[this.user_id];
  }.property(),

  topic: function () {
    return this.topicLookup[this.topic_id];
  }.property(),

  flaggedForSpam: function() {
    return !_.every(this.get('post_actions'), function(action) { return action.name_key !== 'spam'; });
  }.property('post_actions.@each.name_key'),

  topicFlagged: function() {
    return _.any(this.get('post_actions'), function(action) { return action.targets_topic; });
  }.property('post_actions.@each.targets_topic'),

  postAuthorFlagged: function() {
    return _.any(this.get('post_actions'), function(action) { return !action.targets_topic; });
  }.property('post_actions.@each.targets_topic'),

  canDeleteAsSpammer: function() {
    return Discourse.User.currentProp('staff') && this.get('flaggedForSpam') && this.get('user.can_delete_all_posts') && this.get('user.can_be_deleted');
  }.property('flaggedForSpam'),

  deletePost: function() {
    if (this.get('post_number') === 1) {
      return Discourse.ajax('/t/' + this.topic_id, { type: 'DELETE', cache: false });
    } else {
      return Discourse.ajax('/posts/' + this.id, { type: 'DELETE', cache: false });
    }
  },

  disagreeFlags: function () {
    return Discourse.ajax('/admin/flags/disagree/' + this.id, { type: 'POST', cache: false });
  },

  deferFlags: function (deletePost) {
    return Discourse.ajax('/admin/flags/defer/' + this.id, { type: 'POST', cache: false, data: { delete_post: deletePost } });
  },

  agreeFlags: function (actionOnPost) {
    return Discourse.ajax('/admin/flags/agree/' + this.id, { type: 'POST', cache: false, data: { action_on_post: actionOnPost } });
  },

  postHidden: Em.computed.alias('hidden'),

  extraClasses: function() {
    var classes = [];
    if (this.get('hidden')) { classes.push('hidden-post'); }
    if (this.get('deleted')) { classes.push('deleted'); }
    return classes.join(' ');
  }.property(),

  deleted: Em.computed.or('deleted_at', 'topic_deleted_at')

});

Discourse.FlaggedPost.reopenClass({
  findAll: function (filter, offset) {
    offset = offset || 0;

    var result = Em.A();
    result.set('loading', true);

    return Discourse.ajax('/admin/flags/' + filter + '.json?offset=' + offset).then(function (data) {
      // users
      var userLookup = {};
      _.each(data.users, function (user) {
        userLookup[user.id] = Discourse.AdminUser.create(user);
      });

      // topics
      var topicLookup = {};
      _.each(data.topics, function (topic) {
        topicLookup[topic.id] = Discourse.Topic.create(topic);
      });

      // posts
      _.each(data.posts, function (post) {
        var f = Discourse.FlaggedPost.create(post);
        f.userLookup = userLookup;
        f.topicLookup = topicLookup;
        result.pushObject(f);
      });

      result.set('loading', false);

      return result;
    });
  }
});
