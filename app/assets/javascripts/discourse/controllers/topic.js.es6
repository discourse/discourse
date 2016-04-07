import BufferedContent from 'discourse/mixins/buffered-content';
import SelectedPostsCount from 'discourse/mixins/selected-posts-count';
import { spinnerHTML } from 'discourse/helpers/loading-spinner';
import Topic from 'discourse/models/topic';
import Quote from 'discourse/lib/quote';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import computed from 'ember-addons/ember-computed-decorators';
import Composer from 'discourse/models/composer';
import DiscourseURL from 'discourse/lib/url';

export default Ember.Controller.extend(SelectedPostsCount, BufferedContent, {
  needs: ['header', 'modal', 'composer', 'quote-button', 'topic-progress', 'application'],
  multiSelect: false,
  allPostsSelected: false,
  editingTopic: false,
  selectedPosts: null,
  selectedReplies: null,
  queryParams: ['filter', 'username_filters', 'show_deleted'],
  loadedAllPosts: Em.computed.or('model.postStream.loadedAllPosts', 'model.postStream.loadingLastPost'),
  enteredAt: null,
  retrying: false,
  adminMenuVisible: false,

  showRecover: Em.computed.and('model.deleted', 'model.details.can_recover'),
  isFeatured: Em.computed.or("model.pinned_at", "model.isBanner"),

  _titleChanged: function() {
    const title = this.get('model.title');
    if (!Ember.isEmpty(title)) {

      // Note normally you don't have to trigger this, but topic titles can be updated
      // and are sometimes lazily loaded.
      this.send('refreshTitle');
    }
  }.observes('model.title', 'category'),

  @computed('model.postStream.posts')
  postsToRender() {
    return this.capabilities.isAndroid ? this.get('model.postStream.posts')
                                       : this.get('model.postStream.postsWithPlaceholders');
  },

  @computed('model.postStream.loadingFilter')
  androidLoading(loading) {
    return this.capabilities.isAndroid && loading;
  },

  @computed('model.postStream.summary')
  show_deleted: {
    set(value) {
      const postStream = this.get('model.postStream');
      if (!postStream) { return; }
      postStream.set('show_deleted', value);
      return postStream.get('show_deleted') ? true : undefined;
    },
    get() {
      return this.get('postStream.show_deleted') ? true : undefined;
    }
  },

  @computed('model.postStream.summary')
  filter: {
    set(value) {
      const postStream = this.get('model.postStream');
      if (!postStream) { return; }
      postStream.set('summary', value === "summary");
      return postStream.get('summary') ? "summary" : undefined;
    },
    get() {
      return this.get('postStream.summary') ? "summary" : undefined;
    }
  },

  @computed('model.postStream.streamFilters.username_filters')
  username_filters: {
    set(value) {
      const postStream = this.get('model.postStream');
      if (!postStream) { return; }
      postStream.set('streamFilters.username_filters', value);
      return postStream.get('streamFilters.username_filters');
    },
    get() {
      return this.get('postStream.streamFilters.username_filters');
    }
  },

  _clearSelected: function() {
    this.set('selectedPosts', []);
    this.set('selectedReplies', []);
  }.on('init'),

  showCategoryChooser: Ember.computed.not("model.isPrivateMessage"),

  gotoInbox(name) {
    var url = '/users/' + this.get('currentUser.username_lower') + '/messages';
    if (name) {
      url = url + '/group/' + name;
    }
    DiscourseURL.routeTo(url);
  },

  selectedQuery: function() {
    return post => this.postSelected(post);
  }.property(),

  actions: {

    fillGapBefore(args) {
      return this.get('model.postStream').fillGapBefore(args.post, args.gap);
    },

    fillGapAfter(args) {
      return this.get('model.postStream').fillGapAfter(args.post, args.gap);
    },

    // Called the the topmost visible post on the page changes.
    topVisibleChanged(event) {
      const { post, refresh } = event;

      if (!post) { return; }

      const postStream = this.get('model.postStream');
      const firstLoadedPost = postStream.get('posts.firstObject');

      const currentPostNumber = post.get('post_number');
      this.set('model.currentPost', currentPostNumber);
      this.send('postChangedRoute', currentPostNumber);

      if (post.get('post_number') === 1) { return; }

      if (firstLoadedPost && firstLoadedPost === post) {
        postStream.prependMore().then(() => refresh());
      }
    },

    //  Called the the bottommost visible post on the page changes.
    bottomVisibleChanged(event) {
      const { post, refresh } = event;

      const postStream = this.get('model.postStream');
      const lastLoadedPost = postStream.get('posts.lastObject');

      this.set('controllers.topic-progress.progressPosition', postStream.progressIndexOfPost(post));

      if (lastLoadedPost && lastLoadedPost === post && postStream.get('canAppendMore')) {
        postStream.appendMore().then(() => refresh());
        // show loading stuff
        refresh();
      }
    },

    toggleSummary() {
      return this.get('model.postStream').toggleSummary();
    },

    removeAllowedUser(user) {
      return this.get('model.details').removeAllowedUser(user);
    },

    showTopicAdminMenu() {
      this.set('adminMenuVisible', true);
    },

    hideTopicAdminMenu() {
      this.set('adminMenuVisible', false);
    },

    deleteTopic() {
      this.deleteTopic();
    },

    archiveMessage() {
      const topic = this.get('model');
      topic.archiveMessage().then(()=>{
        this.gotoInbox(topic.get("inboxGroupName"));
      });
    },

    moveToInbox() {
      const topic = this.get('model');
      topic.moveToInbox().then(()=>{
        this.gotoInbox(topic.get("inboxGroupName"));
      });
    },

    // Post related methods
    replyToPost(post) {
      const composerController = this.get('controllers.composer'),
          quoteController = this.get('controllers.quote-button'),
          quotedText = Quote.build(quoteController.get('post'), quoteController.get('buffer')),
          topic = post ? post.get('topic') : this.get('model');

      quoteController.set('buffer', '');

      if (composerController.get('content.topic.id') === topic.get('id') &&
          composerController.get('content.action') === Composer.REPLY) {
        composerController.set('content.post', post);
        composerController.set('content.composeState', Composer.OPEN);
        this.appEvents.trigger('composer:insert-text', quotedText.trim());
      } else {

        const opts = {
          action: Composer.REPLY,
          draftKey: topic.get('draft_key'),
          draftSequence: topic.get('draft_sequence')
        };

        if (quotedText) { opts.quote = quotedText; }

        if(post && post.get("post_number") !== 1){
          opts.post = post;
        } else {
          opts.topic = topic;
        }

        composerController.open(opts);
      }
      return false;
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
        return this.deleteTopic();
      } else if (!post.can_delete) {
        // check if current user can delete post
        return false;
      }

      const user = Discourse.User.current(),
          replyCount = post.get('reply_count'),
          self = this;

      // If the user is staff and the post has replies, ask if they want to delete replies too.
      if (user.get('staff') && replyCount > 0) {
        bootbox.dialog(I18n.t("post.controls.delete_replies.confirm", {count: replyCount}), [
          {label: I18n.t("cancel"),
           'class': 'btn-danger right'},
          {label: I18n.t("post.controls.delete_replies.no_value"),
            callback() {
              post.destroy(user);
            }
          },
          {label: I18n.t("post.controls.delete_replies.yes_value"),
           'class': 'btn-primary',
            callback() {
              Discourse.Post.deleteMany([post], [post]);
              self.get('model.postStream.posts').forEach(function (p) {
                if (p === post || p.get('reply_to_post_number') === post.get('post_number')) {
                  p.setDeletedState(user);
                }
              });
            }
          }
        ]);
      } else {
        return post.destroy(user).then(() => {
          this.appEvents.trigger('post-stream:refresh');
        }).catch(error => {
          popupAjaxError(error);
          post.undoDeleteState();
        });
      }
    },

    editPost(post) {
      if (!Discourse.User.current()) {
        return bootbox.alert(I18n.t('post.controls.edit_anonymous'));
      }

      // check if current user can edit post
      if (!post.can_edit) {
        return false;
      }

      const composer = this.get('controllers.composer'),
            composerModel = composer.get('model'),
            opts = {
              post: post,
              action: Composer.EDIT,
              draftKey: post.get('topic.draft_key'),
              draftSequence: post.get('topic.draft_sequence')
            };

      // Cancel and reopen the composer for the first post
      if (composerModel && (post.get('firstPost') || composerModel.get('editingFirstPost'))) {
        composer.cancelComposer().then(() => composer.open(opts));
      } else {
        composer.open(opts);
      }
    },

    toggleBookmark(post) {
      if (!this.currentUser) {
        alert(I18n.t("bookmarks.not_bookmarked"));
        return;
      }
      if (post) {
        return post.toggleBookmark().catch(popupAjaxError);
      } else {
        return this.get("model").toggleBookmark().then(changedIds => {
          if (!changedIds) { return; }
          changedIds.forEach(id => this.appEvents.trigger('post-stream:refresh', { id }));
        });
      }
    },

    jumpTop() {
      this.get('controllers.topic-progress').send('jumpTop');
    },

    selectAll() {
      const posts = this.get('model.postStream.posts');
      const selectedPosts = this.get('selectedPosts');
      if (posts) {
        selectedPosts.addObjects(posts);
      }
      this.set('allPostsSelected', true);
      this.appEvents.trigger('post-stream:refresh', { force: true });
    },

    deselectAll() {
      this.get('selectedPosts').clear();
      this.get('selectedReplies').clear();
      this.set('allPostsSelected', false);
      this.appEvents.trigger('post-stream:refresh', { force: true });
    },

    toggleParticipant(user) {
      this.get('model.postStream').toggleParticipant(Em.get(user, 'username'));
    },

    editTopic() {
      if (!this.get('model.details.can_edit')) return false;

      this.set('editingTopic', true);
      return false;
    },

    cancelEditingTopic() {
      this.set('editingTopic', false);
      this.rollbackBuffer();
    },

    toggleMultiSelect() {
      this.toggleProperty('multiSelect');
      this.appEvents.trigger('post-stream:refresh', { force: true });
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
      }).catch(popupAjaxError);
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
      bootbox.confirm(I18n.t("post.delete.confirm", { count: this.get('selectedPostsCount')}), result => {
        if (result) {

          // If all posts are selected, it's the same thing as deleting the topic
          if (this.get('allPostsSelected')) {
            return this.deleteTopic();
          }

          const selectedPosts = this.get('selectedPosts');
          const selectedReplies = this.get('selectedReplies');
          const postStream = this.get('model.postStream');

          Discourse.Post.deleteMany(selectedPosts, selectedReplies);
          postStream.get('posts').forEach(p => {
            if (this.postSelected(p)) {
              p.set('deleted_at', new Date());
            }
          });

          this.send('toggleMultiSelect');
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
      const value = this.get('model.pinned_at') ? false : true,
            topic = this.get('content'),
            until = this.get('model.pinnedInCategoryUntil');

      // optimistic update
      topic.setProperties({
        pinned_at: value ? moment() : null,
        pinned_globally: false,
        pinned_until: value ? until : null
      });

      return topic.saveStatus("pinned", value, until);
    },

    pinGlobally() {
      const topic = this.get('content'),
            until = this.get('model.pinnedGloballyUntil');

      // optimistic update
      topic.setProperties({
        pinned_at: moment(),
        pinned_globally: true,
        pinned_until: until
      });

      return topic.saveStatus("pinned_globally", true, until);
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
      if (this.get('model.pinned_at')) {
        const topic = this.get('content');
        if (topic.get('pinned')) {
          topic.clearPin();
        } else {
          topic.rePin();
        }
      }
    },

    replyAsNewTopic(post) {
      const composerController = this.get('controllers.composer'),
            quoteController = this.get('controllers.quote-button'),
            quotedText = Quote.build(quoteController.get('post'), quoteController.get('buffer')),
            self = this;

      quoteController.deselectText();

      composerController.open({
        action: Composer.CREATE_TOPIC,
        draftKey: Composer.REPLY_AS_NEW_TOPIC_KEY,
        categoryId: this.get('model.category.id')
      }).then(() => {
        return Em.isEmpty(quotedText) ? "" : quotedText;
      }).then(q => {
        const postUrl = `${location.protocol}//${location.host}${post.get('url')}`;
        const postLink = `[${Handlebars.escapeExpression(self.get('model.title'))}](${postUrl})`;
        composerController.get('model').appendText(`${I18n.t("post.continue_discussion", { postLink })}\n\n${q}`);
      });
    },

    retryLoading() {
      const self = this;
      self.set('retrying', true);
      this.get('model.postStream').refresh().then(function() {
        self.set('retrying', false);
      }, function() {
        self.set('retrying', false);
      });
    },

    toggleWiki(post) {
      return post.updatePostField('wiki', !post.get('wiki'));
    },

    togglePostType(post) {
      const regular = this.site.get('post_types.regular');
      const moderator = this.site.get('post_types.moderator_action');

      return post.updatePostField('post_type', post.get('post_type') === moderator ? regular : moderator);
    },

    rebakePost(post) {
      return post.rebake();
    },

    unhidePost(post) {
      return post.unhide();
    },

    changePostOwner(post) {
      this.get('selectedPosts').addObject(post);
      this.send('changeOwner');
    }
  },

  togglePinnedState() {
    this.send('togglePinnedForUser');
  },

  canMergeTopic: function() {
    if (!this.get('model.details.can_move_posts')) return false;
    return this.get('selectedPostsCount') > 0;
  }.property('selectedPostsCount'),

  canSplitTopic: function() {
    if (!this.get('model.details.can_move_posts')) return false;
    if (this.get('allPostsSelected')) return false;
    return this.get('selectedPostsCount') > 0;
  }.property('selectedPostsCount'),

  canChangeOwner: function() {
    if (!Discourse.User.current() || !Discourse.User.current().admin) return false;
    return this.get('selectedPostsUsername') !== undefined;
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

  hasError: Ember.computed.or('model.notFoundHtml', 'model.message'),
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
    return Discourse.User.current() && !this.get('model.isPrivateMessage');
  }.property('model.isPrivateMessage'),

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

    const refresh = (args) => this.appEvents.trigger('post-stream:refresh', args);

    this.messageBus.subscribe("/topic/" + this.get('model.id'), data => {
      const topic = this.get('model');

      if (data.notification_level_change) {
        topic.set('details.notification_level', data.notification_level_change);
        topic.set('details.notifications_reason_id', data.notifications_reason_id);
        return;
      }

      const postStream = this.get('model.postStream');
      switch (data.type) {
        case "acted":
          postStream.triggerChangedPost(data.id, data.updated_at).then(() => refresh({ id: data.id, refreshLikes: true }));
          break;
        case "revised":
        case "rebaked": {
          postStream.triggerChangedPost(data.id, data.updated_at).then(() => refresh({ id: data.id }));
          break;
        }
        case "deleted": {
          postStream.triggerDeletedPost(data.id, data.post_number).then(() => refresh({ id: data.id }));
          break;
        }
        case "recovered": {
          postStream.triggerRecoveredPost(data.id, data.post_number).then(() => refresh({ id: data.id }));
          break;
        }
        case "created": {
          postStream.triggerNewPostInStream(data.id).then(() => refresh());
          if (this.get('currentUser.id') !== data.user_id) {
            Discourse.notifyBackgroundCountIncrement();
          }
          break;
        }
        case "move_to_inbox": {
          topic.set("message_archived",false);
          break;
        }
        case "archived": {
          topic.set("message_archived",true);
          break;
        }
        default: {
          Em.Logger.warn("unknown topic bus message type", data);
        }
      }

      if (data.reload_topic) {
        topic.reload().then(() => {
          this.send('postChangedRoute', topic.get('post_number') || 1);
        });
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
      this.set('allPostsSelected', selectedPosts.length === this.get('model.posts_count'));
      return true;
    }
  },

  readPosts(topicId, postNumbers) {
    const topic = this.get("model");
    const postStream = topic.get("postStream");

    if (topic.get('id') === topicId) {

      // TODO identity map for postNumber
      postStream.get('posts').forEach(post => {
        if (!post.read && postNumbers.indexOf(post.post_number) !== -1) {
          post.set('read', true);
          this.appEvents.trigger('post-stream:refresh', { id: post.id });
        }
      });

      const max = _.max(postNumbers);
      if (max > topic.get("last_read_post_number")) {
        topic.set("last_read_post_number", max);
      }

      if (this.siteSettings.automatically_unpin_topics &&
          this.currentUser &&
          this.currentUser.automatically_unpin_topics) {
        // automatically unpin topics when the user reaches the bottom
        if (topic.get("pinned") && max >= topic.get("highest_post_number")) {
          Em.run.next(() => topic.clearPin());
        }
      }
    }
  },


  _showFooter: function() {
    const showFooter = this.get("model.postStream.loaded") && this.get("model.postStream.loadedAllPosts");
    this.set("controllers.application.showFooter", showFooter);
  }.observes("model.postStream.{loaded,loadedAllPosts}")

});
