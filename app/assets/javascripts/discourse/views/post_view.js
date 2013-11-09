/**
  This view renders a post.

  @class PostView
  @extends Discourse.GroupedView
  @namespace Discourse
  @module Discourse
**/
Discourse.PostView = Discourse.GroupedView.extend(Ember.Evented, {
  classNames: ['topic-post', 'clearfix'],
  templateName: 'post',
  classNameBindings: ['postTypeClass',
                      'selected',
                      'post.hidden:hidden',
                      'post.deleted'],
  postBinding: 'content',

  postTypeClass: function() {
    return this.get('post.post_type') === Discourse.Site.currentProp('post_types.moderator_action') ? 'moderator' : 'regular';
  }.property('post.post_type'),

  // If the cooked content changed, add the quote controls
  cookedChanged: function() {
    var postView = this;
    Em.run.schedule('afterRender', function() {
      postView.insertQuoteControls();
    });
  }.observes('post.cooked'),

  mouseUp: function(e) {
    if (this.get('controller.multiSelect') && (e.metaKey || e.ctrlKey)) {
      this.get('controller').toggledSelectedPost(this.get('post'));
    }
  },

  selected: function() {
    return this.get('controller').postSelected(this.get('post'));
  }.property('controller.selectedPostsCount'),

  canSelectReplies: function() {
    if (this.get('post.reply_count') === 0) { return false; }
    return !this.get('selected');
  }.property('post.reply_count', 'selected'),

  selectPostText: function() {
    return this.get('selected') ? I18n.t('topic.multi_select.selected', { count: this.get('controller.selectedPostsCount') }) : I18n.t('topic.multi_select.select');
  }.property('selected', 'controller.selectedPostsCount'),

  repliesShown: Em.computed.gt('post.replies.length', 0),

  updateQuoteElements: function($aside, desc) {
    var navLink = "";
    var quoteTitle = I18n.t("post.follow_quote");
    var postNumber = $aside.data('post');

    if (postNumber) {

      // If we have a topic reference
      var topicId, topic;
      if (topicId = $aside.data('topic')) {
        topic = this.get('controller.content');

        // If it's the same topic as ours, build the URL from the topic object
        if (topic && topic.get('id') === topicId) {
          navLink = "<a href='" + topic.urlForPostNumber(postNumber) + "' title='" + quoteTitle + "' class='back'></a>";
        } else {
          // Made up slug should be replaced with canonical URL
          navLink = "<a href='" + Discourse.getURL("/t/via-quote/") + topicId + "/" + postNumber + "' title='" + quoteTitle + "' class='quote-other-topic'></a>";
        }

      } else if (topic = this.get('controller.content')) {
        // assume the same topic
        navLink = "<a href='" + topic.urlForPostNumber(postNumber) + "' title='" + quoteTitle + "' class='back'></a>";
      }
    }
    // Only add the expand/contract control if it's not a full post
    var expandContract = "";
    if (!$aside.data('full')) {
      expandContract = "<i class='icon-" + desc + "' title='" + I18n.t("post.expand_collapse") + "'></i>";
      $aside.css('cursor', 'pointer');
    }
    $('.quote-controls', $aside).html("" + expandContract + navLink);
  },

  toggleQuote: function($aside) {
    $aside.data('expanded',!$aside.data('expanded'));
    if ($aside.data('expanded')) {
      this.updateQuoteElements($aside, 'chevron-up');
      // Show expanded quote
      var $blockQuote = $('blockquote', $aside);
      $aside.data('original-contents',$blockQuote.html());

      var originalText = $blockQuote.text().trim();
      $blockQuote.html(I18n.t("loading"));
      var topic_id = this.get('post.topic_id');
      if ($aside.data('topic')) {
        topic_id = $aside.data('topic');
      }
      Discourse.ajax("/posts/by_number/" + topic_id + "/" + $aside.data('post')).then(function (result) {
        var parsed = $(result.cooked);
        parsed.replaceText(originalText, "<span class='highlighted'>" + originalText + "</span>");
        $blockQuote.showHtml(parsed);
      });
    } else {
      // Hide expanded quote
      this.updateQuoteElements($aside, 'chevron-down');
      $('blockquote', $aside).showHtml($aside.data('original-contents'));
    }
    return false;
  },

  // Show how many times links have been clicked on
  showLinkCounts: function() {

    var postView = this;
    var link_counts = this.get('post.link_counts');

    if (link_counts) {
      _.each(link_counts, function(lc) {
        if (lc.clicks > 0) {
          postView.$(".cooked a[href]").each(function() {
            var link = $(this);
            if (link.attr('href') === lc.url) {
              // don't display badge counts on category badge
              if (link.closest('.badge-category').length === 0) {
                // nor in oneboxes (except when we force it)
                if (link.closest(".onebox-result").length === 0 || link.hasClass("track-link")) {
                  link.append("<span class='badge badge-notification clicks' title='" + I18n.t("topic_summary.clicks") + "'>" + lc.clicks + "</span>");
                }
              }
            }
          });
        }
      });
    }
  },

  actions: {
    /**
      Toggle the replies this post is a reply to

      @method showReplyHistory
    **/
    toggleReplyHistory: function(post) {

      var replyHistory = post.get('replyHistory'),
          topicController = this.get('controller'),
          origScrollTop = $(window).scrollTop();


      if (replyHistory.length > 0) {
        var origHeight = this.$('.embedded-posts.top').height();

        replyHistory.clear();
        Em.run.next(function() {
          $(window).scrollTop(origScrollTop - origHeight);
        });
      } else {
        post.set('loadingReplyHistory', true);

        var self = this;
        topicController.get('postStream').findReplyHistory(post).then(function () {
          post.set('loadingReplyHistory', false);

          Em.run.next(function() {
            $(window).scrollTop(origScrollTop + self.$('.embedded-posts.top').height());
          });
        });
      }
    }
  },

  // Add the quote controls to a post
  insertQuoteControls: function() {
    var postView = this;

    return this.$('aside.quote').each(function(i, e) {
      var $aside = $(e);
      postView.updateQuoteElements($aside, 'chevron-down');
      var $title = $('.title', $aside);

      // Unless it's a full quote, allow click to expand
      if (!($aside.data('full') || $title.data('has-quote-controls'))) {
        $title.on('click', function(e) {
          if ($(e.target).is('a')) return true;
          postView.toggleQuote($aside);
        });
        $title.data('has-quote-controls', true);
      }
    });
  },

  willDestroyElement: function() {
    Discourse.ScreenTrack.current().stopTracking(this.$().prop('id'));
  },

  didInsertElement: function() {
    var $post = this.$(),
        post = this.get('post');

    this.showLinkCounts();

    // Track this post
    Discourse.ScreenTrack.current().track(this.$().prop('id'), this.get('post.post_number'));

    // Add syntax highlighting
    Discourse.SyntaxHighlighting.apply($post);
    Discourse.Lightbox.apply($post);

    this.trigger('postViewInserted', $post);

    // Find all the quotes
    this.insertQuoteControls();

    $post.addClass('ready');
  }
});
