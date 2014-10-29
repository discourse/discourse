import ObjectController from 'discourse/controllers/object';

export default ObjectController.extend(Discourse.SelectedPostsCount, {
  multiSelect: false,
  needs: ['header', 'modal', 'composer', 'quote-button', 'search', 'topic-progress'],
  allPostsSelected: false,
  editingTopic: false,
  selectedPosts: null,
  selectedReplies: null,
  queryParams: ['filter', 'username_filters', 'show_deleted'],

  maxTitleLength: Discourse.computed.setting('max_topic_title_length'),

  contextChanged: function() {
    this.set('controllers.search.searchContext', this.get('model.searchContext'));
  }.observes('topic'),

  _titleChanged: function() {
    var title = this.get('title');
    if (!Em.empty(title)) {

      // Note normally you don't have to trigger this, but topic titles can be updated
      // and are sometimes lazily loaded.
      this.send('refreshTitle');
    }
  }.observes('title', 'category'),

  termChanged: function() {
    var dropdown = this.get('controllers.header.visibleDropdown');
    var term = this.get('controllers.search.term');

    if(dropdown === 'search-dropdown' && term){
      this.set('searchHighlight', term);
    } else {
      if(this.get('searchHighlight')){
        this.set('searchHighlight', null);
      }
    }

  }.observes('controllers.search.term', 'controllers.header.visibleDropdown'),

  show_deleted: function(key, value) {
    var postStream = this.get('postStream');
    if (!postStream) { return; }

    if (arguments.length > 1) {
      postStream.set('show_deleted', value);
    }
    return postStream.get('show_deleted') ? true : null;
  }.property('postStream.summary'),

  filter: function(key, value) {
    var postStream = this.get('postStream');
    if (!postStream) { return; }

    if (arguments.length > 1) {
      postStream.set('summary', value === "summary");
    }
    return postStream.get('summary') ? "summary" : null;
  }.property('postStream.summary'),

  username_filters: Discourse.computed.queryAlias('postStream.streamFilters.username_filters'),

  init: function() {
    this._super();
    this.set('selectedPosts', []);
    this.set('selectedReplies', []);
  },

  actions: {
    // Post related methods
    replyToPost: function(post) {
      var composerController = this.get('controllers.composer'),
          quoteController = this.get('controllers.quote-button'),
          quotedText = Discourse.Quote.build(quoteController.get('post'), quoteController.get('buffer')),
          topic = post ? post.get('topic') : this.get('model');

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

        composerController.open(opts).then(function() {
          composerController.appendText(quotedText);
        });
      }
      return false;
    },

    toggleLike: function(post) {
      var likeAction = post.get('actionByName.like');
      if (likeAction && likeAction.get('canToggle')) {
        likeAction.toggle();
      }
    },

    recoverPost: function(post) {
      // Recovering the first post recovers the topic instead
      if (post.get('post_number') === 1) {
        this.recoverTopic();
        return;
      }
      post.recover();
    },

    deletePost: function(post) {

      // Deleting the first post deletes the topic
      if (post.get('post_number') === 1) {
        this.deleteTopic();
        return;
      }

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
        post.destroy(user).then(null, function(e) {
          post.undoDeleteState();
          var response = $.parseJSON(e.responseText);
          if (response && response.errors) {
            bootbox.alert(response.errors[0]);
          } else {
            bootbox.alert(I18n.t('generic_error'));
          }
        });
      }
    },

    editPost: function(post) {
      if (!Discourse.User.current()) {
        return bootbox.alert(I18n.t('post.controls.edit_anonymous'));
      }

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

    jumpTop: function() {
      this.get('controllers.topic-progress').send('jumpTop');
    },

    selectAll: function() {
      var posts = this.get('postStream.posts'),
          selectedPosts = this.get('selectedPosts');
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
      if (this.get('editingTopic')) {

        var topic = this.get('model');

        // Topic title hasn't been sanitized yet, so the template shouldn't trust it.
        this.set('topicSaving', true);

        // manually update the titles & category
        var backup = topic.setPropertiesBackup({
          title: this.get('newTitle'),
          category_id: parseInt(this.get('newCategoryId'), 10),
          fancy_title: this.get('newTitle')
        });

        // save the modifications
        var self = this;
        topic.save().then(function(result){
          // update the title if it has been changed (cleaned up) server-side
          topic.setProperties(Em.getProperties(result.basic_topic, 'title', 'fancy_title'));
          self.set('topicSaving', false);
        }, function(error) {
          self.setProperties({ editingTopic: true, topicSaving: false });
          topic.setProperties(backup);
          if (error && error.responseText) {
            bootbox.alert($.parseJSON(error.responseText).errors[0]);
          } else {
            bootbox.alert(I18n.t('generic_error'));
          }
        });

        // close editing mode
        self.set('editingTopic', false);
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
              toRemove = [];

          Discourse.Post.deleteMany(selectedPosts, selectedReplies);
          postStream.get('posts').forEach(function (p) {
            if (self.postSelected(p)) { toRemove.addObject(p); }
          });

          postStream.removePosts(toRemove);
          self.send('toggleMultiSelect');
        }
      });
    },

    expandHidden: function(post) {
      post.expandHidden();
    },

    toggleVisibility: function() {
      this.get('content').toggleStatus('visible');
    },

    toggleClosed: function() {
      this.get('content').toggleStatus('closed');
    },

    makeBanner: function() {
      this.get('content').makeBanner();
    },

    removeBanner: function() {
      this.get('content').removeBanner();
    },

    togglePinned: function() {
      // Note that this is different than clearPin
      this.get('content').setStatus('pinned', this.get('pinned_at') ? false : true);
    },

    togglePinnedGlobally: function() {
      // Note that this is different than clearPin
      this.get('content').setStatus('pinned_globally', this.get('pinned_at') ? false : true);
    },

    toggleArchived: function() {
      this.get('content').toggleStatus('archived');
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

    replyAsNewTopic: function(post) {
      var composerController = this.get('controllers.composer'),
          quoteController = this.get('controllers.quote-button'),
          quotedText = Discourse.Quote.build(quoteController.get('post'), quoteController.get('buffer')),
          self = this;

      quoteController.deselectText();

      composerController.open({
        action: Discourse.Composer.CREATE_TOPIC,
        draftKey: Discourse.Composer.REPLY_AS_NEW_TOPIC_KEY
      }).then(function() {
        return Em.isEmpty(quotedText) ? Discourse.Post.loadQuote(post.get('id')) : quotedText;
      }).then(function(q) {
        var postUrl = "" + location.protocol + "//" + location.host + (post.get('url')),
            postLink = "[" + self.get('title') + "](" + postUrl + ")";
        composerController.appendText(I18n.t("post.continue_discussion", { postLink: postLink }) + "\n\n" + q);
      });
    },

    expandFirstPost: function(post) {
      var self = this;
      this.set('loadingExpanded', true);
      post.expand().then(function() {
        self.set('firstPostExpanded', true);
      }).catch(function(error) {
        bootbox.alert($.parseJSON(error.responseText).errors);
      }).finally(function() {
        self.set('loadingExpanded', false);
      });
    },

    retryLoading: function() {
      var self = this;
      self.set('retrying', true);
      this.get('postStream').refresh().then(function() {
        self.set('retrying', false);
      }, function() {
        self.set('retrying', false);
      });
    },

    toggleWiki: function(post) {
      // the request to the server is made in an observer in the post class
      post.toggleProperty('wiki');
    },

    togglePostType: function (post) {
      // the request to the server is made in an observer in the post class
      var regular = Discourse.Site.currentProp('post_types.regular'),
          moderator = Discourse.Site.currentProp('post_types.moderator_action');

      if (post.get("post_type") === moderator) {
        post.set("post_type", regular);
      } else {
        post.set("post_type", moderator);
      }
    },

    rebakePost: function (post) {
      post.rebake();
    },

    unhidePost: function (post) {
      post.unhide();
    }
  },

  showExpandButton: function() {
    var post = this.get('post');
    return post.get('post_number') === 1 && post.get('topic.expandable_first_post');
  }.property(),

  canMergeTopic: function() {
    if (!this.get('details.can_move_posts')) return false;
    return (this.get('selectedPostsCount') > 0);
  }.property('selectedPostsCount'),

  canSplitTopic: function() {
    if (!this.get('details.can_move_posts')) return false;
    if (this.get('allPostsSelected')) return false;
    return (this.get('selectedPostsCount') > 0);
  }.property('selectedPostsCount'),

  canChangeOwner: function() {
    if (!Discourse.User.current() || !Discourse.User.current().admin) return false;
    return !!this.get('selectedPostsUsername');
  }.property('selectedPostsUsername'),

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

  hasError: Ember.computed.or('notFoundHtml', 'message'),

  multiSelectChanged: function() {
    // Deselect all posts when multi select is turned off
    if (!this.get('multiSelect')) {
      this.send('deselectAll');
    }
  }.observes('multiSelect'),

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

  showStarButton: function() {
    return Discourse.User.current() && !this.get('isPrivateMessage');
  }.property('isPrivateMessage'),

  loadingHTML: function() {
    return "<div class='spinner'></div>";
  }.property(),

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

      var postStream = topicController.get('postStream');
      switch (data.type) {
        case "revised":
        case "acted":
        case "rebaked": {
          // TODO we could update less data for "acted" (only post actions)
          postStream.triggerChangedPost(data.id, data.updated_at);
          return;
        }
        case "deleted": {
          postStream.triggerDeletedPost(data.id, data.post_number);
          return;
        }
        case "recovered": {
          postStream.triggerRecoveredPost(data.id, data.post_number);
          return;
        }
        case "created": {
          postStream.triggerNewPostInStream(data.id);
          return;
        }
        default: {
          Em.Logger.warn("unknown topic bus message type", data);
        }
      }
    });
  },

  unsubscribe: function() {
    var topicId = this.get('content.id');
    if (!topicId) return;

    // there is a condition where the view never calls unsubscribe, navigate to a topic from a topic
    Discourse.MessageBus.unsubscribe('/topic/*');
  },

  // Topic related
  reply: function() {
    this.replyToPost();
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

  // If our current post is changed, notify the router
  _currentPostChanged: function() {
    var currentPost = this.get('currentPost');
    if (currentPost) {
      this.send('postChangedRoute', currentPost);
    }
  }.observes('currentPost'),

  readPosts: function(topicId, postNumbers) {
    var postStream = this.get('postStream');

    if(this.get('postStream.topic.id') === topicId){
      _.each(postStream.get('posts'), function(post){
        // optimise heavy loop
        // TODO identity map for postNumber
        if(_.include(postNumbers,post.post_number) && !post.read){
          post.set("read", true);
        }
      });

      var max = _.max(postNumbers);
      if(max > this.get('last_read_post_number')){
        this.set('last_read_post_number', max);
      }
    }
  },

  /**
    Called the the topmost visible post on the page changes.

    @method topVisibleChanged
    @params {Discourse.Post} post that is at the top
  **/
  topVisibleChanged: function(post) {
    if (!post) { return; }

    var postStream = this.get('postStream'),
        firstLoadedPost = postStream.get('firstLoadedPost');

    this.set('currentPost', post.get('post_number'));

    if (post.get('post_number') === 1) { return; }

    if (firstLoadedPost && firstLoadedPost === post) {
      // Note: jQuery shouldn't be done in a controller, but how else can we
      // trigger a scroll after a promise resolves in a controller? We need
      // to do this to preserve upwards infinte scrolling.
      var $body = $('body'),
          $elem = $('#post-cloak-' + post.get('post_number')),
          distToElement = $body.scrollTop() - $elem.position().top;

      postStream.prependMore().then(function() {
        Em.run.next(function () {
          $elem = $('#post-cloak-' + post.get('post_number'));

          // Quickly going back might mean the element is destroyed
          var position = $elem.position();
          if (position && position.top) {
            $('html, body').scrollTop(position.top + distToElement);
          }
        });
      });
    }
  },

  /**
    Called the the bottommost visible post on the page changes.

    @method bottomVisibleChanged
    @params {Discourse.Post} post that is at the bottom
  **/
  bottomVisibleChanged: function(post) {
    if (!post) { return; }

    var postStream = this.get('postStream'),
        lastLoadedPost = postStream.get('lastLoadedPost');

    this.set('controllers.topic-progress.progressPosition', postStream.progressIndexOfPost(post));

    if (lastLoadedPost && lastLoadedPost === post) {
      postStream.appendMore();
    }
  }

});
