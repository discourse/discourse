import ScreenTrack from 'discourse/lib/screen-track';
import { number } from 'discourse/lib/formatter';
import DiscourseURL from 'discourse/lib/url';
import { default as computed, on } from 'ember-addons/ember-computed-decorators';
import { fmt } from 'discourse/lib/computed';

const DAY = 60 * 50 * 1000;

const PostView = Discourse.GroupedView.extend(Ember.Evented, {
  classNames: ['topic-post', 'clearfix'],
  classNameBindings: ['needsModeratorClass:moderator:regular',
                      'selected',
                      'post.hidden:post-hidden',
                      'post.deleted:deleted',
                      'post.topicOwner:topic-owner',
                      'groupNameClass',
                      'post.wiki:wiki',
                      'whisper'],

  post: Ember.computed.alias('content'),
  postElementId: fmt('post.post_number', 'post_%@'),
  likedUsers: null,

  @on('init')
  initLikedUsers() {
    this.set('likedUsers', []);
  },

  @computed('post.post_type')
  whisper(postType) {
    return postType === this.site.get('post_types.whisper');
  },

  templateName: function() {
    return (this.get('post.post_type') === this.site.get('post_types.small_action')) ? 'post-small-action' : 'post';
  }.property('post.post_type'),

  historyHeat: function() {
    const updatedAt = this.get('post.updated_at');
    if (!updatedAt) { return; }

    // Show heat on age
    const rightNow = new Date().getTime(),
        updatedAtDate = new Date(updatedAt).getTime();

    if (updatedAtDate > (rightNow - DAY * Discourse.SiteSettings.history_hours_low)) return 'heatmap-high';
    if (updatedAtDate > (rightNow - DAY * Discourse.SiteSettings.history_hours_medium)) return 'heatmap-med';
    if (updatedAtDate > (rightNow - DAY * Discourse.SiteSettings.history_hours_high)) return 'heatmap-low';
  }.property('post.updated_at'),

  needsModeratorClass: function() {
    return (this.get('post.post_type') === this.site.get('post_types.moderator_action')) ||
           (this.get('post.topic.is_warning') && this.get('post.firstPost'));
  }.property('post.post_type'),

  groupNameClass: function() {
    const primaryGroupName = this.get('post.primary_group_name');
    if (primaryGroupName) {
      return "group-" + primaryGroupName;
    }
  }.property('post.primary_group_name'),

  showExpandButton: function() {
    if (this.get('controller.firstPostExpanded')) { return false; }

    const post = this.get('post');
    return post.get('post_number') === 1 && post.get('topic.expandable_first_post');
  }.property('post.post_number', 'controller.firstPostExpanded'),

  // If the cooked content changed, add the quote controls
  cookedChanged: function() {
    Em.run.scheduleOnce('afterRender', this, '_cookedWasChanged');
  }.observes('post.cooked'),

  _cookedWasChanged() {
    this.trigger('postViewUpdated', this.$());
    this._insertQuoteControls();
  },

  mouseUp(e) {
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

  _updateQuoteElements($aside, desc) {
    let navLink = "";
    const quoteTitle = I18n.t("post.follow_quote"),
          postNumber = $aside.data('post');

    if (postNumber) {

      // If we have a topic reference
      let topicId, topic;
      if (topicId = $aside.data('topic')) {
        topic = this.get('controller.content');

        // If it's the same topic as ours, build the URL from the topic object
        if (topic && topic.get('id') === topicId) {
          navLink = `<a href='${topic.urlForPostNumber(postNumber)}' title='${quoteTitle}' class='back'></a>`;
        } else {
          // Made up slug should be replaced with canonical URL
          navLink = `<a href='${Discourse.getURL("/t/via-quote/") + topicId + "/" + postNumber}' title='${quoteTitle}' class='quote-other-topic'></a>`;
        }

      } else if (topic = this.get('controller.content')) {
        // assume the same topic
        navLink = `<a href='${topic.urlForPostNumber(postNumber)}' title='${quoteTitle}' class='back'></a>`;
      }
    }
    // Only add the expand/contract control if it's not a full post
    let expandContract = "";
    if (!$aside.data('full')) {
      expandContract = `<i class='fa fa-${desc}' title='${I18n.t("post.expand_collapse")}'></i>`;
      $('.title', $aside).css('cursor', 'pointer');
    }
    $('.quote-controls', $aside).html(expandContract + navLink);
  },

  _toggleQuote($aside) {
    if (this.get('expanding')) { return; }

    this.set('expanding', true);

    $aside.data('expanded', !$aside.data('expanded'));

    const finished = () => this.set('expanding', false);

    if ($aside.data('expanded')) {
      this._updateQuoteElements($aside, 'chevron-up');
      // Show expanded quote
      const $blockQuote = $('blockquote', $aside);
      $aside.data('original-contents', $blockQuote.html());

      const originalText = $blockQuote.text().trim();
      $blockQuote.html(I18n.t("loading"));
      let topicId = this.get('post.topic_id');
      if ($aside.data('topic')) {
        topicId = $aside.data('topic');
      }

      const postId = parseInt($aside.data('post'), 10);
      topicId = parseInt(topicId, 10);

      Discourse.ajax(`/posts/by_number/${topicId}/${postId}`).then(result => {
        const div = $("<div class='expanded-quote'></div>");
        div.html(result.cooked);
        div.highlight(originalText, {caseSensitive: true, element: 'span', className: 'highlighted'});
        $blockQuote.showHtml(div, 'fast', finished);
      });
    } else {
      // Hide expanded quote
      this._updateQuoteElements($aside, 'chevron-down');
      $('blockquote', $aside).showHtml($aside.data('original-contents'), 'fast', finished);
    }
    return false;
  },

  // Show how many times links have been clicked on
  _showLinkCounts() {
    const self = this,
          link_counts = this.get('post.link_counts');

    if (!link_counts) { return; }

    link_counts.forEach(function(lc) {
      if (!lc.clicks || lc.clicks < 1) { return; }

      self.$(".cooked a[href]").each(function() {
        const $link = $(this),
              href = $link.attr('href');

        let valid = !lc.internal && href === lc.url;

        // this might be an attachment
        if (lc.internal) { valid = href.indexOf(lc.url) >= 0; }

        if (valid) {
          // don't display badge counts on category badge & oneboxes (unless when explicitely stated)
          if ($link.hasClass("track-link") ||
              $link.closest('.badge-category,.onebox-result,.onebox-body').length === 0) {
            $link.append("<span class='badge badge-notification clicks' title='" + I18n.t("topic_map.clicks", {count: lc.clicks}) + "'>" + number(lc.clicks) + "</span>");
          }
        }
      });
    });
  },

  actions: {
    toggleLike() {
      const currentUser = this.get('controller.currentUser');
      const post = this.get('post');
      const likeAction = post.get('likeAction');
      if (likeAction && likeAction.get('canToggle')) {
        const users = this.get('likedUsers');
        if (likeAction.toggle(post) && users.length) {
          users.addObject(currentUser);
        } else {
          users.removeObject(currentUser);
        }
      }
    },

    toggleWhoLiked() {
      const post = this.get('post');
      const likeAction = post.get('likeAction');
      if (likeAction) {
        const users = this.get('likedUsers');
        if (users.length) {
          users.clear();
        } else {
          likeAction.loadUsers(post).then(newUsers => this.set('likedUsers', newUsers));
        }
      }
    },

    // Toggle the replies this post is a reply to
    toggleReplyHistory(post) {
      const replyHistory = post.get('replyHistory'),
            topicController = this.get('controller'),
            origScrollTop = $(window).scrollTop(),
            replyPostNumber = this.get('post.reply_to_post_number'),
            postNumber = this.get('post.post_number'),
            self = this;

      if (Discourse.Mobile.mobileView) {
        DiscourseURL.routeTo(this.get('post.topic').urlForPostNumber(replyPostNumber));
        return;
      }

      const stream = topicController.get('model.postStream');
      const offsetFromTop = this.$().position().top - $(window).scrollTop();

      if(Discourse.SiteSettings.experimental_reply_expansion) {
        if(postNumber - replyPostNumber > 1) {
          stream.collapsePosts(replyPostNumber + 1, postNumber - 1);
        }

        Em.run.next(function() {
          PostView.highlight(replyPostNumber);
          $(window).scrollTop(self.$().position().top - offsetFromTop);
        });
        return;
      }

      if (replyHistory.length > 0) {
        const origHeight = this.$('.embedded-posts.top').height();

        replyHistory.clear();
        Em.run.next(function() {
          $(window).scrollTop(origScrollTop - origHeight);
        });
      } else {
        post.set('loadingReplyHistory', true);

        stream.findReplyHistory(post).then(function () {
          post.set('loadingReplyHistory', false);

          Em.run.next(function() {
            $(window).scrollTop(origScrollTop + self.$('.embedded-posts.top').height());
          });
        });
      }
    }
  },

  // Add the quote controls to a post
  _insertQuoteControls() {
    const self = this,
        $quotes = this.$('aside.quote');

    // Safety check - in some cases with cloackedView this seems to be `undefined`.
    if (Em.isEmpty($quotes)) { return; }

    $quotes.each(function(i, e) {
      const $aside = $(e);
      if ($aside.data('post')) {
        self._updateQuoteElements($aside, 'chevron-down');
        const $title = $('.title', $aside);

        // Unless it's a full quote, allow click to expand
        if (!($aside.data('full') || $title.data('has-quote-controls'))) {
          $title.on('click', function(e2) {
            if ($(e2.target).is('a')) return true;
            self._toggleQuote($aside);
          });
          $title.data('has-quote-controls', true);
        }
      }
    });
  },

  _destroyedPostView: function() {
    ScreenTrack.current().stopTracking(this.get('elementId'));
  }.on('willDestroyElement'),

  _postViewInserted: function() {
    const $post = this.$(),
          postNumber = this.get('post').get('post_number');

    this._showLinkCounts();

    ScreenTrack.current().track($post.prop('id'), postNumber);

    this.trigger('postViewInserted', $post);

    // Find all the quotes
    Em.run.scheduleOnce('afterRender', this, '_insertQuoteControls');

    this._applySearchHighlight();
  }.on('didInsertElement'),

  _fixImageSizes: function(){
    var maxWidth;
    this.$('img:not(.avatar)').each(function(idx,img){

      // deferring work only for posts with images
      // we got to use screen here, cause nothing is rendered yet.
      // long term we may want to allow for weird margins that are enforced, instead of hardcoding at 70/20
      maxWidth = maxWidth || $(window).width() - (Discourse.Mobile.mobileView ? 20 : 70);
      if (Discourse.SiteSettings.max_image_width < maxWidth) {
        maxWidth = Discourse.SiteSettings.max_image_width;
      }

      var aspect = img.height / img.width;
      if (img.width > maxWidth) {
        img.width = maxWidth;
        img.height = parseInt(maxWidth * aspect,10);
      }

      // very unlikely but lets fix this too
      if (img.height > Discourse.SiteSettings.max_image_height) {
        img.height = Discourse.SiteSettings.max_image_height;
        img.width = parseInt(maxWidth / aspect,10);
      }

    });
  }.on('willInsertElement'),

  _applySearchHighlight: function() {
    const highlight = this.get('searchService.highlightTerm');
    const cooked = this.$('.cooked');

    if (!cooked) { return; }

    if (highlight && highlight.length > 2) {
      if (this._highlighted) {
         cooked.unhighlight();
      }
      cooked.highlight(highlight.split(/\s+/));
      this._highlighted = true;

    } else if (this._highlighted) {
      cooked.unhighlight();
      this._highlighted = false;
    }
  }.observes('searchService.highlightTerm', 'cooked')
});

export default PostView;
