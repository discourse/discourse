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
  classNameBindings: ['controller.multiSelect:multi-select', 'topic.archetype'],
  siteBinding: 'Discourse.site',
  progressPosition: 1,
  menuVisible: true,
  SHORT_POST: 1200,

  // Update the progress bar using sweet animations
  updateBar: function() {
    var $topicProgress, bg, currentWidth, progressWidth, ratio, totalWidth;
    if (!this.get('topic.loaded')) return;
    $topicProgress = $('#topic-progress');
    if (!$topicProgress.length) return;

    ratio = this.get('progressPosition') / this.get('topic.filtered_posts_count');
    totalWidth = $topicProgress.width();
    progressWidth = ratio * totalWidth;
    bg = $topicProgress.find('.bg');
    bg.stop(true, true);
    currentWidth = bg.width();

    if (currentWidth === totalWidth) {
      bg.width(currentWidth - 1);
    }

    if (progressWidth === totalWidth) {
      bg.css("border-right-width", "0px");
    } else {
      bg.css("border-right-width", "1px");
    }

    if (currentWidth === 0) {
      bg.width(progressWidth);
    } else {
      bg.animate({ width: progressWidth }, 400);
    }
  }.observes('progressPosition', 'topic.filtered_posts_count', 'topic.loaded'),

  updateTitle: function() {
    var title;
    title = this.get('topic.title');
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
    if (current > 1) {
      postUrl += "/" + current;
    } else {
      if (this.get('controller.bestOf')) {
        postUrl += "/best_of";
      }
    }
    Discourse.URL.replaceState(postUrl);

    // Show appropriate jump tools
    if (current === 1) {
      $('#jump-top').attr('disabled', true);
    } else {
      $('#jump-top').attr('disabled', false);
    }

    if (current === this.get('topic.highest_post_number')) {
      $('#jump-bottom').attr('disabled', true);
    } else {
      $('#jump-bottom').attr('disabled', false);
    }
  }.observes('controller.currentPost', 'controller.bestOf', 'topic.highest_post_number'),

  composeChanged: function() {
    var composerController = Discourse.get('router.composerController');
    composerController.clearState();
    composerController.set('topic', this.get('topic'));
  }.observes('composer'),

  // This view is being removed. Shut down operations
  willDestroyElement: function() {
    var screenTrack, controller;
    this.unbindScrolling();
    $(window).unbind('resize.discourse-on-scroll');

    controller = this.get('controller');
    controller.unsubscribe();
    controller.set('onPostRendered', null);

    screenTrack = this.get('screenTrack');
    if (screenTrack) {
      screenTrack.stop();
    }

    this.set('screenTrack', null);
    this.resetExamineDockCache();

    // this happens after route exit, stuff could have trickled in
    this.set('controller.controllers.header.showExtraInfo', false)
  },

  didInsertElement: function(e) {
    var topicView = this;
    this.bindScrolling({debounce: 0});
    $(window).bind('resize.discourse-on-scroll', function() { topicView.updatePosition(false); });

    var controller = this.get('controller');
    controller.subscribe();
    controller.set('onPostRendered', function(){
      topicView.postsRendered.apply(topicView);
    });

    // Insert our screen tracker
    var screenTrack = Discourse.ScreenTrack.create({ topic_id: this.get('topic.id') });
    screenTrack.start();
    this.set('screenTrack', screenTrack);

    this.$().on('mouseup.discourse-redirect', '.cooked a, a.track-link', function(e) {
      return Discourse.ClickTrack.trackClick(e);
    });

    this.updatePosition(true);
  },

  // Triggered whenever any posts are rendered, debounced to save over calling
  postsRendered: Discourse.debounce(function() {
    this.set('renderedPosts', $('.topic-post'));
    this.updatePosition(false);
  }, 50),

  resetRead: function(e) {
    this.get('screenTrack').cancel();
    this.set('screenTrack', null);
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
    var post, postNumber, screenTrack;
    post = this.getPost($post);

    if (post) {
      postNumber = post.get('post_number');
      if (postNumber > (this.get('topic.last_read_post_number') || 0)) {
        this.set('topic.last_read_post_number', postNumber);
      }
      if (!post.get('read')) {
        post.set('read', true);
      }
      return post.get('post_number');
    }
  },

  observeFirstPostLoaded: (function() {
    var loaded, old, posts;
    posts = this.get('topic.posts');
    // TODO topic.posts stores non ember objects in it for a period of time, this is bad
    loaded = posts && posts[0] && posts[0].post_number === 1;

    // I avoided a computed property cause I did not want to set it, over and over again
    old = this.get('firstPostLoaded');
    if (loaded) {
      if (old !== true) {
        this.set('firstPostLoaded', true);
      }
    } else {
      if (old !== false) {
        this.set('firstPostLoaded', false);
      }
    }
  }).observes('topic.posts.@each'),

  // Load previous posts if there are some
  prevPage: function($post) {
    var postView = Ember.View.views[$post.prop('id')];
    if (!postView) return;

    var post = postView.get('post');
    if (!post) return;

    // We don't load upwards from the first page
    if (post.post_number === 1) return;

    // double check
    if (this.topic && this.topic.posts && this.topic.posts.length > 0 && this.topic.posts.first().post_number !== post.post_number) return;

    // half mutex
    if (this.get('controller.loading')) return;
    this.set('controller.loading', true);
    this.set('controller.loadingAbove', true);
    var opts = $.extend({ postsBefore: post.get('post_number') }, this.get('controller.postFilters'));

    var topicView = this;
    return Discourse.Topic.find(this.get('topic.id'), opts).then(function(result) {
      var lastPostNum, posts;
      posts = topicView.get('topic.posts');

      // Add a scrollTo record to the last post inserted to the DOM
      lastPostNum = result.posts.first().post_number;
      result.posts.each(function(p) {
        var newPost;
        newPost = Discourse.Post.create(p, topicView.get('topic'));
        if (p.post_number === lastPostNum) {
          newPost.set('scrollTo', {
            top: $(window).scrollTop(),
            height: $(document).height()
          });
        }
        return posts.unshiftObject(newPost);
      });
      topicView.set('controller.loading', false);
      return topicView.set('controller.loadingAbove', false);
    });
  },

  fullyLoaded: (function() {
    return this.get('controller.seenBottom') || this.get('topic.at_bottom');
  }).property('topic.at_bottom', 'controller.seenBottom'),

  // Load new posts if there are some
  nextPage: function($post) {
    if (this.get('controller.loading') || this.get('controller.seenBottom')) return;
    return this.loadMore(this.getPost($post));
  },

  postCountChanged: function() {
    this.set('controller.seenBottom', false);
  }.observes('topic.highest_post_number'),

  loadMore: function(post) {
    if (!post) return;
    if (this.get('controller.loading')) return;

    // Don't load if we know we're at the bottom
    if (this.get('topic.highest_post_number') === post.get('post_number')) return;

    if (this.get('controller.seenBottom')) return;

    // Don't double load ever
    if (this.topic.posts.last().post_number !== post.post_number) return;
    this.set('controller.loadingBelow', true);
    this.set('controller.loading', true);
    var opts = $.extend({ postsAfter: post.get('post_number') }, this.get('controller.postFilters'));

    var topicView = this;
    var topic = this.get('controller.content');
    return Discourse.Topic.find(topic.get('id'), opts).then(function(result) {
      if (result.at_bottom || result.posts.length === 0) {
        topicView.set('controller.seenBottom', 'true');
      }
      topic.pushPosts(result.posts.map(function(p) {
        return Discourse.Post.create(p, topic);
      }));
      if (result.suggested_topics) {
        var suggested = Em.A();
        result.suggested_topics.each(function(st) {
          suggested.pushObject(Discourse.Topic.create(st));
        });
        topicView.set('topic.suggested_topics', suggested);
      }
      topicView.set('controller.loadingBelow', false);
      return topicView.set('controller.loading', false);
    });
  },

  cancelEdit: function() {
    // close editing mode
    this.set('editingTopic', false);
  },

  finishedEdit: function() {
    if (this.get('editingTopic')) {
      var topic = this.get('topic');
      // retrieve the title from the text field
      var newTitle = $('#edit-title').val();
      // retrieve the category from the combox box
      var newCategoryName = $('#topic-title select option:selected').val();
      // manually update the titles & category
      topic.setProperties({
        title: newTitle,
        fancy_title: newTitle,
        categoryName: newCategoryName
      });
      // save the modifications
      topic.save().then(function(result){
        // update the title if it has been changed (cleaned up) server-side
        var title = result.basic_topic.fancy_title;
        topic.setProperties({
          title: title,
          fancy_title: title
        });
      });
      // close editing mode
      this.set('editingTopic', false);
    }
  },

  editTopic: function() {
    if (!this.get('topic.can_edit')) return false;
    // enable editing mode
    this.set('editingTopic', true);
    return false;
  },

  showFavoriteButton: (function() {
    return Discourse.currentUser && !this.get('topic.isPrivateMessage');
  }).property('topic.isPrivateMessage'),

  resetExamineDockCache: function() {
    this.docAt = null;
    this.dockedTitle = false;
    this.dockedCounter = false;
  },

  updateDock: function(postView) {
    if (!postView) return;
    var post = postView.get('post');
    if (!post) return;
    this.set('progressPosition', post.get('index'));
  },

  nonUrgentPositionUpdate: Discourse.debounce(function(opts){
    var screenTrack = this.get('screenTrack');
    if(opts.userActive && screenTrack) {
      screenTrack.scrolled();
    }
    this.set('controller.currentPost', opts.currentPost);
  },500),

  scrolled: function(){
    this.updatePosition(true);
  },

  updatePosition: function(userActive) {
    var $lastPost, firstLoaded, lastPostOffset, offset,
        title, info, rows, screenTrack, _this, currentPost;

    _this = this;
    rows = this.get('renderedPosts');

    if (!rows || rows.length === 0) { return; }
    info = Discourse.Eyeline.analyze(rows);

    // if we have no rows
    if(!info) { return; }

    // top on screen
    if(info.top === 0 || info.onScreen[0] === 0 || info.bottom === 0) {
      this.prevPage($(rows[0]));
    }

    // bottom of screen
    if(info.bottom === rows.length-1) {
      currentPost = _this.postSeen($(rows[info.bottom]));
      this.nextPage($(rows[info.bottom]));
    }

    // update dock
    this.updateDock(Ember.View.views[rows[info.bottom].id]);

    // mark everything on screen read
    $.each(info.onScreen,function(){
      var seen = _this.postSeen($(rows[this]));
      currentPost = currentPost || seen;
    });

    this.nonUrgentPositionUpdate({
        userActive: userActive,
        currentPost: currentPost || this.getPost($(rows[info.bottom])).get('post_number')
    });

    offset = window.pageYOffset || $('html').scrollTop();
    firstLoaded = this.get('firstPostLoaded');
    if (!this.docAt) {
      title = $('#topic-title');
      if (title && title.length === 1) {
        this.docAt = title.offset().top;
      }
    }

    var headerController = this.get('controller.controllers.header');
    if (this.docAt) {
      headerController.set('showExtraInfo', offset >= this.docAt || !firstLoaded);
    } else {
      headerController.set('showExtraInfo', !firstLoaded);
    }

    // there is a whole bunch of caching we could add here
    $lastPost = $('.last-post');
    lastPostOffset = $lastPost.offset();
    if (!lastPostOffset) return;

    if (offset >= (lastPostOffset.top + $lastPost.height()) - $(window).height()) {
      if (!this.dockedCounter) {
        $('#topic-progress-wrapper').addClass('docked');
        this.dockedCounter = true;
      }
    } else {
      if (this.dockedCounter) {
        $('#topic-progress-wrapper').removeClass('docked');
        this.dockedCounter = false;
      }
    }
  },

  browseMoreMessage: (function() {
    var category, opts;

    opts = {
      latestLink: "<a href=\"/\">" + (Em.String.i18n("topic.view_latest_topics")) + "</a>"
    };
    if (category = this.get('controller.content.category')) {
      opts.catLink = Discourse.Utilities.categoryLink(category);
      return Ember.String.i18n("topic.read_more_in_category", opts);
    } else {
      opts.catLink = "<a href=\"" + Discourse.getURL("/categories") + "\">" + (Em.String.i18n("topic.browse_all_categories")) + "</a>";
      return Ember.String.i18n("topic.read_more", opts);
    }
  }).property()

});

Discourse.TopicView.reopenClass({

  // Scroll to a given post, if in the DOM. Returns whether it was in the DOM or not.
  scrollTo: function(topicId, postNumber, callback) {
    // Make sure we're looking at the topic we want to scroll to
    var existing, header, title, expectedOffset;
    if (parseInt(topicId, 10) !== parseInt($('#topic').data('topic-id'), 10)) return false;
    existing = $("#post_" + postNumber);
    if (existing.length) {
      if (postNumber === 1) {
        $('html, body').scrollTop(0);
      } else {
        header = $('header');
        title = $('#topic-title');
        expectedOffset = title.height() - header.find('.contents').height();

        if (expectedOffset < 0) {
            expectedOffset = 0;
        }

        $('html, body').scrollTop(existing.offset().top - (header.outerHeight(true) + expectedOffset));
      }
      return true;
    }
    return false;
  }
});
