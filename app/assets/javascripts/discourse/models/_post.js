/**
  A data model representing a post in a topic

  @class Post
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.Post = Discourse.Model.extend({

  init: function() {
    this.set('replyHistory', []);
  },

  shareUrl: function() {
    var user = Discourse.User.current();
    var userSuffix = user ? '?u=' + user.get('username_lower') : '';

    if (this.get('firstPost')) {
      return this.get('topic.url') + userSuffix;
    } else {
      return this.get('url') + userSuffix ;
    }
  }.property('url'),

  new_user: Em.computed.equal('trust_level', 0),
  firstPost: Em.computed.equal('post_number', 1),

  // Posts can show up as deleted if the topic is deleted
  deletedViaTopic: Em.computed.and('firstPost', 'topic.deleted_at'),
  deleted: Em.computed.or('deleted_at', 'deletedViaTopic'),
  notDeleted: Em.computed.not('deleted'),
  userDeleted: Em.computed.empty('user_id'),

  showName: function() {
    var name = this.get('name');
    return name && (name !== this.get('username'))  && Discourse.SiteSettings.display_name_on_posts;
  }.property('name', 'username'),

  postDeletedBy: function() {
    if (this.get('firstPost')) { return this.get('topic.deleted_by'); }
    return this.get('deleted_by');
  }.property('firstPost', 'deleted_by', 'topic.deleted_by'),

  postDeletedAt: function() {
    if (this.get('firstPost')) { return this.get('topic.deleted_at'); }
    return this.get('deleted_at');
  }.property('firstPost', 'deleted_at', 'topic.deleted_at'),

  url: function() {
    return Discourse.Utilities.postUrl(this.get('topic.slug') || this.get('topic_slug'), this.get('topic_id'), this.get('post_number'));
  }.property('post_number', 'topic_id', 'topic.slug'),

  usernameUrl: Discourse.computed.url('username', '/users/%@'),

  showUserReplyTab: function() {
    return this.get('reply_to_user') && (
      !Discourse.SiteSettings.suppress_reply_directly_above ||
      this.get('reply_to_post_number') < (this.get('post_number') - 1)
    );
  }.property('reply_to_user', 'reply_to_post_number', 'post_number'),

  byTopicCreator: Discourse.computed.propertyEqual('topic.details.created_by.id', 'user_id'),
  hasHistory: Em.computed.gt('version', 1),
  postElementId: Discourse.computed.fmt('post_number', 'post_%@'),

  canViewRawEmail: function() {
    return Discourse.User.currentProp('staff');
  }.property(),

  bookmarkedChanged: function() {
    Discourse.Post.bookmark(this.get('id'), this.get('bookmarked'))
             .then(null, function (error) {
               if (error && error.responseText) {
                 bootbox.alert($.parseJSON(error.responseText).errors[0]);
               } else {
                 bootbox.alert(I18n.t('generic_error'));
               }
             });
  }.observes('bookmarked'),

  wikiChanged: function() {
    var data = { wiki: this.get("wiki") };
    this._updatePost("wiki", data);
  }.observes('wiki'),

  postTypeChanged: function () {
    var data = { post_type: this.get("post_type") };
    this._updatePost("post_type", data);
  }.observes("post_type"),

  _updatePost: function (field, data) {
    var self = this;
    Discourse.ajax("/posts/" + this.get("id") + "/" + field, {
      type: "PUT",
      data: data
    }).then(function () {
      self.incrementProperty("version");
    }, function (error) {
      if (error && error.responseText) {
        bootbox.alert($.parseJSON(error.responseText).errors[0]);
      } else {
        bootbox.alert(I18n.t("generic_error"));
      }
    });
  },

  internalLinks: function() {
    if (this.blank('link_counts')) return null;
    return this.get('link_counts').filterProperty('internal').filterProperty('title');
  }.property('link_counts.@each.internal'),

  // Edits are the version - 1, so version 2 = 1 edit
  editCount: function() { return this.get('version') - 1; }.property('version'),

  flagsAvailable: function() {
    var post = this;
    return Discourse.Site.currentProp('flagTypes').filter(function(item) {
      return post.get("actionByName." + item.get('name_key') + ".can_act");
    });
  }.property('actions_summary.@each.can_act'),

  actionsHistory: function() {
    if (!this.present('actions_summary')) return null;

    return this.get('actions_summary').filter(function(i) {
      if (i.get('count') === 0) return false;
      if (i.get('users') && i.get('users').length > 0) return true;
      return !i.get('hidden');
    });
  }.property('actions_summary.@each.users', 'actions_summary.@each.count'),

  // Save a post and call the callback when done.
  save: function(complete, error) {
    var self = this;
    if (!this.get('newPost')) {
      // We're updating a post
      return Discourse.ajax("/posts/" + (this.get('id')), {
        type: 'PUT',
        dataType: 'json',
        data: {
          post: { raw: this.get('raw'), edit_reason: this.get('editReason') },
          image_sizes: this.get('imageSizes')
        }
      }).then(function(result) {
        // If we received a category update, update it
        self.set('version', result.post.version);
        if (result.category) Discourse.Site.current().updateCategory(result.category);
        if (complete) complete(Discourse.Post.create(result.post));
      }, function(result) {
        // Post failed to update
        if (error) error(result);
      });

    } else {

      // We're saving a post
      var data = {
        raw: this.get('raw'),
        topic_id: this.get('topic_id'),
        is_warning: this.get('is_warning'),
        reply_to_post_number: this.get('reply_to_post_number'),
        category: this.get('category'),
        archetype: this.get('archetype'),
        title: this.get('title'),
        image_sizes: this.get('imageSizes'),
        target_usernames: this.get('target_usernames'),
      };

      var metaData = this.get('metaData');
      // Put the metaData into the request
      if (metaData) {
        data.meta_data = {};
        Ember.keys(metaData).forEach(function(key) { data.meta_data[key] = metaData.get(key); });
      }

      return Discourse.ajax("/posts", {
        type: 'POST',
        data: data
      }).then(function(result) {
        // Post created
        if (complete) complete(Discourse.Post.create(result));
      }, function(result) {
        // Failed to create a post
        if (error) error(result);
      });
    }
  },

  /**
    Expands the first post's content, if embedded and shortened.

    @method expandFirstPost
  **/
  expand: function() {
    var self = this;
    return Discourse.ajax("/posts/" + this.get('id') + "/expand-embed").then(function(post) {
      self.set('cooked', "<section class='expanded-embed'>" + post.cooked + "</section>" );
    });
  },

  /**
    Recover a deleted post

    @method recover
  **/
  recover: function() {
    var post = this;
    post.setProperties({
      deleted_at: null,
      deleted_by: null,
      user_deleted: false,
      can_delete: false
    });

    return Discourse.ajax("/posts/" + (this.get('id')) + "/recover", { type: 'PUT', cache: false }).then(function(data){
      post.setProperties({
        cooked: data.cooked,
        raw: data.raw,
        user_deleted: false,
        can_delete: true,
        version: data.version
      });
    });
  },

  /**
    Changes the state of the post to be deleted. Does not call the server, that should be
    done elsewhere.

    @method setDeletedState
    @param {Discourse.User} deletedBy The user deleting the post
  **/
  setDeletedState: function(deletedBy) {
    this.set('oldCooked', this.get('cooked'));

    // Moderators can delete posts. Users can only trigger a deleted at message, unless delete_removed_posts_after is 0.
    if (deletedBy.get('staff') || Discourse.SiteSettings.delete_removed_posts_after === 0) {
      this.setProperties({
        deleted_at: new Date(),
        deleted_by: deletedBy,
        can_delete: false
      });
    } else {
      this.setProperties({
        cooked: Discourse.Markdown.cook(I18n.t("post.deleted_by_author", {count: Discourse.SiteSettings.delete_removed_posts_after})),
        can_delete: false,
        version: this.get('version') + 1,
        can_recover: true,
        can_edit: false,
        user_deleted: true
      });
    }
  },

  /**
    Changes the state of the post to NOT be deleted. Does not call the server.
    This can only be called after setDeletedState was called, but the delete
    failed on the server.

    @method undoDeletedState
  **/
  undoDeleteState: function() {
    if (this.get('oldCooked')) {
      this.setProperties({
        deleted_at: null,
        deleted_by: null,
        cooked: this.get('oldCooked'),
        version: this.get('version') - 1,
        can_recover: false,
        user_deleted: false
      });
    }
  },

  /**
    Deletes a post

    @method destroy
    @param {Discourse.User} deletedBy The user deleting the post
  **/
  destroy: function(deletedBy) {
    this.setDeletedState(deletedBy);
    return Discourse.ajax("/posts/" + this.get('id'), {
      data: { context: window.location.pathname },
      type: 'DELETE'
    });
  },

  /**
    Updates a post from another's attributes. This will normally happen when a post is loading but
    is already found in an identity map.

    @method updateFromPost
    @param {Discourse.Post} otherPost The post we're updating from
  **/
  updateFromPost: function(otherPost) {
    var self = this;
    Object.keys(otherPost).forEach(function (key) {
      var value = otherPost[key],
          oldValue = self[key];

      if (key === "replyHistory") {
        return;
      }

      if (!value) { value = null; }
      if (!oldValue) { oldValue = null; }

      var skip = false;
      if (typeof value !== "function" && oldValue !== value) {
        // wishing for an identity map
        if (key === "reply_to_user" && value && oldValue) {
          skip = value.username === oldValue.username || Em.get(value, "username") === Em.get(oldValue, "username");
        }

        if (!skip) {
          self.set(key, value);
        }
      }
    });
  },

  /**
    Updates a post from a JSON packet. This is normally done after the post is saved to refresh any
    attributes.

    @method updateFromJson
    @param {Object} obj The Json data to update with
  **/
  updateFromJson: function(obj) {
    if (!obj) return;

    var skip, oldVal;

    // Update all the properties
    var post = this;
    _.each(obj, function(val,key) {
      if (key !== 'actions_summary'){
        oldVal = post[key];
        skip = false;

        if (val && val !== oldVal) {

          if (key === "reply_to_user" && val && oldVal) {
            skip = val.username === oldVal.username || Em.get(val, "username") === Em.get(oldVal, "username");
          }

          if(!skip) {
            post.set(key, val);
          }
        }
      }
    });

    // Rebuild actions summary
    this.set('actions_summary', Em.A());
    if (obj.actions_summary) {
      var lookup = Em.Object.create();
      _.each(obj.actions_summary,function(a) {
        var actionSummary;
        a.post = post;
        a.actionType = Discourse.Site.current().postActionTypeById(a.id);
        actionSummary = Discourse.ActionSummary.create(a);
        post.get('actions_summary').pushObject(actionSummary);
        lookup.set(a.actionType.get('name_key'), actionSummary);
      });
      this.set('actionByName', lookup);
    }
  },

  // Load replies to this post
  loadReplies: function() {
    if(this.get('loadingReplies')){
      return;
    }

    this.set('loadingReplies', true);
    this.set('replies', []);

    var self = this;
    return Discourse.ajax("/posts/" + (this.get('id')) + "/replies")
      .then(function(loaded) {
        var replies = self.get('replies');
        _.each(loaded,function(reply) {
          var post = Discourse.Post.create(reply);
          post.set('topic', self.get('topic'));
          replies.pushObject(post);
        });
      })
      ['finally'](function(){
        self.set('loadingReplies', false);
    });
  },

  // Whether to show replies directly below
  showRepliesBelow: function() {
    var replyCount = this.get('reply_count');

    // We don't show replies if there aren't any
    if (replyCount === 0) return false;

    // Always show replies if the setting `suppress_reply_directly_below` is false.
    if (!Discourse.SiteSettings.suppress_reply_directly_below) return true;

    // Always show replies if there's more than one
    if (replyCount > 1) return true;

    // If we have *exactly* one reply, we have to consider if it's directly below us
    var topic = this.get('topic');
    return !topic.isReplyDirectlyBelow(this);

  }.property('reply_count'),

  expandHidden: function() {
    var self = this;
    return Discourse.ajax("/posts/" + this.get('id') + "/cooked.json").then(function (result) {
      self.setProperties({
        cooked: result.cooked,
        cooked_hidden: false
      });
    });
  },

  rebake: function () {
    return Discourse.ajax("/posts/" + this.get("id") + "/rebake", { type: "PUT" });
  },

  unhide: function () {
    return Discourse.ajax("/posts/" + this.get("id") + "/unhide", { type: "PUT" });
  }
});

