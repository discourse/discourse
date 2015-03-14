import ObjectController from 'discourse/controllers/object';
import BufferedContent from 'discourse/mixins/buffered-content';
import { spinnerHTML } from 'discourse/helpers/loading-spinner';
import Topic from 'discourse/models/topic';

export default ObjectController.extend(Discourse.SelectedPostsCount, BufferedContent, {
  multiSelect: false,
  needs: ['header', 'modal', 'composer', 'quote-button', 'search', 'topic-progress', 'application'],
  allPostsSelected: false,
  editingTopic: false,
  selectedPosts: null,
  selectedReplies: null,
  queryParams: ['filter', 'username_filters', 'show_deleted'],
  searchHighlight: null,

  maxTitleLength: Discourse.computed.setting('max_topic_title_length'),

  contextChanged: function() {
    this.set('controllers.search.searchContext', this.get('model.searchContext'));
  }.observes('topic'),

  _titleChanged: function() {
    const title = this.get('title');
    if (!Ember.isEmpty(title)) {

      // Note normally you don't have to trigger this, but topic titles can be updated
      // and are sometimes lazily loaded.
      this.send('refreshTitle');
    }
  }.observes('title', 'category'),

  termChanged: function() {
    const dropdown = this.get('controllers.header.visibleDropdown');
    const term = this.get('controllers.search.term');

    if(dropdown === 'search-dropdown' && term){
      this.set('searchHighlight', term);
    } else {
      if(this.get('searchHighlight')){
        this.set('searchHighlight', null);
      }
    }

  }.observes('controllers.search.term', 'controllers.header.visibleDropdown'),

  postStreamLoadedAllPostsChanged: function() {
    // semantics of loaded all posts are slightly diff at topic level,
    // it just means that we "once" loaded all posts, this means we don't
    // keep re-rendering the suggested topics when new posts zoom in
    let loaded = this.get('postStream.loadedAllPosts');

    if (loaded) {
      this.set('loadedTopicId', this.get('model.id'));
    } else {
      loaded = this.get('loadedTopicId') === this.get('model.id');
    }

    this.set('loadedAllPosts', loaded);

  }.observes('postStream', 'postStream.loadedAllPosts'),

  show_deleted: function(key, value) {
    const postStream = this.get('postStream');
    if (!postStream) { return; }

    if (arguments.length > 1) {
      postStream.set('show_deleted', value);
    }
    return postStream.get('show_deleted') ? true : undefined;
  }.property('postStream.summary'),

  filter: function(key, value) {
    const postStream = this.get('postStream');
    if (!postStream) { return; }

    if (arguments.length > 1) {
      postStream.set('summary', value === "summary");
    }
    return postStream.get('summary') ? "summary" : undefined;
  }.property('postStream.summary'),

  username_filters: function(key, value) {
    const postStream = this.get('postStream');
    if (!postStream) { return; }

    if (arguments.length > 1) {
      postStream.set('streamFilters.username_filters', value);
    }
    return postStream.get('streamFilters.username_filters');
  }.property('postStream.streamFilters.username_filters'),

  _clearSelected: function() {
    this.set('selectedPosts', []);
    this.set('selectedReplies', []);
  }.on('init'),

  _togglePinnedStates(property) {
    const value = this.get('pinned_at') ? false : true,
          topic = this.get('content');

    // optimistic update
    topic.setProperties({
      pinned_at: value,
      pinned_globally: value
    });

    return topic.saveStatus(property, value);
  },

  actions: {
    deleteTopic() {
      this.deleteTopic();
    },

    // Post related methods
    replyToPost(post) {
      const composerController = this.get('controllers.composer'),
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

        const opts = {
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

    toggleLike(post) {
      const likeAction = post.get('actionByName.like');
      if (likeAction && likeAction.get('canToggle')) {
        likeAction.toggle();
      }
    },

    recoverPost(post) {
      // Recovering the first post recovers the topic instead
      if (post.get('post_number') === 1) {
        this.recoverTopic();
        return;
      }
      post.recover();
    },

    deletePost(post) {

      // Deleting the first post deletes the topic
      if (post.get('post_number') === 1) {
        this.deleteTopic();
        return;
      }

      const user = Discourse.User.current(),
          replyCount = post.get('reply_count'),
          self = this;

      // If the user is staff and the post has replies, ask if they want to delete replies too.
      if (user.get('staff') && replyCount > 0) {
        bootbox.dialog(I18n.t("post.controls.delete_replies.confirm", {count: replyCount}), [
          {label: I18n.t("cancel"),
           'class': 'btn-danger rightg'},
          {label: I18n.t("post.controls.delete_replies.no_value"),
            callback() {
              post.destroy(user);
            }
          },
          {label: I18n.t("post.controls.delete_replies.yes_value"),
           'class': 'btn-primary',
            callback() {
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
          const response = $.parseJSON(e.responseText);
          if (response && response.errors) {
            bootbox.alert(response.errors[0]);
          } else {
            bootbox.alert(I18n.t('generic_error'));
          }
        });
      }
    },

    editPost(post) {
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

    toggleBookmark(post) {
      if (!Discourse.User.current()) {
        alert(I18n.t("bookmarks.not_bookmarked"));
        return;
      }
      if (post) {
        return post.toggleBookmark().catch(function(error) {
          if (error && error.responseText) {
            bootbox.alert($.parseJSON(error.responseText).errors[0]);
          } else {
            bootbox.alert(I18n.t('generic_error'));
          }
        });
      } else {
        return this.get("model").toggleBookmark();
      }
    },

    jumpTop() {
      this.get('controllers.topic-progress').send('jumpTop');
    },

    selectAll() {
      const posts = this.get('postStream.posts'),
          selectedPosts = this.get('selectedPosts');
      if (posts) {
        selectedPosts.addObjects(posts);
      }
      this.set('allPostsSelected', true);
    },

    deselectAll() {
      this.get('selectedPosts').clear();
      this.get('selectedReplies').clear();
      this.set('allPostsSelected', false);
    },

    toggleParticipant(user) {
      this.get('postStream').toggleParticipant(Em.get(user, 'username'));
    },

    editTopic() {
      if (!this.get('details.can_edit')) return false;

      this.set('editingTopic', true);
      return false;
    },

    cancelEditingTopic() {
      this.set('editingTopic', false);
      this.rollbackBuffer();
    },

    toggleMultiSelect() {
      this.toggleProperty('multiSelect');
    },

    finishedEditingTopic() {
      if (!this.get('editingTopic')) { return; }

      // save the modifications
      const self = this,
          props = this.get('buffered.buffer');

      Topic.update(this.get('model'), props).then(function() {
        // Note we roll back on success here because `update` saves
        // the properties to the topic.
        self.rollbackBuffer();
        self.set('editingTopic', false);
      }).catch(function(error) {
        if (error && error.responseText) {
          bootbox.alert($.parseJSON(error.responseText).errors[0]);
        } else {
          bootbox.alert(I18n.t('generic_error'));
        }
      });
    },

    toggledSelectedPost(post) {
      this.performTogglePost(post);
    },

    toggledSelectedPostReplies(post) {
      const selectedReplies = this.get('selectedReplies');
      if (this.performTogglePost(post)) {
        selectedReplies.addObject(post);
      } else {
        selectedReplies.removeObject(post);
      }
    },

    deleteSelected() {
      const self = this;
      bootbox.confirm(I18n.t("post.delete.confirm", { count: this.get('selectedPostsCount')}), function(result) {
        if (result) {

          // If all posts are selected, it's the same thing as deleting the topic
          if (self.get('allPostsSelected')) {
            return self.deleteTopic();
          }

          const selectedPosts = self.get('selectedPosts'),
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

    expandHidden(post) {
      post.expandHidden();
    },

    toggleVisibility() {
      this.get('content').toggleStatus('visible');
    },

    toggleClosed() {
      this.get('content').toggleStatus('closed');
    },

    recoverTopic() {
      this.get('content').recover();
    },

    makeBanner() {
      this.get('content').makeBanner();
    },

    removeBanner() {
      this.get('content').removeBanner();
    },

    togglePinned() {
      const value = this.get('pinned_at') ? false : true,
            topic = this.get('content');

      // optimistic update
      topic.setProperties({
        pinned_at: value ? moment() : null,
        pinned_globally: false
      });

      return topic.saveStatus("pinned", value);
    },

    pinGlobally() {
      const topic = this.get('content');

      // optimistic update
      topic.setProperties({
        pinned_at: moment(),
        pinned_globally: true
      });

      return topic.saveStatus("pinned_globally", true);
    },

    toggleArchived() {
      this.get('content').toggleStatus('archived');
    },

    // Toggle the star on the topic
    toggleStar() {
      this.get('content').toggleStar();
    },

    clearPin() {
      this.get('content').clearPin();
    },

    togglePinnedForUser() {
      if (this.get('pinned_at')) {
        if (this.get('pinned')) {
          this.get('content').clearPin();
        } else {
          this.get('content').rePin();
        }
      }
    },

    replyAsNewTopic(post) {
      const composerController = this.get('controllers.composer'),
            quoteController = this.get('controllers.quote-button'),
            quotedText = Discourse.Quote.build(quoteController.get('post'), quoteController.get('buffer')),
            self = this;

      quoteController.deselectText();

      composerController.open({
        action: Discourse.Composer.CREATE_TOPIC,
        draftKey: Discourse.Composer.REPLY_AS_NEW_TOPIC_KEY,
        categoryId: this.get('category.id')
      }).then(function() {
        return Em.isEmpty(quotedText) ? Discourse.Post.loadQuote(post.get('id')) : quotedText;
      }).then(function(q) {
        const postUrl = "" + location.protocol + "//" + location.host + (post.get('url')),
              postLink = "[" + self.get('title') + "](" + postUrl + ")";
        composerController.appendText(I18n.t("post.continue_discussion", { postLink: postLink }) + "\n\n" + q);
      });
    },

    expandFirstPost(post) {
      const self = this;
      this.set('loadingExpanded', true);
      post.expand().then(function() {
        self.set('firstPostExpanded', true);
      }).catch(function(error) {
        bootbox.alert($.parseJSON(error.responseText).errors);
      }).finally(function() {
        self.set('loadingExpanded', false);
      });
    },

    retryLoading() {
      const self = this;
      self.set('retrying', true);
      this.get('postStream').refresh().then(function() {
        self.set('retrying', false);
      }, function() {
        self.set('retrying', false);
      });
    },

    toggleWiki(post) {
      // the request to the server is made in an observer in the post class
      post.toggleProperty('wiki');
    },

    togglePostType(post) {
      // the request to the server is made in an observer in the post class
      const regular = this.site.get('post_types.regular'),
            moderator = this.site.get('post_types.moderator_action');

      if (post.get("post_type") === moderator) {
        post.set("post_type", regular);
      } else {
        post.set("post_type", moderator);
      }
    },

    rebakePost(post) {
      post.rebake();
    },

    unhidePost(post) {
      post.unhide();
    }
  },

  togglePinnedState() {
    this.send('togglePinnedForUser');
  },

  showExpandButton: function() {
    const post = this.get('post');
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
    const selectedPosts = this.get('selectedPosts');

    if (this.get('allPostsSelected')) return true;
    if (this.get('selectedPostsCount') === 0) return false;

    let canDelete = true;
    selectedPosts.forEach(function(p) {
      if (!p.get('can_delete')) {
        canDelete = false;
        return false;
      }
    });
    return canDelete;
  }.property('selectedPostsCount'),

  hasError: Ember.computed.or('notFoundHtml', 'message'),
  noErrorYet: Ember.computed.not('hasError'),

  multiSelectChanged: function() {
    // Deselect all posts when multi select is turned off
    if (!this.get('multiSelect')) {
      this.send('deselectAll');
    }
  }.observes('multiSelect'),

  deselectPost(post) {
    this.get('selectedPosts').removeObject(post);

    const selectedReplies = this.get('selectedReplies');
    selectedReplies.removeObject(post);

    const selectedReply = selectedReplies.findProperty('post_number', post.get('reply_to_post_number'));
    if (selectedReply) { selectedReplies.removeObject(selectedReply); }

    this.set('allPostsSelected', false);
  },

  postSelected(post) {
    if (this.get('allPostsSelected')) { return true; }
    if (this.get('selectedPosts').contains(post)) { return true; }
    if (this.get('selectedReplies').findProperty('post_number', post.get('reply_to_post_number'))) { return true; }

    return false;
  },

  showStarButton: function() {
    return Discourse.User.current() && !this.get('isPrivateMessage');
  }.property('isPrivateMessage'),

  loadingHTML: function() {
    return spinnerHTML;
  }.property(),

  recoverTopic() {
    this.get('content').recover();
  },

  deleteTopic() {
    this.unsubscribe();
    this.get('content').destroy(Discourse.User.current());
  },

  // Receive notifications for this topic
  subscribe() {
    // Unsubscribe before subscribing again
    this.unsubscribe();

    const self = this;
    this.messageBus.subscribe("/topic/" + this.get('id'), function(data) {
      const topic = self.get('model');

      if (data.notification_level_change) {
        topic.set('details.notification_level', data.notification_level_change);
        topic.set('details.notifications_reason_id', data.notifications_reason_id);
        return;
      }

      const postStream = self.get('postStream');
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

  unsubscribe() {
    const topicId = this.get('content.id');
    if (!topicId) return;

    // there is a condition where the view never calls unsubscribe, navigate to a topic from a topic
    this.messageBus.unsubscribe('/topic/*');
  },

  // Topic related
  reply() {
    this.replyToPost();
  },

  performTogglePost(post) {
    const selectedPosts = this.get('selectedPosts');
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
    const currentPost = this.get('currentPost');
    if (currentPost) {
      this.send('postChangedRoute', currentPost);
    }
  }.observes('currentPost'),

  readPosts(topicId, postNumbers) {
    const postStream = this.get('postStream');

    if(this.get('postStream.topic.id') === topicId){
      _.each(postStream.get('posts'), function(post){
        // optimise heavy loop
        // TODO identity map for postNumber
        if(_.include(postNumbers,post.post_number) && !post.read){
          post.set("read", true);
        }
      });

      const max = _.max(postNumbers);
      if(max > this.get('last_read_post_number')){
        this.set('last_read_post_number', max);
      }
    }
  },

  // Called the the topmost visible post on the page changes.
  topVisibleChanged(post) {
    if (!post) { return; }

    const postStream = this.get('postStream'),
        firstLoadedPost = postStream.get('firstLoadedPost');

    this.set('currentPost', post.get('post_number'));

    if (post.get('post_number') === 1) { return; }

    if (firstLoadedPost && firstLoadedPost === post) {
      // Note: jQuery shouldn't be done in a controller, but how else can we
      // trigger a scroll after a promise resolves in a controller? We need
      // to do this to preserve upwards infinte scrolling.
      const $body = $('body');
      let $elem = $('#post-cloak-' + post.get('post_number'));
      const distToElement = $body.scrollTop() - $elem.position().top;

      postStream.prependMore().then(function() {
        Em.run.next(function () {
          $elem = $('#post-cloak-' + post.get('post_number'));

          // Quickly going back might mean the element is destroyed
          const position = $elem.position();
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
  bottomVisibleChanged(post) {
    if (!post) { return; }

    const postStream = this.get('postStream'),
        lastLoadedPost = postStream.get('lastLoadedPost');

    this.set('controllers.topic-progress.progressPosition', postStream.progressIndexOfPost(post));

    if (lastLoadedPost && lastLoadedPost === post) {
      postStream.appendMore();
    }
  },

  _showFooter: function() {
    this.set("controllers.application.showFooter", this.get("postStream.loadedAllPosts"));
  }.observes("postStream.loadedAllPosts")

});
