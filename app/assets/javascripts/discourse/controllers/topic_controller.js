(function() {

  Discourse.TopicController = Ember.ObjectController.extend(Discourse.Presence, {
    /* A list of usernames we want to filter by
    */

    userFilters: new Em.Set(),
    multiSelect: false,
    bestOf: false,
    showExtraHeaderInfo: false,
    needs: ['header', 'modal', 'composer', 'quoteButton'],
    filter: (function() {
      if (this.get('bestOf') === true) {
        return 'best_of';
      }
      if (this.get('userFilters').length > 0) {
        return 'user';
      }
      return null;
    }).property('userFilters.[]', 'bestOf'),
    filterDesc: (function() {
      var filter;
      if (!(filter = this.get('filter'))) {
        return null;
      }
      return Em.String.i18n("topic.filters." + filter);
    }).property('filter'),
    selectedPosts: (function() {
      var posts;
      if (!(posts = this.get('content.posts'))) {
        return null;
      }
      return posts.filterProperty('selected');
    }).property('content.posts.@each.selected'),
    selectedCount: (function() {
      if (!this.get('selectedPosts')) {
        return 0;
      }
      return this.get('selectedPosts').length;
    }).property('selectedPosts'),
    canMoveSelected: (function() {
      if (!this.get('content.can_move_posts')) {
        return false;
      }
      /* For now, we can move it if we can delete it since the posts
      */

      /* need to be deleted.
      */

      return this.get('canDeleteSelected');
    }).property('canDeleteSelected'),
    showExtraHeaderInfoChanged: (function() {
      return this.set('controllers.header.showExtraInfo', this.get('showExtraHeaderInfo'));
    }).observes('showExtraHeaderInfo'),
    canDeleteSelected: (function() {
      var canDelete, selectedPosts;
      selectedPosts = this.get('selectedPosts');
      if (!(selectedPosts && selectedPosts.length > 0)) {
        return false;
      }
      canDelete = true;
      selectedPosts.each(function(p) {
        if (!p.get('can_delete')) {
          canDelete = false;
          return false;
        }
      });
      return canDelete;
    }).property('selectedPosts'),
    multiSelectChanged: (function() {
      /* Deselect all posts when multi select is turned off
      */

      var posts;
      if (!this.get('multiSelect')) {
        if (posts = this.get('content.posts')) {
          return posts.forEach(function(p) {
            return p.set('selected', false);
          });
        }
      }
    }).observes('multiSelect'),
    hideProgress: (function() {
      if (!this.get('content.loaded')) {
        return true;
      }
      if (!this.get('currentPost')) {
        return true;
      }
      if (this.get('content.highest_post_number') < 2) {
        return true;
      }
      return this.present('filter');
    }).property('filter', 'content.loaded', 'currentPost'),
    selectPost: function(post) {
      return post.toggleProperty('selected');
    },
    toggleMultiSelect: function() {
      return this.toggleProperty('multiSelect');
    },
    moveSelected: function() {
      var _ref;
      return (_ref = this.get('controllers.modal')) ? _ref.show(Discourse.MoveSelectedView.create({
        topic: this.get('content'),
        selectedPosts: this.get('selectedPosts')
      })) : void 0;
    },
    deleteSelected: function() {
      var _this = this;
      return bootbox.confirm(Em.String.i18n("post.delete.confirm", {
        count: this.get('selectedCount')
      }), function(result) {
        if (result) {
          Discourse.Post.deleteMany(_this.get('selectedPosts'));
          return _this.get('content.posts').removeObjects(_this.get('selectedPosts'));
        }
      });
    },
    jumpTop: function() {
      return Discourse.routeTo(this.get('content.url'));
    },
    jumpBottom: function() {
      return Discourse.routeTo(this.get('content.lastPostUrl'));
    },
    cancelFilter: function() {
      this.set('bestOf', false);
      return this.get('userFilters').clear();
    },
    replyAsNewTopic: function(post) {
      var composerController, postLink, postUrl, promise;
      composerController = this.get('controllers.composer');
      /*TODO shut down topic draft cleanly if it exists ...
      */

      promise = composerController.open({
        action: Discourse.Composer.CREATE_TOPIC,
        draftKey: Discourse.Composer.REPLY_AS_NEW_TOPIC_KEY
      });
      postUrl = "" + location.protocol + "//" + location.host + (post.get('url'));
      postLink = "[" + (this.get('title')) + "](" + postUrl + ")";
      return promise.then(function() {
        return Discourse.Post.loadQuote(post.get('id')).then(function(q) {
          return composerController.appendText("" + (Em.String.i18n("post.continue_discussion", {
            postLink: postLink
          })) + "\n\n" + q);
        });
      });
    },
    /* Topic related
    */

    reply: function() {
      var composerController;
      composerController = this.get('controllers.composer');
      return composerController.open({
        topic: this.get('content'),
        action: Discourse.Composer.REPLY,
        draftKey: this.get('content.draft_key'),
        draftSequence: this.get('content.draft_sequence')
      });
    },
    toggleParticipant: function(user) {
      var userFilters, username;
      this.set('bestOf', false);
      username = Em.get(user, 'username');
      userFilters = this.get('userFilters');
      if (userFilters.contains(username)) {
        userFilters.remove(username);
      } else {
        userFilters.add(username);
      }
      return false;
    },
    enableBestOf: function(e) {
      this.set('bestOf', true);
      this.get('userFilters').clear();
      return false;
    },
    showBestOf: (function() {
      if (this.get('bestOf') === true) {
        return false;
      }
      return this.get('content.has_best_of') === true;
    }).property('bestOf', 'content.has_best_of'),
    postFilters: (function() {
      if (this.get('bestOf') === true) {
        return {
          bestOf: true
        };
      }
      return {
        userFilters: this.get('userFilters')
      };
    }).property('userFilters.[]', 'bestOf'),
    reloadTopics: (function() {
      var posts, topic,
        _this = this;
      topic = this.get('content');
      if (!topic) {
        return;
      }
      posts = topic.get('posts');
      if (!posts) {
        return;
      }
      posts.clear();
      this.set('content.loaded', false);
      return Discourse.Topic.find(this.get('content.id'), this.get('postFilters')).then(function(result) {
        var first;
        first = result.posts.first();
        if (first) {
          _this.set('currentPost', first.post_number);
        }
        jQuery('#topic-progress .solid').data('progress', false);
        result.posts.each(function(p) {
          return posts.pushObject(Discourse.Post.create(p, topic));
        });
        return _this.set('content.loaded', true);
      });
    }).observes('postFilters'),
    deleteTopic: function(e) {
      var _this = this;
      this.unsubscribe();
      return this.get('content')["delete"](function() {
        _this.set('message', "The topic has been deleted");
        return _this.set('loaded', false);
      });
    },
    toggleVisibility: function() {
      return this.get('content').toggleStatus('visible');
    },
    toggleClosed: function() {
      return this.get('content').toggleStatus('closed');
    },
    togglePinned: function() {
      return this.get('content').toggleStatus('pinned');
    },
    toggleArchived: function() {
      return this.get('content').toggleStatus('archived');
    },
    convertToRegular: function() {
      return this.get('content').convertArchetype('regular');
    },
    startTracking: function() {
      var screenTrack;
      screenTrack = Discourse.ScreenTrack.create({
        topic_id: this.get('content.id')
      });
      screenTrack.start();
      return this.set('content.screenTrack', screenTrack);
    },
    stopTracking: function() {
      var _ref;
      if (_ref = this.get('content.screenTrack')) {
        _ref.stop();
      }
      return this.set('content.screenTrack', null);
    },
    /* Toggle the star on the topic
    */

    toggleStar: function(e) {
      return this.get('content').toggleStar();
    },
    /* Receive notifications for this topic
    */

    subscribe: function() {
      var bus,
        _this = this;
      bus = Discourse.MessageBus;
      /* there is a condition where the view never calls unsubscribe, navigate to a topic from a topic
      */

      bus.unsubscribe('/topic/*');
      return bus.subscribe("/topic/" + (this.get('content.id')), function(data) {
        var posts, topic;
        topic = _this.get('content');
        if (data.notification_level_change) {
          topic.set('notification_level', data.notification_level_change);
          topic.set('notifications_reason_id', data.notifications_reason_id);
          return;
        }
        posts = topic.get('posts');
        if (posts.some(function(p) {
          return p.get('post_number') === data.post_number;
        })) {
          return;
        }
        topic.set('posts_count', topic.get('posts_count') + 1);
        topic.set('highest_post_number', data.post_number);
        topic.set('last_poster', data.user);
        topic.set('last_posted_at', data.created_at);
        return Discourse.notifyTitle();
      });
    },
    unsubscribe: function() {
      var bus, topicId;
      topicId = this.get('content.id');
      if (!topicId) {
        return;
      }
      bus = Discourse.MessageBus;
      return bus.unsubscribe("/topic/" + topicId);
    },
    /* Post related methods
    */

    replyToPost: function(post) {
      var composerController, promise, quoteController, quotedText,
        _this = this;
      composerController = this.get('controllers.composer');
      quoteController = this.get('controllers.quoteButton');
      quotedText = Discourse.BBCode.buildQuoteBBCode(quoteController.get('post'), quoteController.get('buffer'));
      quoteController.set('buffer', '');
      if (composerController.get('content.topic.id') === post.get('topic.id') && composerController.get('content.action') === Discourse.Composer.REPLY) {
        composerController.set('content.post', post);
        composerController.set('content.composeState', Discourse.Composer.OPEN);
        composerController.appendText(quotedText);
      } else {
        promise = composerController.open({
          post: post,
          action: Discourse.Composer.REPLY,
          draftKey: post.get('topic.draft_key'),
          draftSequence: post.get('topic.draft_sequence')
        });
        promise.then(function() {
          return composerController.appendText(quotedText);
        });
      }
      return false;
    },
    /* Edits a post
    */

    editPost: function(post) {
      return this.get('controllers.composer').open({
        post: post,
        action: Discourse.Composer.EDIT,
        draftKey: post.get('topic.draft_key'),
        draftSequence: post.get('topic.draft_sequence')
      });
    },
    toggleBookmark: function(post) {
      if (!Discourse.get('currentUser')) {
        alert(Em.String.i18n("bookmarks.not_bookmarked"));
        return;
      }
      post.toggleProperty('bookmarked');
      return false;
    },
    clearFlags: function(actionType) {
      return actionType.clearFlags();
    },
    /* Who acted on a particular post / action type
    */

    whoActed: function(actionType) {
      actionType.loadUsers();
      return false;
    },
    showPrivateInviteModal: function() {
      var modal, _ref;
      modal = Discourse.InvitePrivateModalView.create({
        topic: this.get('content')
      });
      if (_ref = this.get('controllers.modal')) {
        _ref.show(modal);
      }
      return false;
    },
    showInviteModal: function() {
      var _ref;
      if (_ref = this.get('controllers.modal')) {
        _ref.show(Discourse.InviteModalView.create({
          topic: this.get('content')
        }));
      }
      return false;
    },
    // Clicked the flag button
    showFlags: function(post) {
      var flagView, _ref;
      flagView = Discourse.FlagView.create({
        post: post,
        controller: this
      });
      return (_ref = this.get('controllers.modal')) ? _ref.show(flagView) : void 0;
    },
    showHistory: function(post) {
      var view, _ref;
      view = Discourse.HistoryView.create({
        originalPost: post
      });
      if (_ref = this.get('controllers.modal')) {
        _ref.show(view);
      }
      return false;
    },
    recoverPost: function(post) {
      post.set('deleted_at', null);
      return post.recover();
    },
    deletePost: function(post) {
      /* Moderators can delete posts. Regular users can only create a deleted at message.
      */
      if (Discourse.get('currentUser.moderator')) {
        post.set('deleted_at', new Date());
      } else {
        post.set('cooked', Discourse.Utilities.cook(Em.String.i18n("post.deleted_by_author")));
        post.set('can_delete', false);
        post.set('version', post.get('version') + 1);
      }
      return post["delete"]();
    }
  });

}).call(this);
