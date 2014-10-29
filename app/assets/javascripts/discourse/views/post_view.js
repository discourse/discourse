var DAY = 60 * 50 * 1000;

Discourse.PostView = Discourse.GroupedView.extend(Ember.Evented, {
  classNames: ['topic-post', 'clearfix'],
  templateName: 'post',
  classNameBindings: ['postTypeClass',
                      'selected',
                      'post.hidden:post-hidden',
                      'post.deleted',
                      'byTopicCreator:topic-creator',
                      'groupNameClass',
                      'post.wiki:wiki'],
  postBinding: 'content',

  historyHeat: function() {
    var updatedAt = this.get('post.updated_at');
    if (!updatedAt) { return; }

    // Show heat on age
    var rightNow = new Date().getTime(),
        updatedAtDate = new Date(updatedAt).getTime();

    if (updatedAtDate > (rightNow - DAY * Discourse.SiteSettings.history_hours_low)) return 'heatmap-high';
    if (updatedAtDate > (rightNow - DAY * Discourse.SiteSettings.history_hours_medium)) return 'heatmap-med';
    if (updatedAtDate > (rightNow - DAY * Discourse.SiteSettings.history_hours_high)) return 'heatmap-low';
  }.property('post.updated_at'),

  postTypeClass: function() {
    return this.get('post.post_type') === Discourse.Site.currentProp('post_types.moderator_action') ? 'moderator' : 'regular';
  }.property('post.post_type'),

  groupNameClass: function() {
    var primaryGroupName = this.get('post.primary_group_name');
    if (primaryGroupName) {
      return "group-" + primaryGroupName;
    }
  }.property('post.primary_group_name'),

  showExpandButton: function() {
    if (this.get('controller.firstPostExpanded')) { return false; }

    var post = this.get('post');
    return post.get('post_number') === 1 && post.get('topic.expandable_first_post');
  }.property('post.post_number', 'controller.firstPostExpanded'),

  // If the cooked content changed, add the quote controls
  cookedChanged: function() {
    Em.run.scheduleOnce('afterRender', this, '_insertQuoteControls');
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

  _updateQuoteElements: function($aside, desc) {
    var navLink = "",
        quoteTitle = I18n.t("post.follow_quote"),
        postNumber = $aside.data('post');

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
      expandContract = "<i class='fa fa-" + desc + "' title='" + I18n.t("post.expand_collapse") + "'></i>";
      $('.title', $aside).css('cursor', 'pointer');
    }
    $('.quote-controls', $aside).html(expandContract + navLink);
  },

  _toggleQuote: function($aside) {
    if (this.get('expanding')) { return; }
    this.set('expanding', true);

    $aside.data('expanded', !$aside.data('expanded'));

    var self = this,
        finished = function() {
          self.set('expanding', false);
        };

    if ($aside.data('expanded')) {
      this._updateQuoteElements($aside, 'chevron-up');
      // Show expanded quote
      var $blockQuote = $('blockquote', $aside);
      $aside.data('original-contents',$blockQuote.html());

      var originalText = $blockQuote.text().trim();
      $blockQuote.html(I18n.t("loading"));
      var topicId = this.get('post.topic_id');
      if ($aside.data('topic')) {
        topicId = $aside.data('topic');
      }

      var postId = parseInt($aside.data('post'), 10);
      topicId = parseInt(topicId, 10);

      Discourse.ajax("/posts/by_number/" + topicId + "/" + postId).then(function (result) {
        // slightly double escape the cooked html to prevent jQuery from unescaping it
        var escaped = result.cooked.replace("&", "&amp;");
        var parsed = $(escaped);
        parsed.replaceText(originalText, "<span class='highlighted'>" + originalText + "</span>");
        $blockQuote.showHtml(parsed, 'fast', finished);
      });
    } else {
      // Hide expanded quote
      this._updateQuoteElements($aside, 'chevron-down');
      $('blockquote', $aside).showHtml($aside.data('original-contents'), 'fast', finished);
    }
    return false;
  },

  // Show how many times links have been clicked on
  _showLinkCounts: function() {
    var self = this,
        link_counts = this.get('post.link_counts');

    if (!link_counts) return;

    link_counts.forEach(function(lc) {
      if (!lc.clicks || lc.clicks < 1) return;

      self.$(".cooked a[href]").each(function() {
        var link = $(this);
        if (!lc.internal && link.attr('href') === lc.url) {
          // don't display badge counts on category badge
          if (link.closest('.badge-category').length === 0 && ((link.closest(".onebox-result").length === 0 && link.closest('.onebox-body').length === 0) || link.hasClass("track-link"))) {
            link.append("<span class='badge badge-notification clicks' title='" +
                        I18n.t("topic_map.clicks", {count: lc.clicks}) +
                        "'>" + Discourse.Formatter.number(lc.clicks) + "</span>");
          }
        }
      });
    });
  },

  actions: {
    /**
      Toggle the replies this post is a reply to

      @method showReplyHistory
    **/
    toggleReplyHistory: function(post) {

      var replyHistory = post.get('replyHistory'),
          topicController = this.get('controller'),
          origScrollTop = $(window).scrollTop(),
          replyPostNumber = this.get('post.reply_to_post_number'),
          postNumber = this.get('post.post_number'),
          self = this;

      if (Discourse.Mobile.mobileView) {
        Discourse.URL.routeTo(this.get('post.topic').urlForPostNumber(replyPostNumber));
        return;
      }

      var stream = topicController.get('postStream');
      var offsetFromTop = this.$().position().top - $(window).scrollTop();

      if(Discourse.SiteSettings.experimental_reply_expansion) {
        if(postNumber - replyPostNumber > 1) {
          stream.collapsePosts(replyPostNumber + 1, postNumber - 1);
        }

        Em.run.next(function() {
          Discourse.PostView.highlight(replyPostNumber);
          $(window).scrollTop(self.$().position().top - offsetFromTop);
        });
        return;
      }

      if (replyHistory.length > 0) {
        var origHeight = this.$('.embedded-posts.top').height();

        replyHistory.clear();
        Em.run.next(function() {
          $(window).scrollTop(origScrollTop - origHeight);
        });
      } else {
        post.set('loadingReplyHistory', true);

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
  _insertQuoteControls: function() {
    var self = this,
        $quotes = this.$('aside.quote');

    // Safety check - in some cases with cloackedView this seems to be `undefined`.
    if (Em.isEmpty($quotes)) { return; }

    $quotes.each(function(i, e) {
      var $aside = $(e);
      if ($aside.data('post')) {
        self._updateQuoteElements($aside, 'chevron-down');
        var $title = $('.title', $aside);

        // Unless it's a full quote, allow click to expand
        if (!($aside.data('full') || $title.data('has-quote-controls'))) {
          $title.on('click', function(e) {
            if ($(e.target).is('a')) return true;
            self._toggleQuote($aside);
          });
          $title.data('has-quote-controls', true);
        }
      }
    });
  },

  _destroyedPostView: function() {
    Discourse.ScreenTrack.current().stopTracking(this.get('elementId'));
  }.on('willDestroyElement'),

  _postViewInserted: function() {
    var $post = this.$(),
        post = this.get('post'),
        postNumber = post.get('post_number');

    this._showLinkCounts();

    // Track this post
    Discourse.ScreenTrack.current().track(this.$().prop('id'), postNumber);

    // Highlight the post if required
    if (postNumber > 1) {
      Discourse.PostView.considerHighlighting(this.get('controller'), postNumber);
    }

    // Add syntax highlighting
    Discourse.SyntaxHighlighting.apply($post);
    Discourse.Lightbox.apply($post);

    this.trigger('postViewInserted', $post);

    // Find all the quotes
    Em.run.scheduleOnce('afterRender', this, '_insertQuoteControls');

    this._applySearchHighlight();
  }.on('didInsertElement'),

  _applySearchHighlight: function() {
    var highlight = this.get('controller.searchHighlight');
    var cooked = this.$('.cooked');

    if(!cooked){ return; }

    if(highlight && highlight.length > 2){
      if(this._highlighted){
         cooked.unhighlight();
      }
      cooked.highlight(highlight.split(/\s+/));
      this._highlighted = true;

    } else if(this._highlighted){
      cooked.unhighlight();
      this._highlighted = false;
    }
  }.observes('controller.searchHighlight', 'cooked')
});

Discourse.PostView.reopenClass({
  highlight: function(postNumber){
    var $contents = $('#post_' + postNumber +' .topic-body'),
        origColor = $contents.data('orig-color') || $contents.css('backgroundColor');

    $contents.data("orig-color", origColor);
    $contents
      .addClass('highlighted')
      .stop()
      .animate({ backgroundColor: origColor }, 2500, 'swing', function(){
        $contents.removeClass('highlighted');
        $contents.css({'background-color': ''});
      });
  },

  considerHighlighting: function(controller, postNumber) {
    var highlightNumber = controller.get('highlightOnInsert');

    // If we're meant to highlight a post
    if (highlightNumber === postNumber) {
      controller.set('highlightOnInsert', null);
      this.highlight(postNumber);
    }
  }
});
