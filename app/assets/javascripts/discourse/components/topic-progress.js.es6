import { default as computed, observes } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  elementId: 'topic-progress-wrapper',
  classNameBindings: ['docked', 'hidden'],
  expanded: false,
  toPostIndex: null,
  docked: false,
  progressPosition: null,
  postStream: Ember.computed.alias('topic.postStream'),
  userWantsToJump: null,

  init() {
    this._super();
    (this.get('delegated') || []).forEach(m => this.set(m, m));
  },

  @computed('userWantsToJump', 'showTimeline')
  hidden(userWantsToJump, showTimeline) {
    return !userWantsToJump && showTimeline;
  },

  keyboardTrigger(kbdEvent) {
    if (kbdEvent.type === 'jump') {
      this.set('expanded', true);
      this.set('userWantsToJump', true);
      Ember.run.scheduleOnce('afterRender', () => this.$('.jump-form input').focus());
    }
  },

  @computed('postStream.loaded', 'progressPosition', 'postStream.filteredPostsCount', 'postStream.highest_post_number')
  streamPercentage(loaded, progressPosition, filteredPostsCount, highestPostNumber) {
    if (!loaded) { return 0; }
    if (highestPostNumber === 0) { return 0; }
    const perc = progressPosition / filteredPostsCount;
    return (perc > 1.0) ? 1.0 : perc;
  },

  @computed('progressPosition')
  jumpTopDisabled(progressPosition) {
    return progressPosition <= 3;
  },

  @computed('postStream.filteredPostsCount', 'topic.highest_post_number', 'progressPosition')
  jumpBottomDisabled(filteredPostsCount, highestPostNumber, progressPosition) {
    return progressPosition >= filteredPostsCount || progressPosition >= highestPostNumber;
  },


  @computed('postStream.loaded', 'topic.currentPost', 'postStream.filteredPostsCount')
  hideProgress(loaded, currentPost, filteredPostsCount) {
    return (!loaded) || (!currentPost) || (filteredPostsCount < 2);
  },

  @computed('postStream.filteredPostsCount')
  hugeNumberOfPosts(filteredPostsCount) {
    return filteredPostsCount >= this.siteSettings.short_progress_text_threshold;
  },

  @computed('hugeNumberOfPosts', 'topic.highest_post_number')
  jumpToBottomTitle(hugeNumberOfPosts, highestPostNumber) {
    if (hugeNumberOfPosts) {
      return I18n.t('topic.progress.jump_bottom_with_number', { post_number: highestPostNumber });
    } else {
      return I18n.t('topic.progress.jump_bottom');
    }
  },

  @observes('streamPercentage', 'postStream.stream.[]')
  _updateBar() {
    Ember.run.scheduleOnce('afterRender', this, this._updateProgressBar);
  },

  didInsertElement() {
    this._super();
    this.appEvents.on("composer:opened", this, this._dock)
                  .on("composer:resized", this, this._dock)
                  .on("composer:closed", this, this._dock)
                  .on("topic:scrolled", this, this._dock)
                  .on('topic:current-post-changed', postNumber => this.set('progressPosition', postNumber))
                  .on('topic-progress:keyboard-trigger', this, this.keyboardTrigger);

    Ember.run.scheduleOnce('afterRender', this, this._updateProgressBar);
  },

  willDestroyElement() {
    this._super();
    this.appEvents.off("composer:opened", this, this._dock)
                  .off("composer:resized", this, this._dock)
                  .off("composer:closed", this, this._dock)
                  .off('topic:scrolled', this, this._dock)
                  .off('topic:current-post-changed')
                  .off('topic-progress:keyboard-trigger');
  },

  _updateProgressBar() {
    if (this.get('hidden')) { return; }

    const $topicProgress = this.$('#topic-progress');
    // speeds up stuff, bypass jquery slowness and extra checks
    if (!this._totalWidth) {
      this._totalWidth = $topicProgress[0].offsetWidth;
    }
    const totalWidth = this._totalWidth;
    const progressWidth = this.get('streamPercentage') * totalWidth;

    $topicProgress.find('.bg')
      .css("border-right-width", (progressWidth === totalWidth) ? "0px" : "1px")
      .width(progressWidth);
  },

  _dock() {
    const maximumOffset = $('#topic-footer-buttons').offset(),
        composerHeight = $('#reply-control').height() || 0,
        $topicProgressWrapper = this.$(),
        style = $topicProgressWrapper.attr('style') || '',
        offset = window.pageYOffset || $('html').scrollTop();

    let isDocked = false;
    if (maximumOffset) {
      const threshold = maximumOffset.top,
          windowHeight = $(window).height(),
          topicProgressHeight = $('#topic-progress').height();

      isDocked = offset >= threshold - windowHeight + topicProgressHeight + composerHeight;
    }

    if (composerHeight > 0) {
      if (isDocked) {
        if (style.indexOf('bottom') >= 0) {
          $topicProgressWrapper.css('bottom', '');
        }
      } else {
        const height = composerHeight + "px";
        if ($topicProgressWrapper.css('bottom') !== height) {
          $topicProgressWrapper.css('bottom', height);
        }
      }
    } else {
      if (style.indexOf('bottom') >= 0) {
        $topicProgressWrapper.css('bottom', '');
      }
    }
    this.set('docked', isDocked);
  },

  click(e) {
    if ($(e.target).parents('#topic-progress').length) {
      this.send('toggleExpansion');
    }
  },

  keyDown(e) {
    if (this.get('expanded')) {
      if (e.keyCode === 13) {
        this.$('input').blur();
        this.send('jumpPost');
      } else if (e.keyCode === 27) {
        this.send('toggleExpansion');
        this.set('userWantsToJump', false);
      }
    }
  },

  actions: {
    toggleExpansion(opts) {
      this.toggleProperty('expanded');
      if (this.get('expanded')) {
        this.set('userWantsToJump', false);
        this.set('toPostIndex', this.get('progressPosition'));
        if(opts && opts.highlight){
          // TODO: somehow move to view?
          Em.run.next(function(){
            $('.jump-form input').select().focus();
          });
        }
        if (!this.site.mobileView && !this.capabilities.isIOS) {
          Ember.run.schedule('afterRender', () => this.$('input').focus());
        }
      }
    },

    jumpPost() {
      let postIndex = parseInt(this.get('toPostIndex'), 10);

      // Validate the post index first
      if (isNaN(postIndex) || postIndex < 1) {
        postIndex = 1;
      }
      if (postIndex > this.get('postStream.filteredPostsCount')) {
        postIndex = this.get('postStream.filteredPostsCount');
      }
      this.set('toPostIndex', postIndex);
      this._beforeJump();
      this.sendAction('jumpToIndex', postIndex);
    },

    jumpTop() {
      this._beforeJump();
      this.sendAction('jumpTop');
    },

    jumpBottom() {
      this._beforeJump();
      this.sendAction('jumpBottom');
    }
  },

  _beforeJump() {
    this.set('expanded', false);
    this.set('userWantsToJump', false);
  }
});
