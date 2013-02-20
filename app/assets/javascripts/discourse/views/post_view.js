(function() {

  window.Discourse.PostView = Ember.View.extend({
    classNames: ['topic-post', 'clearfix'],
    templateName: 'post',
    classNameBindings: ['lastPostClass', 'postTypeClass', 'selectedClass', 'post.hidden:hidden', 'isDeleted:deleted', 'parentPost:replies-above'],
    siteBinding: Ember.Binding.oneWay('Discourse.site'),
    composeViewBinding: Ember.Binding.oneWay('Discourse.composeView'),
    quoteButtonViewBinding: Ember.Binding.oneWay('Discourse.quoteButtonView'),
    postBinding: 'content',
    isDeleted: (function() {
      return !!this.get('post.deleted_at');
    }).property('post.deleted_at'),
    /*TODO really we should do something cleaner here... this makes it work in debug but feels really messy
    */

    screenTrack: (function() {
      var parentView, screenTrack;
      parentView = this.get('parentView');
      screenTrack = null;
      while (parentView && !screenTrack) {
        screenTrack = parentView.get('screenTrack');
        parentView = parentView.get('parentView');
      }
      return screenTrack;
    }).property('parentView'),
    lastPostClass: (function() {
      if (this.get('post.lastPost')) {
        return 'last-post';
      }
    }).property('post.lastPost'),
    postTypeClass: (function() {
      if (this.get('post.post_type') === Discourse.get('site.post_types.moderator_action')) {
        return 'moderator';
      }
      return 'regular';
    }).property('post.post_type'),
    selectedClass: (function() {
      if (this.get('post.selected')) {
        return 'selected';
      }
      return null;
    }).property('post.selected'),
    /* If the cooked content changed, add the quote controls
    */

    cookedChanged: (function() {
      var _this = this;
      return Em.run.next(function() {
        return _this.insertQuoteControls();
      });
    }).observes('post.cooked'),
    init: function() {
      this._super();
      return this.set('context', this.get('content'));
    },
    mouseDown: function(e) {
      var qbc;
      if (qbc = Discourse.get('router.quoteButtonController')) {
        return qbc.mouseDown(e);
      }
    },
    mouseUp: function(e) {
      var $target, qbc;
      if (qbc = Discourse.get('router.quoteButtonController')) {
        qbc.mouseUp(e);
      }
      if (this.get('controller.multiSelect') && (e.metaKey || e.ctrlKey)) {
        this.toggleProperty('post.selected');
      }
      $target = jQuery(e.target);
      if ($target.closest('.cooked').length === 0) {
        return;
      }
      if (qbc = this.get('controller.controllers.quoteButton')) {
        e.context = this.get('post');
        return qbc.selectText(e);
      }
    },
    selectText: (function() {
      if (this.get('post.selected')) {
        return Em.String.i18n('topic.multi_select.selected', {
          count: this.get('controller.selectedCount')
        });
      }
      return Em.String.i18n('topic.multi_select.select');
    }).property('post.selected', 'controller.selectedCount'),
    repliesHidden: (function() {
      return !this.get('repliesShown');
    }).property('repliesShown'),
    /* Click on the replies button
    */

    showReplies: function() {
      var _this = this;
      if (this.get('repliesShown')) {
        this.set('repliesShown', false);
      } else {
        this.get('post').loadReplies().then(function() {
          return _this.set('repliesShown', true);
        });
      }
      return false;
    },
    /* Toggle visibility of parent post
    */

    toggleParent: function(e) {
      var $parent, post,
        _this = this;
      $parent = this.$('.parent-post');
      if (this.get('parentPost')) {
        jQuery('nav', $parent).removeClass('toggled');
        /* Don't animate on touch
        */

        if (Discourse.get('touch')) {
          $parent.hide();
          this.set('parentPost', null);
        } else {
          $parent.slideUp(function() {
            return _this.set('parentPost', null);
          });
        }
      } else {
        post = this.get('post');
        this.set('loadingParent', true);
        jQuery('nav', $parent).addClass('toggled');
        Discourse.Post.loadByPostNumber(post.get('topic_id'), post.get('reply_to_post_number'), function(result) {
          _this.set('loadingParent', false);
          /* Give the post a reference back to the topic
          */

          result.topic = _this.get('post.topic');
          return _this.set('parentPost', result);
        });
      }
      return false;
    },
    updateQuoteElements: function($aside, desc) {
      var expandContract, navLink, postNumber, quoteTitle, topic, topicId;
      navLink = "";
      quoteTitle = Em.String.i18n("post.follow_quote");
      if (postNumber = $aside.data('post')) {
        /* If we have a topic reference
        */

        if (topicId = $aside.data('topic')) {
          topic = this.get('controller.content');
          /* If it's the same topic as ours, build the URL from the topic object
          */

          if (topic && topic.get('id') === topicId) {
            navLink = "<a href='" + (topic.urlForPostNumber(postNumber)) + "' title='" + quoteTitle + "' class='back'></a>";
          } else {
            /* Made up slug should be replaced with canonical URL
            */

            navLink = "<a href='/t/via-quote/" + topicId + "/" + postNumber + "' title='" + quoteTitle + "' class='quote-other-topic'></a>";
          }
        } else if (topic = this.get('controller.content')) {
          /* assume the same topic
          */

          navLink = "<a href='" + (topic.urlForPostNumber(postNumber)) + "' title='" + quoteTitle + "' class='back'></a>";
        }
      }
      /* Only add the expand/contract control if it's not a full post
      */

      expandContract = "";
      if (!$aside.data('full')) {
        expandContract = "<i class='icon-" + desc + "' title='expand/collapse'></i>";
        $aside.css('cursor', 'pointer');
      }
      return jQuery('.quote-controls', $aside).html("" + expandContract + navLink);
    },
    toggleQuote: function($aside) {
      var $blockQuote, originalText, post, topic_id,
        _this = this;
      this.toggleProperty('quoteExpanded');
      if (this.get('quoteExpanded')) {
        this.updateQuoteElements($aside, 'chevron-up');
        /* Show expanded quote
        */

        $blockQuote = jQuery('blockquote', $aside);
        this.originalContents = $blockQuote.html();
        originalText = $blockQuote.text().trim();
        $blockQuote.html(Em.String.i18n("loading"));
        post = this.get('post');
        topic_id = post.get('topic_id');
        if ($aside.data('topic')) {
          topic_id = $aside.data('topic');
        }
        jQuery.getJSON("/posts/by_number/" + topic_id + "/" + ($aside.data('post')), function(result) {
          var parsed;
          parsed = jQuery(result.cooked);
          parsed.replaceText(originalText, "<span class='highlighted'>" + originalText + "</span>");
          return $blockQuote.showHtml(parsed);
        });
      } else {
        /* Hide expanded quote
        */

        this.updateQuoteElements($aside, 'chevron-down');
        jQuery('blockquote', $aside).showHtml(this.originalContents);
      }
      return false;
    },
    /* Show how many times links have been clicked on
    */

    showLinkCounts: function() {
      var link_counts,
        _this = this;
      if (link_counts = this.get('post.link_counts')) {
        return link_counts.each(function(lc) {
          if (lc.clicks > 0) {
            return _this.$(".cooked a[href]").each(function() {
              var link;
              link = jQuery(this);
              if (link.attr('href') === lc.url) {
                return link.append("<span class='badge badge-notification clicks' title='clicks'>" + lc.clicks + "</span>");
              }
            });
          }
        });
      }
    },
    /* Add the quote controls to a post
    */

    insertQuoteControls: function() {
      var _this = this;
      return this.$('aside.quote').each(function(i, e) {
        var $aside, $title;
        $aside = jQuery(e);
        _this.updateQuoteElements($aside, 'chevron-down');
        $title = jQuery('.title', $aside);
        /* Unless it's a full quote, allow click to expand
        */

        if (!($aside.data('full') || $title.data('has-quote-controls'))) {
          $title.on('click', function(e) {
            if (jQuery(e.target).is('a')) {
              return true;
            }
            return _this.toggleQuote($aside);
          });
          return $title.data('has-quote-controls', true);
        }
      });
    },
    didInsertElement: function(e) {
      var $contents, $post, newSize, originalCol, post, postNumber, scrollTo, _ref;
      $post = this.$();
      post = this.get('post');
      /* Do we want to scroll to this post now that we've inserted it?
      */

      if (postNumber = post.get('scrollToAfterInsert')) {
        Discourse.TopicView.scrollTo(this.get('post.topic_id'), postNumber);
        if (postNumber === post.get('post_number')) {
          $contents = jQuery('.topic-body .contents', $post);
          originalCol = $contents.css('backgroundColor');
          $contents.css({
            backgroundColor: "#ffffcc"
          }).animate({
            backgroundColor: originalCol
          }, 2500);
        }
      }
      this.showLinkCounts();
      if (_ref = this.get('screenTrack')) {
        _ref.track(this.$().prop('id'), this.get('post.post_number'));
      }
      /* Add syntax highlighting
      */

      Discourse.SyntaxHighlighting.apply($post);
      Discourse.Lightbox.apply($post);
      /* If we're scrolling upwards, adjust the scroll position accordingly
      */

      if (scrollTo = this.get('post.scrollTo')) {
        newSize = (jQuery(document).height() - scrollTo.height) + scrollTo.top;
        jQuery('body').scrollTop(newSize);
        jQuery('section.divider').addClass('fade');
      }
      /* Find all the quotes
      */

      return this.insertQuoteControls();
    }
  });

}).call(this);