Discourse.Post.reopenClass({

  createActionSummary: function(result) {
    if (result.actions_summary) {
      var lookup = Em.Object.create();
      // this area should be optimized, it is creating way too many objects per post
      result.actions_summary = result.actions_summary.map(function(a) {
        a.post = result;
        a.actionType = Discourse.Site.current().postActionTypeById(a.id);
        var actionSummary = Discourse.ActionSummary.create(a);
        lookup[a.actionType.name_key] = actionSummary;
        return actionSummary;
      });
      result.set('actionByName', lookup);
    }
  },

  create: function(obj) {
    var result = this._super.apply(this, arguments);
    this.createActionSummary(result);
    if (obj && obj.reply_to_user) {
      result.set('reply_to_user', Discourse.User.create(obj.reply_to_user));
    }
    return result;
  },

  deleteMany: function(selectedPosts, selectedReplies) {
    return Discourse.ajax("/posts/destroy_many", {
      type: 'DELETE',
      data: {
        post_ids: selectedPosts.map(function(p) { return p.get('id'); }),
        reply_post_ids: selectedReplies.map(function(p) { return p.get('id'); })
      }
    });
  },

  loadRevision: function(postId, version) {
    return Discourse.ajax("/posts/" + postId + "/revisions/" + version + ".json").then(function (result) {
      return Em.Object.create(result);
    });
  },

  hideRevision: function(postId, version) {
    return Discourse.ajax("/posts/" + postId + "/revisions/" + version + "/hide", { type: 'PUT' });
  },

  showRevision: function(postId, version) {
    return Discourse.ajax("/posts/" + postId + "/revisions/" + version + "/show", { type: 'PUT' });
  },

  loadQuote: function(postId) {
    return Discourse.ajax("/posts/" + postId + ".json").then(function (result) {
      var post = Discourse.Post.create(result);
      return Discourse.Quote.build(post, post.get('raw'));
    });
  },

  loadRawEmail: function(postId) {
    return Discourse.ajax("/posts/" + postId + "/raw-email").then(function (result) {
      return result.raw_email;
    });
  },

  load: function(postId) {
    return Discourse.ajax("/posts/" + postId + ".json").then(function (result) {
      return Discourse.Post.create(result);
    });
  },

  bookmark: function(postId, bookmarked) {
    return Discourse.ajax("/posts/" + postId + "/bookmark", { type: 'PUT', data: { bookmarked: bookmarked } });
  }

});
