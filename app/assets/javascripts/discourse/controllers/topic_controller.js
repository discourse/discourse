/**
  This controller supports all actions related to a topic

  @class TopicController
  @extends Discourse.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.TopicController = Discourse.ObjectController.extend(Discourse.SelectedPostsCount, {
  userFilters: new Em.Set(),
  multiSelect: false,
  bestOf: false,
  summaryCollapsed: true,
  loading: false,
  loadingBelow: false,
  loadingAbove: false,
  needs: ['header', 'modal', 'composer', 'quoteButton'],

  selectedPosts: function() {
    var posts = this.get('content.posts');
    if (!posts) return null;
    return posts.filterProperty('selected');
  }.property('content.posts.@each.selected'),

  canMoveSelected: function() {
    if (!this.get('content.can_move_posts')) return false;
    // For now, we can move it if we can delete it since the posts need to be deleted.
    return this.get('canDeleteSelected');
  }.property('canDeleteSelected'),

  canDeleteSelected: function() {
    var selectedPosts = this.get('selectedPosts');
    if (!(selectedPosts && selectedPosts.length > 0)) return false;

    var canDelete = true;
    selectedPosts.each(function(p) {
      if (!p.get('can_delete')) {
        canDelete = false;
        return false;
      }
    });
    return canDelete;
  }.property('selectedPosts'),

  multiSelectChanged: function() {
    // Deselect all posts when multi select is turned off
    if (!this.get('multiSelect')) {
      var posts = this.get('content.posts');
      if (posts) {
        posts.forEach(function(p) {
          p.set('selected', false);
        });
      }
    }
  }.observes('multiSelect'),

  hideProgress: function() {
    if (!this.get('content.loaded')) return true;
    if (!this.get('currentPost')) return true;
    if (this.get('content.filtered_posts_count') < 2) return true;
    return false;
  }.property('content.loaded', 'currentPost', 'content.filtered_posts_count'),

  selectPost: function(post) {
    post.toggleProperty('selected');
  },

  toggleMultiSelect: function() {
    this.toggleProperty('multiSelect');
  },

  toggleSummary: function() {
    this.toggleProperty('summaryCollapsed');
  },

  moveSelected: function() {
    var modalController = this.get('controllers.modal');
    if (!modalController) return;

    modalController.show(Discourse.MoveSelectedView.create({
      topicController: this,
      topic: this.get('content'),
      selectedPosts: this.get('selectedPosts')
    }));
  },

  deleteSelected: function() {
    var topicController = this;
    return bootbox.confirm(Em.String.i18n("post.delete.confirm", { count: this.get('selectedPostsCount')}), function(result) {
      if (result) {
        var selectedPosts = topicController.get('selectedPosts');
        Discourse.Post.deleteMany(selectedPosts);
        topicController.get('content.posts').removeObjects(selectedPosts);
        topicController.toggleMultiSelect();
      }
    });
  },

  jumpTop: function() {
    Discourse.URL.routeTo(this.get('content.url'));
  },

  jumpBottom: function() {
    Discourse.URL.routeTo(this.get('content.lastPostUrl'));
  },

  cancelFilter: function() {
    this.set('bestOf', false);
    this.get('userFilters').clear();
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

  toggleParticipant: function(user) {
    this.set('bestOf', false);
    var username = Em.get(user, 'username');
    var userFilters = this.get('userFilters');
    if (userFilters.contains(username)) {
      userFilters.remove(username);
    } else {
      userFilters.add(username);
    }
  },

  /**
    Show or hide the bottom bar, depending on our filter options.

    @method updateBottomBar
  **/
  updateBottomBar: function() {

    var postFilters = this.get('postFilters');

    if (postFilters.bestOf) {
      this.set('filterDesc', Em.String.i18n("topic.filters.best_of", {
        n_best_posts: Em.String.i18n("topic.filters.n_best_posts", { count: this.get('filtered_posts_count') }),
        of_n_posts: Em.String.i18n("topic.filters.of_n_posts", { count: this.get('posts_count') })
      }));
    } else if (postFilters.userFilters.length > 0) {
      this.set('filterDesc', Em.String.i18n("topic.filters.user", {
        n_posts: Em.String.i18n("topic.filters.n_posts", { count: this.get('filtered_posts_count') }),
        by_n_users: Em.String.i18n("topic.filters.by_n_users", { count: postFilters.userFilters.length })
      }));
    } else {
      // Hide the bottom bar
      $('#topic-filter').slideUp();
      return;
    }

    $('#topic-filter').slideDown();
  },

  enableBestOf: function(e) {
    this.set('bestOf', true);
    this.get('userFilters').clear();
  },

  postFilters: function() {
    if (this.get('bestOf') === true) return { bestOf: true };
    return { userFilters: this.get('userFilters') };
  }.property('userFilters.[]', 'bestOf'),

  loadPosts: function(opts) {
    var topicController = this;
    this.get('content').loadPosts(opts).then(function () {
      Em.run.next(function () { topicController.updateBottomBar(); });
    });
  },

  reloadPosts: function() {
    var topic = this.get('content');
    if (!topic) return;

    var posts = topic.get('posts');
    if (!posts) return;

    // Leave the first post -- we keep it above the filter controls
    posts.removeAt(1, posts.length - 1);

    this.set('loadingBelow', true);

    var topicController = this;
    var postFilters = this.get('postFilters');
    return Discourse.Topic.find(this.get('id'), postFilters).then(function(result) {
      var first = result.posts.first();
      if (first) {
        topicController.set('currentPost', first.post_number);
      }
      $('#topic-progress .solid').data('progress', false);
      result.posts.each(function(p) {
        // Skip the first post
        if (p.post_number === 1) return;
        posts.pushObject(Discourse.Post.create(p, topic));
      });

      Em.run.next(function () { topicController.updateBottomBar(); });

      topicController.set('filtered_posts_count', result.filtered_posts_count);
      topicController.set('loadingBelow', false);
      topicController.set('seenBottom', false);
    });
  }.observes('postFilters'),

  deleteTopic: function(e) {
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

  startTracking: function() {
    var screenTrack = Discourse.ScreenTrack.create({ topic_id: this.get('content.id') });
    screenTrack.start();
    this.set('content.screenTrack', screenTrack);
  },

  stopTracking: function() {
    var screenTrack = this.get('content.screenTrack');
    if (screenTrack) screenTrack.stop();
    this.set('content.screenTrack', null);
  },

  // Toggle the star on the topic
  toggleStar: function(e) {
    this.get('content').toggleStar();
  },

  /**
    Clears the pin from a topic for the currentUser

    @method clearPin
  **/
  clearPin: function() {
    this.get('content').clearPin();
  },

  // Receive notifications for this topic
  subscribe: function() {
    var bus = Discourse.MessageBus;

    // there is a condition where the view never calls unsubscribe, navigate to a topic from a topic
    bus.unsubscribe('/topic/*');

    var topicController = this;
    bus.subscribe("/topic/" + (this.get('content.id')), function(data) {
      var topic = topicController.get('content');
      if (data.notification_level_change) {
        topic.set('notification_level', data.notification_level_change);
        topic.set('notifications_reason_id', data.notifications_reason_id);
        return;
      }
      var posts = topic.get('posts');
      if (posts.some(function(p) {
        return p.get('post_number') === data.post_number;
      })) {
        return;
      }

      // Robin, TODO when a message comes in we need to figure out if it even goes
      //  in this view ... for now fixed the general case
      topic.set('filtered_posts_count', topic.get('filtered_posts_count') + 1);
      topic.set('highest_post_number', data.post_number);
      topic.set('last_poster', data.user);
      topic.set('last_posted_at', data.created_at);
      Discourse.notifyTitle();
    });
  },

  unsubscribe: function() {
    var topicId = this.get('content.id');
    if (!topicId) return;
    Discourse.MessageBus.unsubscribe("/topic/" + topicId);
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
    if (!Discourse.get('currentUser')) {
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

  showPrivateInviteModal: function() {
    var modal = Discourse.InvitePrivateModalView.create({
      topic: this.get('content')
    });

    var modalController = this.get('controllers.modal');
    if (modalController) {
      modalController.show(modal);
    }
  },

  showInviteModal: function() {
    var modalController = this.get('controllers.modal');
    if (modalController) {
      modalController.show(Discourse.InviteModalView.create({
        topic: this.get('content')
      }));
    }
  },

  // Clicked the flag button
  showFlags: function(post) {
    var modalController = this.get('controllers.modal');
    if (modalController) {
      modalController.show(Discourse.FlagView.create({
        post: post,
        controller: this
      }));
    }
  },

  showHistory: function(post) {
    var modalController = this.get('controllers.modal');
    if (modalController) {
      modalController.show(Discourse.HistoryView.create({
        originalPost: post
      }));
    }
  },

  recoverPost: function(post) {
    post.set('deleted_at', null);
    post.recover();
  },

  deletePost: function(post) {
    // Moderators can delete posts. Regular users can only create a deleted at message.
    if (Discourse.get('currentUser.staff')) {
      post.set('deleted_at', new Date());
    } else {
      post.set('cooked', Discourse.Markdown.cook(Em.String.i18n("post.deleted_by_author")));
      post.set('can_delete', false);
      post.set('version', post.get('version') + 1);
    }
    post.destroy();
  },

  postRendered: function(post) {
    var onPostRendered = this.get('onPostRendered');
    if (onPostRendered) {
      onPostRendered(post);
    }
  }
});


