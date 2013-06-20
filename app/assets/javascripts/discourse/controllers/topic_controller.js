/**
  This controller supports all actions related to a topic

  @class TopicController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicController = Discourse.ObjectController.extend(Discourse.SelectedPostsCount, {
  multiSelect: false,
  summaryCollapsed: true,
  needs: ['header', 'modal', 'composer', 'quoteButton'],
  allPostsSelected: false,
  selectedPosts: new Em.Set(),
  editingTopic: false,

  jumpTopDisabled: function() {
    return this.get('currentPost') === 1;
  }.property('currentPost'),

  jumpBottomDisabled: function() {
    return this.get('currentPost') === this.get('highest_post_number');
  }.property('currentPost'),

  canMergeTopic: function() {
    if (!this.get('details.can_move_posts')) return false;
    return (this.get('selectedPostsCount') > 0);
  }.property('selectedPostsCount'),

  canSplitTopic: function() {
    if (!this.get('details.can_move_posts')) return false;
    if (this.get('allPostsSelected')) return false;
    return (this.get('selectedPostsCount') > 0);
  }.property('selectedPostsCount'),

  categories: function() {
    return Discourse.Category.list();
  }.property(),

  canSelectAll: Em.computed.not('allPostsSelected'),

  canDeselectAll: function () {
    if (this.get('selectedPostsCount') > 0) return true;
    if (this.get('allPostsSelected')) return true;
  }.property('selectedPostsCount', 'allPostsSelected'),

  canDeleteSelected: function() {
    var selectedPosts = this.get('selectedPosts');

    if (this.get('allPostsSelected')) return true;
    if (this.get('selectedPostsCount') === 0) return false;

    var canDelete = true;
    selectedPosts.forEach(function(p) {
      if (!p.get('can_delete')) {
        canDelete = false;
        return false;
      }
    });
    return canDelete;
  }.property('selectedPostsCount'),

  multiSelectChanged: function() {
    // Deselect all posts when multi select is turned off
    if (!this.get('multiSelect')) {
      this.deselectAll();
    }
  }.observes('multiSelect'),

  hideProgress: function() {
    if (!this.get('postStream.loaded')) return true;
    if (!this.get('currentPost')) return true;
    if (this.get('postStream.filteredPostsCount') < 2) return true;
    return false;
  }.property('postStream.loaded', 'currentPost', 'postStream.filteredPostsCount'),

  selectPost: function(post) {
    var selectedPosts = this.get('selectedPosts');
    if (selectedPosts.contains(post)) {
      selectedPosts.removeObject(post);
      this.set('allPostsSelected', false);
    } else {
      selectedPosts.addObject(post);

      // If the user manually selects all posts, all posts are selected
      if (selectedPosts.length === this.get('posts_count')) {
        this.set('allPostsSelected');
      }
    }
  },

  selectAll: function() {
    var posts = this.get('posts');
    var selectedPosts = this.get('selectedPosts');
    if (posts) {
      selectedPosts.addObjects(posts);
    }
    this.set('allPostsSelected', true);
  },

  deselectAll: function() {
    this.get('selectedPosts').clear();
    this.set('allPostsSelected', false);
  },

  toggleMultiSelect: function() {
    this.toggleProperty('multiSelect');
  },

  toggleSummary: function() {
    this.toggleProperty('summaryCollapsed');
  },

  editTopic: function() {
    if (!this.get('details.can_edit')) return false;

    this.setProperties({
      editingTopic: true,
      newTitle: this.get('title'),
      newCategoryId: this.get('category_id')
    });
    return false;
  },

  // close editing mode
  cancelEditingTopic: function() {
    this.set('editingTopic', false);
  },

  finishedEditingTopic: function() {
    var topicController = this;
    if (this.get('editingTopic')) {

      var topic = this.get('model');

      // manually update the titles & category
      topic.setProperties({
        title: this.get('newTitle'),
        category_id: parseInt(this.get('newCategoryId'), 10),
        fancy_title: this.get('newTitle')
      });

      // save the modifications
      topic.save().then(function(result){
        // update the title if it has been changed (cleaned up) server-side
        var title = result.basic_topic.fancy_title;
        topic.setProperties({
          title: title,
          fancy_title: title
        });

      }, function(error) {
        topicController.set('editingTopic', true);
        if (error && error.responseText) {
          bootbox.alert($.parseJSON(error.responseText).errors[0]);
        } else {
          bootbox.alert(Em.String.i18n('generic_error'));
        }
      });

      // close editing mode
      topicController.set('editingTopic', false);
    }
  },

  deleteSelected: function() {
    var topicController = this;
    bootbox.confirm(Em.String.i18n("post.delete.confirm", { count: this.get('selectedPostsCount')}), function(result) {
      if (result) {

        // If all posts are selected, it's the same thing as deleting the topic
        if (topicController.get('allPostsSelected')) {
          return topicController.deleteTopic();
        }

        var selectedPosts = topicController.get('selectedPosts');
        Discourse.Post.deleteMany(selectedPosts);
        topicController.get('content.posts').removeObjects(selectedPosts);
        topicController.toggleMultiSelect();
      }
    });
  },

  jumpTop: function() {
    Discourse.URL.routeTo(this.get('url'));
  },

  jumpBottom: function() {
    Discourse.URL.routeTo(this.get('lastPostUrl'));
  },



  replyAsNewTopic: function(post) {
    // TODO shut down topic draft cleanly if it exists ...
    var composerController = this.get('controllers.composer');
    var promise = composerController.open({
      action: Discourse.Composer.CREATE_TOPIC,
      draftKey: Discourse.Composer.REPLY_AS_NEW_TOPIC_KEY
    });
    var postUrl = "" + location.protocol + "//" + location.host + (post.get('url'));
    var postLink = "[" + (this.get('title')) + "](" + postUrl + ")";

    promise.then(function() {
      Discourse.Post.loadQuote(post.get('id')).then(function(q) {
        composerController.appendText("" + (Em.String.i18n("post.continue_discussion", {
          postLink: postLink
        })) + "\n\n" + q);
      });
    });
  },

  // Topic related
  reply: function() {
    var composerController = this.get('controllers.composer');
    if (composerController.get('content.topic.id') === this.get('content.id') &&
        composerController.get('content.action') === Discourse.Composer.REPLY) {
      composerController.set('content.post', null);
      composerController.set('content.composeState', Discourse.Composer.OPEN);
    } else {
      composerController.open({
        topic: this.get('content'),
        action: Discourse.Composer.REPLY,
        draftKey: this.get('content.draft_key'),
        draftSequence: this.get('content.draft_sequence')
      });
    }
  },

  /**
    Toggle a participant for filtering

    @method toggleParticipant
  **/
  toggleParticipant: function(user) {
    this.get('postStream').toggleParticipant(Em.get(user, 'username'));
  },

  showFavoriteButton: function() {
    return Discourse.User.current() && !this.get('isPrivateMessage');
  }.property('isPrivateMessage'),

  deleteTopic: function() {
    var topicController = this;
    this.unsubscribe();
    this.get('content').destroy().then(function() {
      topicController.set('message', Em.String.i18n('topic.deleted'));
      topicController.set('loaded', false);
    });
  },

  toggleVisibility: function() {
    this.get('content').toggleStatus('visible');
  },

  toggleClosed: function() {
    this.get('content').toggleStatus('closed');
  },

  togglePinned: function() {
    this.get('content').toggleStatus('pinned');
  },

  toggleArchived: function() {
    this.get('content').toggleStatus('archived');
  },

  convertToRegular: function() {
    this.get('content').convertArchetype('regular');
  },

  // Toggle the star on the topic
  toggleStar: function(e) {
    this.get('content').toggleStar();
  },

  /**
    Clears the pin from a topic for the currently logged in user

    @method clearPin
  **/
  clearPin: function() {
    this.get('content').clearPin();
  },

  // Receive notifications for this topic
  subscribe: function() {

    // Unsubscribe before subscribing again
    this.unsubscribe();

    var bus = Discourse.MessageBus;

    var topicController = this;
    bus.subscribe("/topic/" + (this.get('id')), function(data) {
      var topic = topicController.get('model');
      if (data.notification_level_change) {
        topic.set('details.notification_level', data.notification_level_change);
        topic.set('details.notifications_reason_id', data.notifications_reason_id);
        return;
      }

      // Add the new post into the stream
      topicController.get('postStream').triggerNewPostInStream(data.id);
    });
  },

  unsubscribe: function() {
    var topicId = this.get('content.id');
    if (!topicId) return;

    // there is a condition where the view never calls unsubscribe, navigate to a topic from a topic
    Discourse.MessageBus.unsubscribe('/topic/*');
  },

  // Post related methods
  replyToPost: function(post) {
    var composerController = this.get('controllers.composer');
    var quoteController = this.get('controllers.quoteButton');
    var quotedText = Discourse.BBCode.buildQuoteBBCode(quoteController.get('post'), quoteController.get('buffer'));
    quoteController.set('buffer', '');

    if (composerController.get('content.topic.id') === post.get('topic.id') &&
        composerController.get('content.action') === Discourse.Composer.REPLY) {
      composerController.set('content.post', post);
      composerController.set('content.composeState', Discourse.Composer.OPEN);
      composerController.appendText(quotedText);
    } else {
      var promise = composerController.open({
        post: post,
        action: Discourse.Composer.REPLY,
        draftKey: post.get('topic.draft_key'),
        draftSequence: post.get('topic.draft_sequence')
      });
      promise.then(function() { composerController.appendText(quotedText); });
    }
    return false;
  },

  // Edits a post
  editPost: function(post) {
    this.get('controllers.composer').open({
      post: post,
      action: Discourse.Composer.EDIT,
      draftKey: post.get('topic.draft_key'),
      draftSequence: post.get('topic.draft_sequence')
    });
  },

  toggleBookmark: function(post) {
    if (!Discourse.User.current()) {
      alert(Em.String.i18n("bookmarks.not_bookmarked"));
      return;
    }
    post.toggleProperty('bookmarked');
    return false;
  },

  clearFlags: function(actionType) {
    actionType.clearFlags();
  },

  // Who acted on a particular post / action type
  whoActed: function(actionType) {
    actionType.loadUsers();
  },

  recoverPost: function(post) {
    post.set('deleted_at', null);
    post.recover();
  },

  deletePost: function(post) {
    // Moderators can delete posts. Regular users can only create a deleted at message.
    if (Discourse.User.current('staff')) {
      post.set('deleted_at', new Date());
    } else {
      post.set('cooked', Discourse.Markdown.cook(Em.String.i18n("post.deleted_by_author")));
      post.set('can_delete', false);
      post.set('version', post.get('version') + 1);
    }
    post.destroy();
  },

  removeAllowedUser: function(username) {
    this.get('details').removeAllowedUser(username);
  }
});


