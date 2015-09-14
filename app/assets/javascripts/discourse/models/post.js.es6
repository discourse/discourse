import RestModel from 'discourse/models/rest';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import ActionSummary from 'discourse/models/action-summary';
import { url, propertyEqual } from 'discourse/lib/computed';
import Quote from 'discourse/lib/quote';
import computed from 'ember-addons/ember-computed-decorators';

const Post = RestModel.extend({

  init() {
    this.set('replyHistory', []);
  },

  @computed()
  siteSettings() {
    // TODO: Remove this once one instantiate all `Discourse.Post` models via the store.
    return Discourse.SiteSettings;
  },

  shareUrl: function() {
    const user = Discourse.User.current();
    const userSuffix = user ? '?u=' + user.get('username_lower') : '';

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

  hasTimeGap: function() {
    return (this.get('daysSincePrevious') || 0) > Discourse.SiteSettings.show_time_gap_days;
  }.property('daysSincePrevious'),

  showName: function() {
    const name = this.get('name');
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

  // Don't drop the /1
  @computed('post_number', 'url')
  urlWithNumber(postNumber, postUrl) {
    return postNumber === 1 ? postUrl + "/1" : postUrl;
  },

  usernameUrl: url('username', '/users/%@'),

  showUserReplyTab: function() {
    return this.get('reply_to_user') && (
      !Discourse.SiteSettings.suppress_reply_directly_above ||
      this.get('reply_to_post_number') < (this.get('post_number') - 1)
    );
  }.property('reply_to_user', 'reply_to_post_number', 'post_number'),

  topicOwner: propertyEqual('topic.details.created_by.id', 'user_id'),
  hasHistory: Em.computed.gt('version', 1),

  canViewRawEmail: function() {
    return this.get("user_id") === Discourse.User.currentProp("id") || Discourse.User.currentProp('staff');
  }.property("user_id"),

  updatePostField(field, value) {
    const data = {};
    data[field] = value;

    Discourse.ajax(`/posts/${this.get('id')}/${field}`, { type: 'PUT', data }).then(() => {
      this.set(field, value);
      this.incrementProperty("version");
    }).catch(popupAjaxError);
  },

  internalLinks: function() {
    if (Ember.isEmpty(this.get('link_counts'))) return null;
    return this.get('link_counts').filterProperty('internal').filterProperty('title');
  }.property('link_counts.@each.internal'),

  // Edits are the version - 1, so version 2 = 1 edit
  editCount: function() { return this.get('version') - 1; }.property('version'),

  flagsAvailable: function() {
    const post = this;
    return Discourse.Site.currentProp('flagTypes').filter(function(item) {
      return post.get("actionByName." + item.get('name_key') + ".can_act");
    });
  }.property('actions_summary.@each.can_act'),

  actionsWithoutLikes: function() {
    if (!!Ember.isEmpty(this.get('actions_summary'))) return null;

    return this.get('actions_summary').filter(function(i) {
      if (i.get('count') === 0) return false;
      if (i.get('actionType.name_key') === 'like') { return false; }
      if (i.get('users') && i.get('users').length > 0) return true;
      return !i.get('hidden');
    });
  }.property('actions_summary.@each.users', 'actions_summary.@each.count'),

  afterUpdate(res) {
    if (res.category) {
      Discourse.Site.current().updateCategory(res.category);
    }
  },

  updateProperties() {
    return {
      post: { raw: this.get('raw'), edit_reason: this.get('editReason') },
      image_sizes: this.get('imageSizes')
    };
  },

  createProperties() {
    const data = this.getProperties(Discourse.Composer.serializedFieldsForCreate());
    data.reply_to_post_number = this.get('reply_to_post_number');
    data.image_sizes = this.get('imageSizes');

    const metaData = this.get('metaData');

    // Put the metaData into the request
    if (metaData) {
      data.meta_data = {};
      Ember.keys(metaData).forEach(function(key) { data.meta_data[key] = metaData.get(key); });
    }

    return data;
  },

  // Expands the first post's content, if embedded and shortened.
  expand() {
    const self = this;
    return Discourse.ajax("/posts/" + this.get('id') + "/expand-embed").then(function(post) {
      self.set('cooked', "<section class='expanded-embed'>" + post.cooked + "</section>" );
    });
  },

  // Recover a deleted post
  recover() {
    const post = this,
          initProperties = post.getProperties('deleted_at', 'deleted_by', 'user_deleted', 'can_delete');

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
    }).catch(function(error) {
      popupAjaxError(error);
      post.setProperties(initProperties);
    });
  },

  /**
    Changes the state of the post to be deleted. Does not call the server, that should be
    done elsewhere.
  **/
  setDeletedState(deletedBy) {
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
  **/
  undoDeleteState() {
    if (this.get('oldCooked')) {
      this.setProperties({
        deleted_at: null,
        deleted_by: null,
        cooked: this.get('oldCooked'),
        version: this.get('version') - 1,
        can_recover: false,
        can_delete: true,
        user_deleted: false
      });
    }
  },

  destroy(deletedBy) {
    this.setDeletedState(deletedBy);
    return Discourse.ajax("/posts/" + this.get('id'), {
      data: { context: window.location.pathname },
      type: 'DELETE'
    });
  },

  /**
    Updates a post from another's attributes. This will normally happen when a post is loading but
    is already found in an identity map.
  **/
  updateFromPost(otherPost) {
    const self = this;
    Object.keys(otherPost).forEach(function (key) {
      let value = otherPost[key],
          oldValue = self[key];

      if (key === "replyHistory") {
        return;
      }

      if (!value) { value = null; }
      if (!oldValue) { oldValue = null; }

      let skip = false;
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

  // Load replies to this post
  loadReplies() {
    if(this.get('loadingReplies')){
      return;
    }

    this.set('loadingReplies', true);
    this.set('replies', []);

    const self = this;
    return Discourse.ajax("/posts/" + (this.get('id')) + "/replies")
      .then(function(loaded) {
        const replies = self.get('replies');
        _.each(loaded,function(reply) {
          const post = Discourse.Post.create(reply);
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
    const replyCount = this.get('reply_count');

    // We don't show replies if there aren't any
    if (replyCount === 0) return false;

    // Always show replies if the setting `suppress_reply_directly_below` is false.
    if (!Discourse.SiteSettings.suppress_reply_directly_below) return true;

    // Always show replies if there's more than one
    if (replyCount > 1) return true;

    // If we have *exactly* one reply, we have to consider if it's directly below us
    const topic = this.get('topic');
    return !topic.isReplyDirectlyBelow(this);

  }.property('reply_count'),

  expandHidden() {
    const self = this;
    return Discourse.ajax("/posts/" + this.get('id') + "/cooked.json").then(function (result) {
      self.setProperties({
        cooked: result.cooked,
        cooked_hidden: false
      });
    });
  },

  rebake() {
    return Discourse.ajax("/posts/" + this.get("id") + "/rebake", { type: "PUT" });
  },

  unhide() {
    return Discourse.ajax("/posts/" + this.get("id") + "/unhide", { type: "PUT" });
  },

  toggleBookmark() {
    const self = this;
    let bookmarkedTopic;

    this.toggleProperty("bookmarked");

    if(this.get("bookmarked") && !this.get("topic.bookmarked")) {
      this.set("topic.bookmarked", true);
      bookmarkedTopic = true;
    }

    // need to wait to hear back from server (stuff may not be loaded)

    return Discourse.Post.updateBookmark(this.get('id'), this.get('bookmarked'))
      .then(function(result){
        self.set("topic.bookmarked", result.topic_bookmarked);
      })
      .catch(function(e) {
        self.toggleProperty("bookmarked");
        if (bookmarkedTopic) {self.set("topic.bookmarked", false); }
        throw e;
      });
  },

  updateActionsSummary(json) {
    if (json && json.id === this.get('id')) {
      json = Post.munge(json);
      this.set('actions_summary', json.actions_summary);
    }
  }

});

Post.reopenClass({

  munge(json) {
    if (json.actions_summary) {
      const lookup = Em.Object.create();

      // this area should be optimized, it is creating way too many objects per post
      json.actions_summary = json.actions_summary.map(function(a) {
        a.actionType = Discourse.Site.current().postActionTypeById(a.id);
        a.count = a.count || 0;
        const actionSummary = ActionSummary.create(a);
        lookup[a.actionType.name_key] = actionSummary;

        if (a.actionType.name_key === "like") {
          json.likeAction = actionSummary;
        }
        return actionSummary;
      });

      json.actionByName = lookup;
    }

    if (json && json.reply_to_user) {
      json.reply_to_user = Discourse.User.create(json.reply_to_user);
    }
    return json;
  },

  updateBookmark(postId, bookmarked) {
    return Discourse.ajax("/posts/" + postId + "/bookmark", {
      type: 'PUT',
      data: { bookmarked: bookmarked }
    });
  },

  deleteMany(selectedPosts, selectedReplies) {
    return Discourse.ajax("/posts/destroy_many", {
      type: 'DELETE',
      data: {
        post_ids: selectedPosts.map(function(p) { return p.get('id'); }),
        reply_post_ids: selectedReplies.map(function(p) { return p.get('id'); })
      }
    });
  },

  loadRevision(postId, version) {
    return Discourse.ajax("/posts/" + postId + "/revisions/" + version + ".json").then(function (result) {
      return Ember.Object.create(result);
    });
  },

  hideRevision(postId, version) {
    return Discourse.ajax("/posts/" + postId + "/revisions/" + version + "/hide", { type: 'PUT' });
  },

  showRevision(postId, version) {
    return Discourse.ajax("/posts/" + postId + "/revisions/" + version + "/show", { type: 'PUT' });
  },

  loadQuote(postId) {
    return Discourse.ajax("/posts/" + postId + ".json").then(function (result) {
      const post = Discourse.Post.create(result);
      return Quote.build(post, post.get('raw'), {raw: true, full: true});
    });
  },

  loadRawEmail(postId) {
    return Discourse.ajax("/posts/" + postId + "/raw-email").then(function (result) {
      return result.raw_email;
    });
  }

});

export default Post;
