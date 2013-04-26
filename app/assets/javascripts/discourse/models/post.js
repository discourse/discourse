/**
  A data model representing a post in a topic

  @class Post
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.Post = Discourse.Model.extend({

  shareUrl: function(){
    var user = Discourse.get('currentUser');
    if (this.get('postnumber') === 1){
      return this.get('topic.url');
    } else {
      return this.get('url') + (user ? '?u=' + user.get('username_lower') : '');
    }
  }.property('url'),

  new_user:(function(){
    return this.get('trust_level') === 0;
  }).property('trust_level'),

  url: function() {
    return Discourse.Utilities.postUrl(this.get('topic.slug') || this.get('topic_slug'), this.get('topic_id'), this.get('post_number'));
  }.property('post_number', 'topic_id', 'topic.slug'),

  originalPostUrl: function() {
    return Discourse.getURL("/t/") + (this.get('topic_id')) + "/" + (this.get('reply_to_post_number'));
  }.property('reply_to_post_number'),

  usernameUrl: (function() {
    return Discourse.getURL("/users/" + this.get('username'));
  }).property('username'),

  showUserReplyTab: (function() {
    return this.get('reply_to_user') && (this.get('reply_to_post_number') < (this.get('post_number') - 1));
  }).property('reply_to_user', 'reply_to_post_number', 'post_number'),

  firstPost: (function() {
    if (this.get('bestOfFirst') === true) return true;
    return this.get('post_number') === 1;
  }).property('post_number'),

  byTopicCreator: function() {
    return this.get('topic.created_by.id') === this.get('user_id');
  }.property('topic.created_by.id', 'user_id'),

  hasHistory: (function() {
    return this.get('version') > 1;
  }).property('version'),

  postElementId: (function() {
    return "post_" + (this.get('post_number'));
  }).property(),

  // The class for the read icon of the post. It starts with read-icon then adds 'seen' or
  // 'last-read' if the post has been seen or is the highest post number seen so far respectively.
  bookmarkClass: (function() {
    var result, topic;
    result = 'read-icon';
    if (this.get('bookmarked')) return result + ' bookmarked';
    topic = this.get('topic');
    if (topic && topic.get('last_read_post_number') === this.get('post_number')) {
      result += ' last-read';
    } else {
      if (this.get('read')) {
        result += ' seen';
      }
    }
    return result;
  }).property('read', 'topic.last_read_post_number', 'bookmarked'),

  // Custom tooltips for the bookmark icons
  bookmarkTooltip: (function() {
    var topic;
    if (this.get('bookmarked')) return Em.String.i18n('bookmarks.created');
    if (!this.get('read')) return "";
    topic = this.get('topic');
    if (topic && topic.get('last_read_post_number') === this.get('post_number')) {
      return Em.String.i18n('bookmarks.last_read');
    }
    return Em.String.i18n('bookmarks.not_bookmarked');
  }).property('read', 'topic.last_read_post_number', 'bookmarked'),

  bookmarkedChanged: (function() {
    var _this = this;
    return Discourse.ajax({
      url: Discourse.getURL("/posts/") + (this.get('id')) + "/bookmark",
      type: 'PUT',
      data: {
        bookmarked: this.get('bookmarked') ? true : false
      },
      error: function(error) {
        var errors;
        errors = $.parseJSON(error.responseText).errors;
        bootbox.alert(errors[0]);
        return _this.toggleProperty('bookmarked');
      }
    });
  }).observes('bookmarked'),

  internalLinks: (function() {
    if (this.blank('link_counts')) return null;
    return this.get('link_counts').filterProperty('internal').filterProperty('title');
  }).property('link_counts.@each.internal'),

  // Edits are the version - 1, so version 2 = 1 edit
  editCount: (function() {
    return this.get('version') - 1;
  }).property('version'),

  historyHeat: (function() {
    var rightNow, updatedAt, updatedAtDate;
    if (!(updatedAt = this.get('updated_at'))) return;
    rightNow = new Date().getTime();

    // Show heat on age
    updatedAtDate = Date.create(updatedAt).getTime();
    if (updatedAtDate > (rightNow - 60 * 60 * 1000 * 12)) return 'heatmap-high';
    if (updatedAtDate > (rightNow - 60 * 60 * 1000 * 24)) return 'heatmap-med';
    if (updatedAtDate > (rightNow - 60 * 60 * 1000 * 48)) return 'heatmap-low';
  }).property('updated_at'),

  flagsAvailable: (function() {
    var _this = this;
    var flags = Discourse.get('site.flagTypes').filter(function(item) {
      return _this.get("actionByName." + (item.get('name_key')) + ".can_act");
    });
    return flags;
  }).property('Discourse.site.flagTypes', 'actions_summary.@each.can_act'),

  actionsHistory: (function() {
    if (!this.present('actions_summary')) return null;

    return this.get('actions_summary').filter(function(i) {
      if (i.get('count') === 0) return false;
      if (i.get('users') && i.get('users').length > 0) return true;
      return !i.get('hidden');
    });
  }).property('actions_summary.@each.users', 'actions_summary.@each.count'),

  // Save a post and call the callback when done.
  save: function(complete, error) {
    var data, metaData;
    if (!this.get('newPost')) {
      // We're updating a post
      return Discourse.ajax({
        url: Discourse.getURL("/posts/") + (this.get('id')),
        type: 'PUT',
        data: {
          post: { raw: this.get('raw') },
          image_sizes: this.get('imageSizes')
        },
        success: function(result) {
          // If we received a category update, update it
          if (result.category) Discourse.get('site').updateCategory(result.category);
          return typeof complete === "function" ? complete(Discourse.Post.create(result.post)) : void 0;
        },
        error: function(result) { return typeof error === "function" ? error(result) : void 0; }
      });
    } else {

      // We're saving a post
      data = {
        post: this.getProperties('raw', 'topic_id', 'reply_to_post_number', 'category'),
        archetype: this.get('archetype'),
        title: this.get('title'),
        image_sizes: this.get('imageSizes'),
        target_usernames: this.get('target_usernames')
      };

      // Put the metaData into the request
      if (metaData = this.get('metaData')) {
        data.meta_data = {};
        Ember.keys(metaData).forEach(function(key) { data.meta_data[key] = metaData.get(key); });
      }
      return Discourse.ajax({
        type: 'POST',
        url: Discourse.getURL("/posts"),
        data: data,
        success: function(result) {
          return typeof complete === "function" ? complete(Discourse.Post.create(result)) : void 0;
        },
        error: function(result) {
          return typeof error === "function" ? error(result) : void 0;
        }
      });
    }
  },

  recover: function() {
    return Discourse.ajax(Discourse.getURL("/posts/") + (this.get('id')) + "/recover", { type: 'PUT', cache: false });
  },

  destroy: function(complete) {
    return Discourse.ajax(Discourse.getURL("/posts/") + (this.get('id')), { type: 'DELETE' });
  },

  // Update the properties of this post from an obj, ignoring cooked as we should already
  // have that rendered.
  updateFromSave: function(obj) {

    var post = this;

    // Update all the properties
    if (!obj) return;
    Object.each(obj, function(key, val) {
      if (key === 'actions_summary') return false;
      if (val) {
        post.set(key, val);
      }
    });

    // Rebuild actions summary
    this.set('actions_summary', Em.A());
    if (obj.actions_summary) {
      var lookup = Em.Object.create();
      obj.actions_summary.each(function(a) {
        var actionSummary;
        a.post = post;
        a.actionType = Discourse.get("site").postActionTypeById(a.id);
        actionSummary = Discourse.ActionSummary.create(a);
        post.get('actions_summary').pushObject(actionSummary);
        lookup.set(a.actionType.get('name_key'), actionSummary);
      });
      this.set('actionByName', lookup);
    }
  },

  // Load replies to this post
  loadReplies: function() {
    this.set('loadingReplies', true);
    this.set('replies', []);

    var parent = this;
    return Discourse.ajax({url: Discourse.getURL("/posts/") + (this.get('id')) + "/replies"}).then(function(loaded) {
      var replies = parent.get('replies');
      loaded.each(function(reply) {
        var post = Discourse.Post.create(reply);
        post.set('topic', parent.get('topic'));
        replies.pushObject(post);
      });
      parent.set('loadingReplies', false);
    });
  },

  loadVersions: function() {
    return Discourse.ajax(Discourse.getURL("/posts/") + (this.get('id')) + "/versions.json");
  },

  // Whether to show replies directly below
  showRepliesBelow: (function() {
    var reply_count, _ref;
    reply_count = this.get('reply_count');

    // We don't show replies if there aren't any
    if (reply_count === 0) return false;

    // Always show replies if the setting `supress_reply_directly_below` is false.
    if (!Discourse.SiteSettings.supress_reply_directly_below) return true;

    // Always show replies if there's more than one
    if (reply_count > 1) return true;

    // If we have *exactly* one reply, we have to consider if it's directly below us
    if ((_ref = this.get('topic')) ? _ref.isReplyDirectlyBelow(this) : void 0) return false;

    return true;
  }).property('reply_count')
});

Discourse.Post.reopenClass({

  createActionSummary: function(result) {
    var lookup;
    if (result.actions_summary) {
      lookup = Em.Object.create();
      result.actions_summary = result.actions_summary.map(function(a) {
        var actionSummary;
        a.post = result;
        a.actionType = Discourse.get("site").postActionTypeById(a.id);
        actionSummary = Discourse.ActionSummary.create(a);
        lookup.set(a.actionType.get('name_key'), actionSummary);
        return actionSummary;
      });
      return result.set('actionByName', lookup);
    }
  },

  create: function(obj, topic) {
    var result;
    result = this._super(obj);
    this.createActionSummary(result);
    if (obj.reply_to_user) {
      result.set('reply_to_user', Discourse.User.create(obj.reply_to_user));
    }
    result.set('topic', topic);
    return result;
  },

  deleteMany: function(posts) {
    return Discourse.ajax(Discourse.getURL("/posts/destroy_many"), {
      type: 'DELETE',
      data: {
        post_ids: posts.map(function(p) { return p.get('id'); })
      }
    });
  },

  loadVersion: function(postId, version, callback) {
    return Discourse.ajax({url: Discourse.getURL("/posts/") + postId + ".json?version=" + version}).then(function(result) {
      return Discourse.Post.create(result);
    });
  },

  loadByPostNumber: function(topicId, postId) {
    return Discourse.ajax({url: Discourse.getURL("/posts/by_number/") + topicId + "/" + postId + ".json"}).then(function (result) {
      return Discourse.Post.create(result);
    });
  },

  loadQuote: function(postId) {
    return Discourse.ajax({url: Discourse.getURL("/posts/") + postId + ".json"}).then(function(result) {
      var post = Discourse.Post.create(result);
      return Discourse.BBCode.buildQuoteBBCode(post, post.get('raw'));
    });
  },

  load: function(postId) {
    return Discourse.ajax({url: Discourse.getURL("/posts/") + postId + ".json"}).then(function (result) {
      return Discourse.Post.create(result);
    });
  }

});


