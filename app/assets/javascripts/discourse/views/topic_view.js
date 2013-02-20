(function() {

  window.Discourse.TopicView = Ember.View.extend(Discourse.Scrolling, {
    templateName: 'topic',
    topicBinding: 'controller.content',
    userFiltersBinding: 'controller.userFilters',
    classNameBindings: ['controller.multiSelect:multi-select', 'topic.archetype'],
    siteBinding: 'Discourse.site',
    categoriesBinding: 'site.categories',
    progressPosition: 1,
    menuVisible: true,
    SHORT_POST: 1200,
    /* Update the progress bar using sweet animations
    */

    updateBar: (function() {
      var $topicProgress, bg, currentWidth, progressWidth, ratio, totalWidth;
      if (!this.get('topic.loaded')) {
        return;
      }
      $topicProgress = jQuery('#topic-progress');
      if (!$topicProgress.length) {
        return;
      }
      /* Don't show progress when there is only one post
      */

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
        return bg.width(progressWidth);
      } else {
        return bg.animate({
          width: progressWidth
        }, 400);
      }
    }).observes('progressPosition', 'topic.highest_post_number', 'topic.loaded'),
    updateTitle: (function() {
      var title;
      title = this.get('topic.title');
      if (title) {
        return Discourse.set('title', title);
      }
    }).observes('topic.loaded', 'topic.title'),
    newPostsPresent: (function() {
      if (this.get('topic.highest_post_number')) {
        this.updateBar();
        return this.examineRead();
      }
    }).observes('topic.highest_post_number'),
    currentPostChanged: (function() {
      var current, postUrl, topic;
      current = this.get('controller.currentPost');
      topic = this.get('topic');
      if (!(current && topic)) {
        return;
      }
      if (current > (this.get('maxPost') || 0)) {
        this.set('maxPost', current);
      }
      postUrl = topic.get('url');
      if (current > 1) {
        postUrl += "/" + current;
      } else {
        if (this.get('controller.bestOf')) {
          postUrl += "/best_of";
        }
      }
      Discourse.replaceState(postUrl);
      /* Show appropriate jump tools
      */

      if (current === 1) {
        jQuery('#jump-top').attr('disabled', true);
      } else {
        jQuery('#jump-top').attr('disabled', false);
      }
      if (current === this.get('topic.highest_post_number')) {
        return jQuery('#jump-bottom').attr('disabled', true);
      } else {
        return jQuery('#jump-bottom').attr('disabled', false);
      }
    }).observes('controller.currentPost', 'controller.bestOf', 'topic.highest_post_number'),
    composeChanged: (function() {
      var composerController;
      composerController = Discourse.get('router.composerController');
      composerController.clearState();
      return composerController.set('topic', this.get('topic'));
    }).observes('composer'),
    /* This view is being removed. Shut down operations
    */

    willDestroyElement: function() {
      var _ref;
      this.unbindScrolling();
      this.get('controller').unsubscribe();
      if (_ref = this.get('screenTrack')) {
        _ref.stop();
      }
      this.set('screenTrack', null);
      jQuery(window).unbind('scroll.discourse-on-scroll');
      jQuery(document).unbind('touchmove.discourse-on-scroll');
      jQuery(window).unbind('resize.discourse-on-scroll');
      return this.resetExamineDockCache();
    },
    didInsertElement: function(e) {
      var eyeline, onScroll, screenTrack,
        _this = this;
      onScroll = Discourse.debounce((function() {
        return _this.onScroll();
      }), 10);
      jQuery(window).bind('scroll.discourse-on-scroll', onScroll);
      jQuery(document).bind('touchmove.discourse-on-scroll', onScroll);
      jQuery(window).bind('resize.discourse-on-scroll', onScroll);
      this.bindScrolling();
      this.get('controller').subscribe();
      // Insert our screen tracker
      screenTrack = Discourse.ScreenTrack.create({
        topic_id: this.get('topic.id')
      });
      screenTrack.start();
      this.set('screenTrack', screenTrack);
      // Track the user's eyeline
      eyeline = new Discourse.Eyeline('.topic-post');
      eyeline.on('saw', function(e) {
        return _this.postSeen(e.detail);
      });
      eyeline.on('sawBottom', function(e) {
        return _this.nextPage(e.detail);
      });
      eyeline.on('sawTop', function(e) {
        return _this.prevPage(e.detail);
      });
      this.set('eyeline', eyeline);
      this.$().on('mouseup.discourse-redirect', '.cooked a, a.track-link', function(e) {
        return Discourse.ClickTrack.trackClick(e);
      });
      return this.onScroll();
    },

    // Triggered from the post view all posts are rendered
    postsRendered: function(postDiv, post) {
      var $lastPost, $window,
        _this = this;
      $window = jQuery(window);
      $lastPost = jQuery('.row:last');
      // we consider stuff at the end of the list as read, right away (if it is visible)
      if ($window.height() + $window.scrollTop() >= $lastPost.offset().top + $lastPost.height()) {
        return this.examineRead();
      } else {
        // last is not in view, so only examine in 2 seconds
        return Em.run.later(function() {
          return _this.examineRead();
        }, 2000);
      }
    },
    resetRead: function(e) {
      var _this = this;
      this.get('screenTrack').cancel();
      this.set('screenTrack', null);
      this.get('controller').unsubscribe();
      return this.get('topic').resetRead(function() {
        _this.set('controller.message', "Your read position has been reset.");
        return _this.set('controller.loaded', false);
      });
    },

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
          return (_ref = this.get('screenTrack')) ? _ref.guessedSeen(post.get('post_number')) : void 0;
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
          return this.set('firstPostLoaded', true);
        }
      } else {
        if (old !== false) {
          return this.set('firstPostLoaded', false);
        }
      }
    }).observes('topic.posts.@each'),

    // Load previous posts if there are some
    prevPage: function($post) {
      var opts, post, postView,
        _this = this;
      postView = Ember.View.views[$post.prop('id')];
      if (!postView) {
        return;
      }
      post = postView.get('post');
      if (!post) {
        return;
      }
      /* We don't load upwards from the first page
      */

      if (post.post_number === 1) {
        return;
      }
      /* double check
      */

      if (this.topic && this.topic.posts && this.topic.posts.length > 0 && this.topic.posts.first().post_number !== post.post_number) {
        return;
      }
      /* half mutex
      */

      if (this.loading) {
        return;
      }
      this.set('loading', true);
      this.set('loadingAbove', true);
      opts = jQuery.extend({
        postsBefore: post.get('post_number')
      }, this.get('controller.postFilters'));
      return Discourse.Topic.find(this.get('topic.id'), opts).then(function(result) {
        var lastPostNum, posts;
        posts = _this.get('topic.posts');
        /* Add a scrollTo record to the last post inserted to the DOM
        */

        lastPostNum = result.posts.first().post_number;
        result.posts.each(function(p) {
          var newPost;
          newPost = Discourse.Post.create(p, _this.get('topic'));
          if (p.post_number === lastPostNum) {
            newPost.set('scrollTo', {
              top: jQuery(window).scrollTop(),
              height: jQuery(document).height()
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
    /* Load new posts if there are some
    */

    nextPage: function($post) {
      var post, postView;
      if (this.loading || this.seenBottom) {
        return;
      }
      postView = Ember.View.views[$post.prop('id')];
      if (!postView) {
        return;
      }
      post = postView.get('post');
      return this.loadMore(post);
    },
    
    postCountChanged: (function() {
      this.set('seenBottom', false);
      var eyeline = this.get('eyeline');
      if (eyeline)
        eyeline.update()
    }).observes('topic.highest_post_number'),

    loadMore: function(post) {
      var opts, postNumberSeen, _ref,
        _this = this;
      if (this.loading || this.seenBottom) {
        return;
      }
      /* Don't load if we know we're at the bottom
      */

      if (this.get('topic.highest_post_number') === post.get('post_number')) {
        if (_ref = this.get('eyeline')) {
          _ref.flushRest();
        }
        /* Update our current post to the last number we saw
        */

        if (postNumberSeen = this.get('postNumberSeen')) {
          this.set('controller.currentPost', postNumberSeen);
        }
        return;
      }
      /* Don't double load ever
      */

      if (this.topic.posts.last().post_number !== post.post_number) {
        return;
      }
      this.set('loadingBelow', true);
      this.set('loading', true);
      opts = jQuery.extend({
        postsAfter: post.get('post_number')
      }, this.get('controller.postFilters'));
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
    /* Examine which posts are on the screen and mark them as read. Also figure out if we
    */

    /* need to load more posts.
    */

    examineRead: function() {
      /* Track posts time on screen
      */

      var postNumberSeen, _ref, _ref1;
      if (_ref = this.get('screenTrack')) {
        _ref.scrolled();
      }
      /* Update what we can see
      */

      if (_ref1 = this.get('eyeline')) {
        _ref1.update();
      }
      /* Update our current post to the last number we saw
      */

      if (postNumberSeen = this.get('postNumberSeen')) {
        return this.set('controller.currentPost', postNumberSeen);
      }
    },
    cancelEdit: function() {
      return this.set('editingTopic', false);
    },
    finishedEdit: function() {
      var new_val, topic;
      if (this.get('editingTopic')) {
        topic = this.get('topic');
        new_val = jQuery('#edit-title').val();
        topic.set('title', new_val);
        topic.set('fancy_title', new_val);
        topic.save();
        return this.set('editingTopic', false);
      }
    },
    editTopic: function() {
      if (!this.get('topic.can_edit')) {
        return false;
      }
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
      rows = jQuery(".topic-post");
      if (rows.length === 0) {
        return;
      }
      i = parseInt(rows.length / 2, 10);
      increment = parseInt(rows.length / 4, 10);
      goingUp = undefined;
      winOffset = window.pageYOffset || jQuery('html').scrollTop();
      winHeight = window.innerHeight || jQuery(window).height();
      while (true) {
        if (i === 0 || (i >= rows.length - 1)) {
          break;
        }
        current = jQuery(rows[i]);
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
      if (!postView) {
        return;
      }
      post = postView.get('post');
      if (!post) {
        return;
      }
      this.set('progressPosition', post.get('post_number'));
    },
    ensureDockIsTestedOnChange: (function() {
      // this is subtle, firstPostLoaded will trigger ember to render the view containing #topic-title
      //  onScroll needs do know about it to be able to make a decision about the dock
      return Em.run.next(this, this.onScroll);
    }).observes('firstPostLoaded'),
    onScroll: function() {
      var $lastPost, firstLoaded, lastPostOffset, offset, title;
      this.detectDockPosition();
      offset = window.pageYOffset || jQuery('html').scrollTop();
      firstLoaded = this.get('firstPostLoaded');
      if (!this.docAt) {
        title = jQuery('#topic-title');
        if (title && title.length === 1) {
          this.docAt = title.offset().top;
        }
      }
      if (this.docAt) {
        this.set('controller.showExtraHeaderInfo', offset >= this.docAt || !firstLoaded);
      } else {
        this.set('controller.showExtraHeaderInfo', !firstLoaded);
      }

      // there is a whole bunch of caching we could add here
      $lastPost = jQuery('.last-post');
      lastPostOffset = $lastPost.offset();
      if (!lastPostOffset) {
        return;
      }
      if (offset >= (lastPostOffset.top + $lastPost.height()) - jQuery(window).height()) {
        if (!this.dockedCounter) {
          jQuery('#topic-progress-wrapper').addClass('docked');
          this.dockedCounter = true;
        }
      } else {
        if (this.dockedCounter) {
          jQuery('#topic-progress-wrapper').removeClass('docked');
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
        opts.catLink = "<a href=\"/categories\">" + (Em.String.i18n("topic.browse_all_categories")) + "</a>";
        return Ember.String.i18n("topic.read_more", opts);
      }
    }).property(),
    /* The window has been scrolled
    */

    scrolled: function(e) {
      return this.examineRead();
    }
  });

  window.Discourse.TopicView.reopenClass({
    /* Scroll to a given post, if in the DOM. Returns whether it was in the DOM or not.
    */

    scrollTo: function(topicId, postNumber, callback) {
      /* Make sure we're looking at the topic we want to scroll to
      */

      var existing;
      if (parseInt(topicId, 10) !== parseInt(jQuery('#topic').data('topic-id'), 10)) {
        return false;
      }
      existing = jQuery("#post_" + postNumber);
      if (existing.length) {
        if (postNumber === 1) {
          jQuery('html, body').scrollTop(0);
        } else {
          jQuery('html, body').scrollTop(existing.offset().top - 55);
        }
        return true;
      }
      return false;
    }
  });

}).call(this);
