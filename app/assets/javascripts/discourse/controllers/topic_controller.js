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
  editingTopic: false,
  selectedPosts: null,
  selectedReplies: null,

  init: function() {
    this._super();
    this.set('selectedPosts', new Em.Set());
    this.set('selectedReplies', new Em.Set());
  },

  actions: {
    jumpTop: function() {
      Discourse.URL.routeTo(this.get('url'));
    },

    jumpBottom: function() {
      Discourse.URL.routeTo(this.get('lastPostUrl'));
    },

    toggleSummary: function() {
      this.toggleProperty('summaryCollapsed');
    },

    selectAll: function() {
      var posts = this.get('postStream.posts');
      var selectedPosts = this.get('selectedPosts');
      if (posts) {
        selectedPosts.addObjects(posts);
      }
      this.set('allPostsSelected', true);
    },

    deselectAll: function() {
      this.get('selectedPosts').clear();
      this.get('selectedReplies').clear();
      this.set('allPostsSelected', false);
    },

    /**
      Toggle a participant for filtering

      @method toggleParticipant
    **/
    toggleParticipant: function(user) {
      this.get('postStream').toggleParticipant(Em.get(user, 'username'));
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

    toggleMultiSelect: function() {
      this.toggleProperty('multiSelect');
    },

    finishedEditingTopic: function() {
      var topicController = this;
      if (this.get('editingTopic')) {

        var topic = this.get('model');

        // Topic title hasn't been sanitized yet, so the template shouldn't trust it.
        this.set('topicSaving', true);

        // manually update the titles & category
        topic.setProperties({
          title: this.get('newTitle'),
          category_id: parseInt(this.get('newCategoryId'), 10),
          fancy_title: this.get('newTitle')
        });

        // save the modifications
        topic.save().then(function(result){
          // update the title if it has been changed (cleaned up) server-side
          var title       = result.basic_topic.title;
          var fancy_title = result.basic_topic.fancy_title;
          topic.setProperties({
            title: title,
            fancy_title: fancy_title
          });
          topicController.set('topicSaving', false);
        }, function(error) {
          topicController.set('editingTopic', true);
          topicController.set('topicSaving', false);
          if (error && error.responseText) {
            bootbox.alert($.parseJSON(error.responseText).errors[0]);
          } else {
            bootbox.alert(I18n.t('generic_error'));
          }
        });

        // close editing mode
        topicController.set('editingTopic', false);
      }
    },

    toggledSelectedPost: function(post) {
      this.performTogglePost(post);
    },

    toggledSelectedPostReplies: function(post) {
      var selectedReplies = this.get('selectedReplies');
      if (this.performTogglePost(post)) {
        selectedReplies.addObject(post);
      } else {
        selectedReplies.removeObject(post);
      }
    },

    deleteSelected: function() {
      var self = this;
      bootbox.confirm(I18n.t("post.delete.confirm", { count: this.get('selectedPostsCount')}), function(result) {
        if (result) {

          // If all posts are selected, it's the same thing as deleting the topic
          if (self.get('allPostsSelected')) {
            return self.deleteTopic();
          }

          var selectedPosts = self.get('selectedPosts'),
              selectedReplies = self.get('selectedReplies'),
              postStream = self.get('postStream'),
              toRemove = new Ember.Set();


          Discourse.Post.deleteMany(selectedPosts, selectedReplies);
          postStream.get('posts').forEach(function (p) {
            if (self.postSelected(p)) { toRemove.addObject(p); }
          });

          postStream.removePosts(toRemove);
          self.send('toggleMultiSelect');
        }
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
    toggleStar: function() {
      this.get('content').toggleStar();
    },


    /**
      Clears the pin from a topic for the currently logged in user

      @method clearPin
    **/
    clearPin: function() {
      this.get('content').clearPin();
    },

    resetRead: function() {
      Discourse.ScreenTrack.current().reset();
      this.unsubscribe();

      var topicController = this;
      this.get('model').resetRead().then(function() {
        topicController.set('message', I18n.t("topic.read_position_reset"));
        topicController.set('postStream.loaded', false);
      });
    },

    replyAsNewTopic: function(post) {
      var composerController = this.get('controllers.composer');
      var promise = composerController.open({
        action: Discourse.Composer.CREATE_TOPIC,
        draftKey: Discourse.Composer.REPLY_AS_NEW_TOPIC_KEY
      });
      var postUrl = "" + location.protocol + "//" + location.host + (post.get('url'));
      var postLink = "[" + (this.get('title')) + "](" + postUrl + ")";

      promise.then(function() {
        Discourse.Post.loadQuote(post.get('id')).then(function(q) {
          composerController.appendText(I18n.t("post.continue_discussion", {
            postLink: postLink
          }) + "\n\n" + q);
        });
      });
    }
  },

  jumpTopDisabled: function() {
    return (this.get('progressPosition') === 1);
  }.property('postStream.filteredPostsCount', 'progressPosition'),

  jumpBottomDisabled: function() {
    return this.get('progressPosition') >= this.get('postStream.filteredPostsCount');
  }.property('postStream.filteredPostsCount', 'progressPosition'),

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

  hasError: Ember.computed.or('errorBodyHtml', 'message'),

  streamPercentage: function() {
    if (!this.get('postStream.loaded')) { return 0; }
    if (this.get('postStream.filteredPostsCount') === 0) { return 0; }
    return this.get('progressPosition') / this.get('postStream.filteredPostsCount');
  }.property('postStream.loaded', 'progressPosition', 'postStream.filteredPostsCount'),

  multiSelectChanged: function() {
    // Deselect all posts when multi select is turned off
    if (!this.get('multiSelect')) {
      this.send('deselectAll');
    }
  }.observes('multiSelect'),

  hideProgress: function() {
    if (!this.get('postStream.loaded')) return true;
    if (!this.get('currentPost')) return true;
    if (this.get('postStream.filteredPostsCount') < 2) return true;
    return false;
  }.property('postStream.loaded', 'currentPost', 'postStream.filteredPostsCount'),

  deselectPost: function(post) {
    this.get('selectedPosts').removeObject(post);

    var selectedReplies = this.get('selectedReplies');
    selectedReplies.removeObject(post);

    var selectedReply = selectedReplies.findProperty('post_number', post.get('reply_to_post_number'));
    if (selectedReply) { selectedReplies.removeObject(selectedReply); }

    this.set('allPostsSelected', false);
  },

  postSelected: function(post) {
    if (this.get('allPostsSelected')) { return true; }
    if (this.get('selectedPosts').contains(post)) { return true; }
    if (this.get('selectedReplies').findProperty('post_number', post.get('reply_to_post_number'))) { return true; }

    return false;
  },

  showFavoriteButton: function() {
    return Discourse.User.current() && !this.get('isPrivateMessage');
  }.property('isPrivateMessage'),

  recoverTopic: function() {
    this.get('content').recover();
  },

  deleteTopic: function() {
    this.unsubscribe();
    this.get('content').destroy(Discourse.User.current());
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
    var quotedText = Discourse.Quote.build(quoteController.get('post'), quoteController.get('buffer'));

    var topic = post ? post.get('topic') : this.get('model');

    quoteController.set('buffer', '');

    if (composerController.get('content.topic.id') === topic.get('id') &&
        composerController.get('content.action') === Discourse.Composer.REPLY) {
      composerController.set('content.post', post);
      composerController.set('content.composeState', Discourse.Composer.OPEN);
      composerController.appendText(quotedText);
    } else {

      var opts = {
        action: Discourse.Composer.REPLY,
        draftKey: topic.get('draft_key'),
        draftSequence: topic.get('draft_sequence')
      };

      if(post && post.get("post_number") !== 1){
        opts.post = post;
      } else {
        opts.topic = topic;
      }

      var promise = composerController.open(opts);
      promise.then(function() { composerController.appendText(quotedText); });
    }
    return false;
  },

  // Topic related
  reply: function() {
    this.replyToPost();
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
      alert(I18n.t("bookmarks.not_bookmarked"));
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
    post.recover();
  },

  deletePost: function(post) {
    var user = Discourse.User.current(),
        replyCount = post.get('reply_count'),
        self = this;

    // If the user is staff and the post has replies, ask if they want to delete replies too.
    if (user.get('staff') && replyCount > 0) {
      bootbox.dialog(I18n.t("post.controls.delete_replies.confirm", {count: replyCount}), [
        {label: I18n.t("cancel"),
         'class': 'btn-danger rightg'},
        {label: I18n.t("post.controls.delete_replies.no_value"),
          callback: function() {
            post.destroy(user);
          }
        },
        {label: I18n.t("post.controls.delete_replies.yes_value"),
         'class': 'btn-primary',
          callback: function() {
            Discourse.Post.deleteMany([post], [post]);
            self.get('postStream.posts').forEach(function (p) {
              if (p === post || p.get('reply_to_post_number') === post.get('post_number')) {
                p.setDeletedState(user);
              }
            });
          }
        }
      ]);
    } else {
      post.destroy(user);
    }
  },

  performTogglePost: function(post) {
    var selectedPosts = this.get('selectedPosts');
    if (this.postSelected(post)) {
      this.deselectPost(post);
      return false;
    } else {
      selectedPosts.addObject(post);

      // If the user manually selects all posts, all posts are selected
      if (selectedPosts.length === this.get('posts_count')) {
        this.set('allPostsSelected', true);
      }
      return true;
    }
  },

  removeAllowedUser: function(username) {
    var self = this;
    bootbox.dialog(I18n.t("private_message_info.remove_allowed_user", {name: username}), [
      {label: I18n.t("no_value"),
       'class': 'btn-danger rightg'},
      {label: I18n.t("yes_value"),
       'class': 'btn-primary',
        callback: function() {
          self.get('details').removeAllowedUser(username);
        }
      }
    ]);
  }

});


