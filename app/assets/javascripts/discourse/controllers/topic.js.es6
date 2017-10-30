import BufferedContent from 'discourse/mixins/buffered-content';
import SelectedPostsCount from 'discourse/mixins/selected-posts-count';
import { spinnerHTML } from 'discourse/helpers/loading-spinner';
import Topic from 'discourse/models/topic';
import Quote from 'discourse/lib/quote';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import computed from 'ember-addons/ember-computed-decorators';
import Composer from 'discourse/models/composer';
import DiscourseURL from 'discourse/lib/url';
import Post from 'discourse/models/post';
import debounce from 'discourse/lib/debounce';
import isElementInViewport from "discourse/lib/is-element-in-viewport";
import QuoteState from 'discourse/lib/quote-state';
import { userPath } from 'discourse/lib/url';

export default Ember.Controller.extend(SelectedPostsCount, BufferedContent, {
  composer: Ember.inject.controller(),
  application: Ember.inject.controller(),
  multiSelect: false,
  allPostsSelected: false,
  editingTopic: false,
  selectedPosts: null,
  selectedReplies: null,
  queryParams: ['filter', 'username_filters'],
  loadedAllPosts: Ember.computed.or('model.postStream.loadedAllPosts', 'model.postStream.loadingLastPost'),
  enteredAt: null,
  enteredIndex: null,
  retrying: false,
  userTriggeredProgress: null,
  _progressIndex: null,
  hasScrolled: null,
  username_filters: null,
  filter: null,
  quoteState: null,

  updateQueryParams() {
    const postStream = this.get('model.postStream');
    this.setProperties(postStream.get('streamFilters'));
  },

  _titleChanged: function() {
    const title = this.get('model.title');
    if (!Ember.isEmpty(title)) {

      // Note normally you don't have to trigger this, but topic titles can be updated
      // and are sometimes lazily loaded.
      this.send('refreshTitle');
    }
  }.observes('model.title', 'category'),

  @computed('site.mobileView', 'model.posts_count')
  showSelectedPostsAtBottom(mobileView, postsCount) {
    return mobileView && (postsCount > 3);
  },

  @computed('model.postStream.posts')
  postsToRender() {
    return this.capabilities.isAndroid ? this.get('model.postStream.posts')
                                       : this.get('model.postStream.postsWithPlaceholders');
  },

  @computed('model.postStream.loadingFilter')
  androidLoading(loading) {
    return this.capabilities.isAndroid && loading;
  },


  @computed('model')
  pmPath(model) {
    return this.currentUser && this.currentUser.pmPath(model);
  },

  init() {
    this._super();
    this.set('selectedPosts', []);
    this.set('selectedReplies', []);
    this.set('quoteState', new QuoteState());
  },

  showCategoryChooser: Ember.computed.not("model.isPrivateMessage"),

  gotoInbox(name) {
    let url = userPath(this.get('currentUser.username_lower') + '/messages');
    if (name) {
      url = url + '/group/' + name;
    }
    DiscourseURL.routeTo(url);
  },

  selectedQuery: function() {
    return post => this.postSelected(post);
  }.property(),

  @computed('model.isPrivateMessage', 'model.category.id')
  canEditTopicFeaturedLink(isPrivateMessage, categoryId) {
    if (!this.siteSettings.topic_featured_link_enabled || isPrivateMessage) { return false; }

    const categoryIds = this.site.get('topic_featured_link_allowed_category_ids');
    return categoryIds === undefined || !categoryIds.length || categoryIds.indexOf(categoryId) !== -1;
  },

  @computed('model.isPrivateMessage')
  canEditTags(isPrivateMessage) {
    return !isPrivateMessage && this.site.get('can_tag_topics');
  },

  actions: {

    showPostFlags(post) {
      return this.send('showFlags', post);
    },

    topicRouteAction(name, model) {
      return this.send(name, model);
    },

    openFeatureTopic() {
      this.send('showFeatureTopic');
    },

    selectText(postId, buffer) {
      return this.get('model.postStream').loadPost(postId).then(post => {
        const composer = this.get('composer');
        const viewOpen = composer.get('model.viewOpen');

        // If we can't create a post, delegate to reply as new topic
        if ((!viewOpen) && (!this.get('model.details.can_create_post'))) {
          this.send('replyAsNewTopic', post);
          return;
        }

        const composerOpts = {
          action: Composer.REPLY,
          draftKey: post.get('topic.draft_key')
        };

        if (post.get('post_number') === 1) {
          composerOpts.topic = post.get("topic");
        } else {
          composerOpts.post = post;
        }

        // If the composer is associated with a different post, we don't change it.
        const composerPost = composer.get('model.post');
        if (composerPost && (composerPost.get('id') !== this.get('post.id'))) {
          composerOpts.post = composerPost;
        }

        const quotedText = Quote.build(post, buffer);
        composerOpts.quote = quotedText;
        if (composer.get('model.viewOpen')) {
          this.appEvents.trigger('composer:insert-block', quotedText);
        } else if (composer.get('model.viewDraft')) {
          const model = composer.get('model');
          model.set('reply', model.get('reply') + quotedText);
          composer.send('openIfDraft');
        } else {
          composer.open(composerOpts);
        }
      });
    },

    fillGapBefore(args) {
      return this.get('model.postStream').fillGapBefore(args.post, args.gap);
    },

    fillGapAfter(args) {
      return this.get('model.postStream').fillGapAfter(args.post, args.gap);
    },

    currentPostChanged(event) {
      const { post } = event;
      if (!post) { return; }

      const postNumber = post.get('post_number');
      const topic = this.get('model');
      topic.set('currentPost', postNumber);
      if (postNumber > (topic.get('last_read_post_number') || 0)) {
        topic.set('last_read_post_id', post.get('id'));
        topic.set('last_read_post_number', postNumber);
      }

      this.send('postChangedRoute', postNumber);
      this._progressIndex = topic.get('postStream').progressIndexOfPost(post);

      this.appEvents.trigger('topic:current-post-changed', { post });
    },

    currentPostScrolled(event) {
      const total = this.get('model.postStream.filteredPostsCount');
      const percent = (parseFloat(this._progressIndex + event.percent - 1) / total);
      this.appEvents.trigger('topic:current-post-scrolled', {
        postIndex: this._progressIndex,
        percent: Math.max(Math.min(percent, 1.0), 0.0)
      });
    },

    // Called the the topmost visible post on the page changes.
    topVisibleChanged(event) {
      const { post, refresh } = event;
      if (!post) { return; }

      const postStream = this.get('model.postStream');
      const firstLoadedPost = postStream.get('posts.firstObject');

      if (post.get('post_number') === 1) { return; }

      if (firstLoadedPost && firstLoadedPost === post) {
        postStream.prependMore().then(() => refresh());
      }
    },

    // Called the the bottommost visible post on the page changes.
    bottomVisibleChanged(event) {
      const { post, refresh } = event;

      const postStream = this.get('model.postStream');
      const lastLoadedPost = postStream.get('posts.lastObject');

      if (lastLoadedPost && lastLoadedPost === post && postStream.get('canAppendMore')) {
        postStream.appendMore().then(() => refresh());
        // show loading stuff
        refresh();
      }
    },

    toggleSummary() {
      return this.get('model.postStream').toggleSummary().then(() => {
        this.updateQueryParams();
      });
    },

    removeAllowedUser(user) {
      return this.get('model.details').removeAllowedUser(user).then(() => {
        if (this.currentUser.id === user.id) {
          this.transitionToRoute("userPrivateMessages", user);
        }
      });
    },

    removeAllowedGroup(group) {
      return this.get('model.details').removeAllowedGroup(group);
    },

    deleteTopic() {
      this.deleteTopic();
    },

    // Archive a PM (as opposed to archiving a topic)
    toggleArchiveMessage() {
      const topic = this.get('model');
      if (topic.get('archiving')) { return; }

      if (topic.get('message_archived')) {
        topic.moveToInbox().then(()=>{
          this.gotoInbox(topic.get("inboxGroupName"));
        });
      } else {
        topic.archiveMessage().then(()=>{
          this.gotoInbox(topic.get("inboxGroupName"));
        });
      }
    },

    // Post related methods
    replyToPost(post) {
      const composerController = this.get('composer');
      const topic = post ? post.get('topic') : this.get('model');

      const quoteState = this.get('quoteState');
      const postStream = this.get('model.postStream');
      if (!postStream) return;
      const quotedPost = postStream.findLoadedPost(quoteState.postId);
      const quotedText = Quote.build(quotedPost, quoteState.buffer);

      quoteState.clear();

      if (composerController.get('content.topic.id') === topic.get('id') &&
          composerController.get('content.action') === Composer.REPLY) {
        composerController.set('content.post', post);
        composerController.set('content.composeState', Composer.OPEN);
        this.appEvents.trigger('composer:insert-block', quotedText.trim());
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

      const composer = this.get('composer'),
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

    jumpToIndex(index) {
      this._jumpToPostId(this.get('model.postStream.stream')[index-1]);
    },

    jumpToPostPrompt() {
      const postText = prompt(I18n.t('topic.progress.jump_prompt_long'));
      if (postText === null) { return; }
      const postNumber = parseInt(postText, 10);
      if (postNumber === 0) { return; }
      this._jumpToPostId(this.get('model.postStream').findPostIdForPostNumber(postNumber));
    },

    jumpToPost(postNumber) {
      const postStream = this.get('model.postStream');
      let postId = postStream.findPostIdForPostNumber(postNumber);

      // If we couldn't find the post, find the closest post to it
      if (!postId) {
        const closest = postStream.closestPostNumberFor(postNumber);
        postId = postStream.findPostIdForPostNumber(closest);
      }
      this._jumpToPostId(postId);
    },

    jumpTop() {
      DiscourseURL.routeTo(this.get('model.firstPostUrl'), { skipIfOnScreen: false });
    },

    jumpBottom() {
      DiscourseURL.routeTo(this.get('model.lastPostUrl'), { skipIfOnScreen: false });
    },

    jumpUnread() {
      this._jumpToPostId(this.get('model.last_read_post_id'));
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
      const postStream = this.get('model.postStream');
      postStream.toggleParticipant(Ember.get(user, 'username')).then(() => {
        this.updateQueryParams();
      });
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
      this.appEvents.trigger('post-stream:refresh', { force: true });
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

    mergePosts() {
      bootbox.confirm(I18n.t("post.merge.confirm", { count: this.get('selectedPostsCount') }), result => {
        if (result) {
          const selectedPosts = this.get('selectedPosts');
          Post.mergePosts(selectedPosts);
          this.send('toggleMultiSelect');
        }
      });
    },

    expandHidden(post) {
      return post.expandHidden();
    },

    toggleVisibility() {
      this.get('content').toggleStatus('visible');
    },

    toggleClosed() {
      const topic = this.get('content');

      this.get('content').toggleStatus('closed').then(result => {
        topic.set('topic_status_update', result.topic_status_update);
      });
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
      const composerController = this.get('composer');

      const { quoteState } = this;
      const quotedText = Quote.build(post, quoteState.buffer);
      quoteState.clear();

      var options;
      if (this.get('model.isPrivateMessage')) {
        let users = this.get('model.details.allowed_users');
        let groups = this.get('model.details.allowed_groups');

        let usernames = [];
        users.forEach(user => usernames.push(user.username));
        groups.forEach(group => usernames.push(group.name));
        usernames = usernames.join();

        options = {
          action: Composer.PRIVATE_MESSAGE,
          archetypeId: 'private_message',
          draftKey: Composer.REPLY_AS_NEW_PRIVATE_MESSAGE_KEY,
          usernames: usernames
        };
      } else {
        options = {
          action: Composer.CREATE_TOPIC,
          draftKey: Composer.REPLY_AS_NEW_TOPIC_KEY,
          categoryId: this.get('model.category.id')
        };
      }

      composerController.open(options).then(() => {
        return Em.isEmpty(quotedText) ? "" : quotedText;
      }).then(q => {
        const postUrl = `${location.protocol}//${location.host}${post.get('url')}`;
        const postLink = `[${Handlebars.escapeExpression(this.get('model.title'))}](${postUrl})`;
        composerController.get('model').prependText(`${I18n.t("post.continue_discussion", { postLink })}\n\n${q}`, {new_line: true});
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
    },

    convertToPublicTopic() {
      this.get('content').convertTopic("public");
    },

    convertToPrivateMessage() {
      this.get('content').convertTopic("private");
    }
  },

  _jumpToPostId(postId) {
    if (!postId) {
      Ember.Logger.warn("jump-post code broken - requested an index outside the stream array");
      return;
    }

    this.appEvents.trigger('topic:jump-to-post', postId);

    const topic = this.get('model');
    const postStream = topic.get('postStream');
    const post = postStream.findLoadedPost(postId);

    if (post) {
      DiscourseURL.routeTo(topic.urlForPostNumber(post.get('post_number')));
    } else {
      // need to load it
      postStream.findPostsByIds([postId]).then(arr => {
        DiscourseURL.routeTo(topic.urlForPostNumber(arr[0].get('post_number')));
      });
    }
  },

  togglePinnedState() {
    this.send('togglePinnedForUser');
  },

  print() {
    if (this.siteSettings.max_prints_per_hour_per_user > 0) {
      window.open(this.get('model.printUrl'), '', 'menubar=no,toolbar=no,resizable=yes,scrollbars=yes,width=600,height=315');
    }
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

  @computed('selectedPosts', 'selectedPostsCount', 'selectedPostsUsername')
  canMergePosts(selectedPosts, selectedPostsCount, selectedPostsUsername) {
    if (selectedPostsCount < 2) return false;
    if (!selectedPosts.every(p => p.get('can_delete'))) return false;
    return selectedPostsUsername !== undefined;
  },

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

    const selectedReply = selectedReplies.findBy('post_number', post.get('reply_to_post_number'));
    if (selectedReply) { selectedReplies.removeObject(selectedReply); }

    this.set('allPostsSelected', false);
  },

  postSelected(post) {
    if (this.get('allPostsSelected')) { return true; }
    if (this.get('selectedPosts').includes(post)) { return true; }
    if (this.get('selectedReplies').findBy('post_number', post.get('reply_to_post_number'))) { return true; }

    return false;
  },

  loadingHTML: function() {
    return spinnerHTML;
  }.property(),

  recoverTopic() {
    this.get('content').recover();
  },

  deleteTopic() {
    this.get('content').destroy(Discourse.User.current());
  },

  // Receive notifications for this topic
  subscribe() {
    // Unsubscribe before subscribing again
    this.unsubscribe();

    const refresh = (args) => this.appEvents.trigger('post-stream:refresh', args);

    this.messageBus.subscribe(`/topic/${this.get('model.id')}`, data => {
      const topic = this.get('model');

      if (Ember.isPresent(data.notification_level_change)) {
        topic.set('details.notification_level', data.notification_level_change);
        topic.set('details.notifications_reason_id', data.notifications_reason_id);
        return;
      }

      const postStream = this.get('model.postStream');

      if (data.reload_topic) {
        topic.reload().then(() => {
          this.send('postChangedRoute', topic.get('post_number') || 1);
          this.appEvents.trigger('header:update-topic', topic);
          if (data.refresh_stream) postStream.refresh();
        });

        return;
      }

      switch (data.type) {
        case "acted":
          postStream.triggerChangedPost(
            data.id,
            data.updated_at,
            { preserveCooked: true }
          ).then(() => refresh({ id: data.id, refreshLikes: true }));
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

      if (topic.get('isPrivateMessage') &&
          this.currentUser &&
          this.currentUser.get('id') !== data.user_id &&
          data.type === 'created') {

        const postNumber = data.post_number;
        const notInPostStream = topic.get('highest_post_number') <= postNumber;
        const postNumberDifference = postNumber - topic.get('currentPost');

        if (notInPostStream &&
          postNumberDifference > 0 &&
          postNumberDifference < 7) {

          this._scrollToPost(data.post_number);
        }
      }
    }, this.get('model.message_bus_last_id'));
  },

  _scrollToPost: debounce(function(postNumber) {
    const $post = $(`.topic-post article#post_${postNumber}`);

    if ($post.length === 0 || isElementInViewport($post)) return;

    $('body').animate({ scrollTop: $post.offset().top }, 1000);
  }, 500),

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
      postStream.get('posts').forEach(post => {
        if (!post.read && postNumbers.indexOf(post.post_number) !== -1) {
          post.set('read', true);
          this.appEvents.trigger('post-stream:refresh', { id: post.get('id') });
        }
      });

      if (this.siteSettings.automatically_unpin_topics &&
          this.currentUser &&
          this.currentUser.automatically_unpin_topics) {

        // automatically unpin topics when the user reaches the bottom
        const max = _.max(postNumbers);
        if (topic.get("pinned") && max >= topic.get("highest_post_number")) {
          Em.run.next(() => topic.clearPin());
        }

      }
    }
  },

  _showFooter: function() {
    const showFooter = this.get("model.postStream.loaded") && this.get("model.postStream.loadedAllPosts");
    this.set("application.showFooter", showFooter);
  }.observes("model.postStream.{loaded,loadedAllPosts}")

});
