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
  updateBar: (function() {
    var $topicProgress, bg, currentWidth, progressWidth, ratio, totalWidth;
    if (!this.get('topic.loaded')) return;
    $topicProgress = $('#topic-progress');
    if (!$topicProgress.length) return;

    // Don't show progress when there is only one post
    if (this.get('topic.highest_post_number') === 1) {
      $topicProgress.hide();
    } else {
      $topicProgress.show();
    }

    ratio = this.get('progressPosition') / this.get('topic.highest_post_number');
    totalWidth = $topicProgress.width();
    progressWidth = ratio * totalWidth;
    bg = $topicProgress.find('.bg');
    bg.stop(true, true);
    currentWidth = bg.width()

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
  }).observes('progressPosition', 'topic.highest_post_number', 'topic.loaded'),

  updateTitle: (function() {
    var title;
    title = this.get('topic.title');
    if (title) return Discourse.set('title', title);
  }).observes('topic.loaded', 'topic.title'),

  newPostsPresent: (function() {
    if (this.get('topic.highest_post_number')) {
      this.updateBar();
      this.examineRead();
    }
  }).observes('topic.highest_post_number'),

  currentPostChanged: (function() {
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
  }).observes('controller.currentPost', 'controller.bestOf', 'topic.highest_post_number'),

  composeChanged: (function() {
    var composerController = Discourse.get('router.composerController');
    composerController.clearState();
    return composerController.set('topic', this.get('topic'));
  }).observes('composer'),

  // This view is being removed. Shut down operations
  willDestroyElement: function() {
    var screenTrack, controller;
    this.unbindScrolling();
    
    controller = this.get('controller');
    controller.unsubscribe();
    controller.set('onPostRendered', null);

    screenTrack = this.get('screenTrack');
    if (screenTrack) {
      screenTrack.stop();
    }

    this.set('screenTrack', null);

    $(window).unbind('scroll.discourse-on-scroll');
    $(document).unbind('touchmove.discourse-on-scroll');
    $(window).unbind('resize.discourse-on-scroll');
    
    this.resetExamineDockCache();
  },

  didInsertElement: function(e) {
    var eyeline, onScroll, screenTrack, controller,
      _this = this;

    onScroll = Discourse.debounce((function() {
      return _this.onScroll();
    }), 10);
    $(window).bind('scroll.discourse-on-scroll', onScroll);
    $(document).bind('touchmove.discourse-on-scroll', onScroll);
    $(window).bind('resize.discourse-on-scroll', onScroll);
    this.bindScrolling();
    controller = this.get('controller'); 
    
    controller.subscribe();
    controller.set('onPostRendered', function(){
      _this.postsRendered.apply(_this);
    });

    // Insert our screen tracker
    screenTrack = Discourse.ScreenTrack.create({ topic_id: this.get('topic.id') });
    screenTrack.start();
    this.set('screenTrack', screenTrack);

    // Track the user's eyeline
    eyeline = new Discourse.Eyeline('.topic-post');
    
    eyeline.on('saw', function(e) { 
      _this.postSeen(e.detail); 
    });
    
    eyeline.on('sawBottom', function(e) { 
      _this.postSeen(e.detail); 
      _this.nextPage(e.detail); 
    });

    eyeline.on('sawTop', function(e) { 
      _this.postSeen(e.detail); 
      _this.prevPage(e.detail); 
    });

    this.set('eyeline', eyeline);
    this.$().on('mouseup.discourse-redirect', '.cooked a, a.track-link', function(e) {
      return Discourse.ClickTrack.trackClick(e);
    });

    this.onScroll();

  },

  // Triggered whenever any posts are rendered, debounced to save over calling 
  postsRendered: Discourse.debounce(function() {

    var $lastPost, $window,
      _this = this;
    $window = $(window);
    $lastPost = $('.row:last');
    // we consider stuff at the end of the list as read, right away (if it is visible)
    if ($window.height() + $window.scrollTop() >= $lastPost.offset().top + $lastPost.height()) {
      this.examineRead();
    } else {
      // last is not in view, so only examine in 2 seconds
      Em.run.later(function() { _this.examineRead(); }, 2000);
    }
  }, 100),

  resetRead: function(e) {
    var _this = this;
    this.get('screenTrack').cancel();
    this.set('screenTrack', null);
    this.get('controller').unsubscribe();
    this.get('topic').resetRead(function() {
      _this.set('controller.message', Em.String.i18n("topic.read_position_reset"));
      _this.set('controller.loaded', false);
    });
  },

  gotFocus: function(){
    if (Discourse.get('hasFocus')){
      this.examineRead();
    }
  }.observes("Discourse.hasFocus"),

  // Called for every post seen
  postSeen: function($post) {
    var post, postView, _ref;
    this.set('postNumberSeen', null);
    postView = Ember.View.views[$post.prop('id')];
    if (postView) {
      post = postView.get('post');
      this.set('postNumberSeen', post.get('post_number'));
      if (post.get('post_number') > (this.get('topic.last_read_post_number') || 0)) {
        this.set('topic.last_read_post_number', post.get('post_number'));
      }
      if (!post.get('read')) {
        post.set('read', true);
        _ref = this.get('screenTrack');
        if (_ref) { _ref.guessedSeen(post.get('post_number')); }
      }
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
    var opts, post, postView,
      _this = this;
    postView = Ember.View.views[$post.prop('id')];
    if (!postView) return;
    post = postView.get('post');
    if (!post) return;

    // We don't load upwards from the first page
    if (post.post_number === 1) return;

    // double check
    if (this.topic && this.topic.posts && this.topic.posts.length > 0 && this.topic.posts.first().post_number !== post.post_number) return;

    // half mutex
    if (this.loading) return;
    this.set('loading', true);
    this.set('loadingAbove', true);
    opts = $.extend({
      postsBefore: post.get('post_number')
    }, this.get('controller.postFilters'));

    return Discourse.Topic.find(this.get('topic.id'), opts).then(function(result) {
      var lastPostNum, posts;
      posts = _this.get('topic.posts');

      // Add a scrollTo record to the last post inserted to the DOM
      lastPostNum = result.posts.first().post_number;
      result.posts.each(function(p) {
        var newPost;
        newPost = Discourse.Post.create(p, _this.get('topic'));
        if (p.post_number === lastPostNum) {
          newPost.set('scrollTo', {
            top: $(window).scrollTop(),
            height: $(document).height()
          });
        }
        return posts.unshiftObject(newPost);
      });
      _this.set('loading', false);
      return _this.set('loadingAbove', false);
    });
  },

  fullyLoaded: (function() {
    return this.seenBottom || this.topic.at_bottom;
  }).property('topic.at_bottom', 'seenBottom'),

  // Load new posts if there are some
  nextPage: function($post) {
    var post, postView;
    if (this.loading || this.seenBottom) return;
    postView = Ember.View.views[$post.prop('id')];
    if (!postView) return;
    post = postView.get('post');
    return this.loadMore(post);
  },

  postCountChanged: (function() {
    this.set('seenBottom', false);
  }).observes('topic.highest_post_number'),

  loadMore: function(post) {
    var opts, postNumberSeen, _ref,
      _this = this;
    if (this.loading || this.seenBottom) return;

    // Don't load if we know we're at the bottom
    if (this.get('topic.highest_post_number') === post.get('post_number')) {
      if (_ref = this.get('eyeline')) {
        _ref.flushRest();
      }

      // Update our current post to the last number we saw
      if (postNumberSeen = this.get('postNumberSeen')) {
        this.set('controller.currentPost', postNumberSeen);
      }
      return;
    }

    // Don't double load ever
    if (this.topic.posts.last().post_number !== post.post_number) return;
    this.set('loadingBelow', true);
    this.set('loading', true);
    opts = $.extend({ postsAfter: post.get('post_number') }, this.get('controller.postFilters'));
    return Discourse.Topic.find(this.get('topic.id'), opts).then(function(result) {
      var suggested;
      if (result.at_bottom || result.posts.length === 0) {
        _this.set('seenBottom', 'true');
      }
      _this.get('topic').pushPosts(result.posts.map(function(p) {
        return Discourse.Post.create(p, _this.get('topic'));
      }));
      if (result.suggested_topics) {
        suggested = Em.A();
        result.suggested_topics.each(function(st) {
          return suggested.pushObject(Discourse.Topic.create(st));
        });
        _this.set('topic.suggested_topics', suggested);
      }
      _this.set('loadingBelow', false);
      return _this.set('loading', false);
    });
  },

  // Examine which posts are on the screen and mark them as read. Also figure out if we
  // need to load more posts.
  examineRead: function() {
    // Track posts time on screen
    var postNumberSeen, _ref, _ref1;
    if (_ref = this.get('screenTrack')) {
      _ref.scrolled();
    }

    // Update what we can see
    if (_ref1 = this.get('eyeline')) {
      _ref1.update();
    }

    // Update our current post to the last number we saw
    if (postNumberSeen = this.get('postNumberSeen')) {
      this.set('controller.currentPost', postNumberSeen);
    }
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
      topic.save();
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

  detectDockPosition: function() {
    var current, goingUp, i, increment, offset, post, postView, rows, winHeight, winOffset;
    rows = $(".topic-post");
    if (rows.length === 0) return;
    i = parseInt(rows.length / 2, 10);
    increment = parseInt(rows.length / 4, 10);
    goingUp = undefined;
    winOffset = window.pageYOffset || $('html').scrollTop();
    winHeight = window.innerHeight || $(window).height();
    while (true) {
      if (i === 0 || (i >= rows.length - 1)) {
        break;
      }
      current = $(rows[i]);
      offset = current.offset();
      if (offset.top - winHeight < winOffset) {
        if (offset.top + current.outerHeight() - window.innerHeight > winOffset) {
          break;
        } else {
          i = i + increment;
          if (goingUp !== undefined && increment === 1 && !goingUp) {
            break;
          }
          goingUp = true;
        }
      } else {
        i = i - increment;
        if (goingUp !== undefined && increment === 1 && goingUp) {
          break;
        }
        goingUp = false;
      }
      if (increment > 1) {
        increment = parseInt(increment / 2, 10);
        goingUp = undefined;
      }
      if (increment === 0) {
        increment = 1;
        goingUp = undefined;
      }
    }
    postView = Ember.View.views[rows[i].id];
    if (!postView) return;
    post = postView.get('post');
    if (!post) return;
    this.set('progressPosition', post.get('post_number'));
  },

  ensureDockIsTestedOnChange: (function() {
    // this is subtle, firstPostLoaded will trigger ember to render the view containing #topic-title
    //  onScroll needs do know about it to be able to make a decision about the dock
    Em.run.next(this, this.onScroll);
  }).observes('firstPostLoaded'),

  onScroll: function() {
    var $lastPost, firstLoaded, lastPostOffset, offset, title;
    this.detectDockPosition();
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
      popularLink: "<a href=\"/\">" + (Em.String.i18n("topic.view_popular_topics")) + "</a>"
    };
    if (category = this.get('controller.content.category')) {
      opts.catLink = Discourse.Utilities.categoryLink(category);
      return Ember.String.i18n("topic.read_more_in_category", opts);
    } else {
      opts.catLink = "<a href=\"" + Discourse.getURL("/categories") + "\">" + (Em.String.i18n("topic.browse_all_categories")) + "</a>";
      return Ember.String.i18n("topic.read_more", opts);
    }
  }).property(),

  // The window has been scrolled
  scrolled: function(e) {
    return this.examineRead();
  }
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
