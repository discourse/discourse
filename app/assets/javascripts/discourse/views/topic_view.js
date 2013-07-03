/**
  This view is for rendering an icon representing the status of a topic

  @class TopicView
  @extends Discourse.View
  @namespace Discourse
  @uses Discourse.Scrolling
  @module Discourse
**/
Discourse.TopicView = Discourse.View.extend(Discourse.Scrolling, {
  templateName: 'topic',
  topicBinding: 'controller.content',
  userFiltersBinding: 'controller.userFilters',
  classNameBindings: ['controller.multiSelect:multi-select', 'topic.archetype', 'topic.category.secure:secure_category'],
  menuVisible: true,
  SHORT_POST: 1200,

  postStream: Em.computed.alias('controller.postStream'),


  updateBar: function() {
    var $topicProgress = $('#topic-progress');
    if (!$topicProgress.length) return;

    var totalWidth = $topicProgress.width();
    var progressWidth = this.get('controller.streamPercentage') * totalWidth;

    $topicProgress.find('.bg')
                  .css("border-right-width", (progressWidth === totalWidth) ? "0px" : "1px")
                  .width(progressWidth);

  }.observes('controller.streamPercentage'),

  updateTitle: function() {
    var title = this.get('topic.title');
    if (title) return Discourse.set('title', title);
  }.observes('topic.loaded', 'topic.title'),

  currentPostChanged: function() {
    var current = this.get('controller.currentPost');

    var topic = this.get('topic');
    if (!(current && topic)) return;

    if (current > (this.get('maxPost') || 0)) {
      this.set('maxPost', current);
    }

    var postUrl = topic.get('url');
    if (current > 1) { postUrl += "/" + current; }
    Discourse.URL.replaceState(postUrl);
  }.observes('controller.currentPost', 'highest_post_number'),

  composeChanged: function() {
    var composerController = Discourse.get('router.composerController');
    composerController.clearState();
    composerController.set('topic', this.get('topic'));
  }.observes('composer'),

  // This view is being removed. Shut down operations
  willDestroyElement: function() {

    this.unbindScrolling();
    $(window).unbind('resize.discourse-on-scroll');

    // Unbind link tracking
    this.$().off('mouseup.discourse-redirect', '.cooked a, a.track-link');

    this.resetExamineDockCache();

    // this happens after route exit, stuff could have trickled in
    this.set('controller.controllers.header.showExtraInfo', false);
  },

  didInsertElement: function(e) {
    this.bindScrolling({debounce: 0});

    var topicView = this;
    $(window).bind('resize.discourse-on-scroll', function() { topicView.updatePosition(); });

    this.$().on('mouseup.discourse-redirect', '.cooked a, a.track-link', function(e) {
      return Discourse.ClickTrack.trackClick(e);
    });

    this.updatePosition();

    // We want to make sure the progress bar is updated after it's rendered
    this.updateBar();
  },

  debounceLoadSuggested: Discourse.debounce(function(){
    if (this.get('isDestroyed') || this.get('isDestroying')) { return; }

    var incoming = this.get('topicTrackingState.newIncoming');
    var suggested = this.get('topic.details.suggested_topics');
    var topicId = this.get('topic.id');

    if(suggested) {

      var existing = _.invoke(suggested, 'get', 'id');

      var lookup = _.chain(incoming)
        .last(5)
        .reverse()
        .union(existing)
        .uniq()
        .without(topicId)
        .first(5)
        .value();

      Discourse.TopicList.loadTopics(lookup, "").then(function(topics){
        suggested.clear();
        suggested.pushObjects(topics);
      });
    }
  }, 1000),

  hasNewSuggested: function(){
    this.debounceLoadSuggested();
  }.observes('topicTrackingState.incomingCount'),

  resetRead: function(e) {
    Discourse.ScreenTrack.instance().reset();
    this.get('controller').unsubscribe();

    var topicView = this;
    this.get('topic').resetRead().then(function() {
      topicView.set('controller.message', Em.String.i18n("topic.read_position_reset"));
      topicView.set('controller.loaded', false);
    });
  },

  gotFocus: function(){
    if (Discourse.get('hasFocus')){
      this.scrolled();
    }
  }.observes("Discourse.hasFocus"),

  getPost: function($post){
    var post, postView;
    postView = Ember.View.views[$post.prop('id')];
    if (postView) {
      return postView.get('post');
    }
    return null;
  },

  // Called for every post seen, returns the post number
  postSeen: function($post) {
    var post = this.getPost($post);

    if (post) {
      var postNumber = post.get('post_number');
      if (postNumber > (this.get('last_read_post_number') || 0)) {
        this.set('last_read_post_number', postNumber);
      }
      if (!post.get('read')) {
        post.set('read', true);
      }
      return post.get('post_number');
    }
  },

  resetExamineDockCache: function() {
    this.set('docAt', false);
  },

  updateDock: function(postView) {
    if (!postView) return;
    var post = postView.get('post');
    if (!post) return;

    this.set('controller.progressPosition', this.get('postStream').indexOf(post) + 1);
  },

  throttledPositionUpdate: Discourse.debounce(function() {
    Discourse.ScreenTrack.instance().scrolled();
    var model = this.get('controller.model');
    if (model && this.get('nextPositionUpdate')) {
      this.set('controller.currentPost', this.get('nextPositionUpdate'));
    }
  },500),

  scrolled: function(){
    this.updatePosition();
  },


  /**
    Process the posts the current user has seen in the topic.

    @private
    @method processSeenPosts
  **/
  processSeenPosts: function() {
    var rows = $('.topic-post.ready');
    if (!rows || rows.length === 0) { return; }

    // if we have no rows
    var info = Discourse.Eyeline.analyze(rows);
    if(!info) { return; }

    // are we scrolling upwards?
    if(info.top === 0 || info.onScreen[0] === 0 || info.bottom === 0) {
      var $body = $('body');
      var $elem = $(rows[0]);
      var distToElement = $body.scrollTop() - $elem.position().top;
      this.get('postStream').prependMore().then(function() {
        Em.run.next(function () {
          $('html, body').scrollTop($elem.position().top + distToElement);
        });
      });
    }

    // are we scrolling down?
    var currentPost;
    if(info.bottom === rows.length-1) {
      currentPost = this.postSeen($(rows[info.bottom]));
      this.get('postStream').appendMore();
    }

    // update dock
    this.updateDock(Ember.View.views[rows[info.bottom].id]);

    // mark everything on screen read
    var topicView = this;
    _.each(info.onScreen,function(item){
      var seen = topicView.postSeen($(rows[item]));
      currentPost = currentPost || seen;
    });

    var currentForPositionUpdate = currentPost;
    if (!currentForPositionUpdate) {
      var postView = this.getPost($(rows[info.bottom]));
      if (postView) { currentForPositionUpdate = postView.get('post_number'); }
    }

    if (currentForPositionUpdate) {
      this.set('nextPositionUpdate', currentPost || currentForPositionUpdate);
      this.throttledPositionUpdate();
    } else {
      console.error("can't update position ");
    }
  },

  /**
    The user has scrolled the window, or it is finished rendering and ready for processing.

    @method updatePosition
  **/
  updatePosition: function() {

    this.processSeenPosts();

    var offset = window.pageYOffset || $('html').scrollTop();
    if (!this.get('docAt')) {
      var title = $('#topic-title');
      if (title && title.length === 1) {
        this.set('docAt', title.offset().top);
      }
    }

    var headerController = this.get('controller.controllers.header'),
        topic = this.get('controller.model');
    if (this.get('docAt')) {
      headerController.set('showExtraInfo', offset >= this.get('docAt') || topic.get('postStream.firstPostNotLoaded'));
    } else {
      headerController.set('showExtraInfo', topic.get('postStream.firstPostNotLoaded'));
    }

    // Dock the counter if necessary
    var $lastPost = $('article[data-post-id=' + topic.get('postStream.lastPostId') + "]");
    var lastPostOffset = $lastPost.offset();
    if (!lastPostOffset) { return; }
    this.set('controller.dockedCounter', (offset >= (lastPostOffset.top + $lastPost.height()) - $(window).height()));
  },

  topicTrackingState: function() {
    return Discourse.TopicTrackingState.current();
  }.property(),

  browseMoreMessage: function() {
    var opts = {
      latestLink: "<a href=\"/\">" + (Em.String.i18n("topic.view_latest_topics")) + "</a>"
    };


    var category = this.get('controller.content.category');
    if (category) {
      opts.catLink = Discourse.Utilities.categoryLink(category);
    } else {
      opts.catLink = "<a href=\"" + Discourse.getURL("/categories") + "\">" + (Em.String.i18n("topic.browse_all_categories")) + "</a>";
    }

    var tracking = this.get('topicTrackingState');

    var unreadTopics = tracking.countUnread();
    var newTopics = tracking.countNew();

    if (newTopics + unreadTopics > 0) {
      var hasBoth = unreadTopics > 0 && newTopics > 0;

      return I18n.messageFormat("topic.read_more_MF", {
        "BOTH": hasBoth,
        "UNREAD": unreadTopics,
        "NEW": newTopics,
        "CATEGORY": category ? true : false,
        latestLink: opts.latestLink,
        catLink: opts.catLink
      });
    }
    else if (category) {
      return Ember.String.i18n("topic.read_more_in_category", opts);
    } else {
      return Ember.String.i18n("topic.read_more", opts);
    }
  }.property('topicTrackingState.messageCount')

});

Discourse.TopicView.reopenClass({

  // Scroll to a given post, if in the DOM. Returns whether it was in the DOM or not.
  jumpToPost: function(topicId, postNumber) {
    Em.run.scheduleOnce('afterRender', function() {

      // Make sure we're looking at the topic we want to scroll to
      if (topicId !== parseInt($('#topic').data('topic-id'), 10)) { return false; }

      var $post = $("#post_" + postNumber);
      if ($post.length) {
        if (postNumber === 1) {
          $('html, body').scrollTop(0);
        } else {
          var header = $('header');
          var title = $('#topic-title');
          var expectedOffset = title.height() - header.find('.contents').height();

          if (expectedOffset < 0) {
            expectedOffset = 0;
          }

          $('html, body').scrollTop($post.offset().top - (header.outerHeight(true) + expectedOffset));

          var $contents = $('.topic-body .contents', $post);
          var originalCol = $contents.css('backgroundColor');
          $contents.css({ backgroundColor: "#ffffcc" }).animate({ backgroundColor: originalCol }, 2500);
        }
      }
    });
  }
});
