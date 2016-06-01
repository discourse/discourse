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
  _streamPercentage: null,

  init() {
    this._super();
    (this.get('delegated') || []).forEach(m => this.set(m, m));
  },

  @computed('userWantsToJump', 'showTimeline')
  hidden(userWantsToJump, showTimeline) {
    return !userWantsToJump && showTimeline;
  },

  @observes('hidden')
  visibilityChanged() {
    if (!this.get('hidden')) {
      this._updateBar();
    }
  },

  keyboardTrigger(kbdEvent) {
    if (kbdEvent.type === 'jump') {
      this.set('expanded', true);
      this.set('userWantsToJump', true);
      Ember.run.scheduleOnce('afterRender', () => this.$('.jump-form input').focus());
    }
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

  @observes('postStream.stream.[]')
  _updateBar() {
    Ember.run.scheduleOnce('afterRender', this, this._updateProgressBar);
  },

  _topicScrolled(event) {
    this.set('progressPosition', event.postIndex);
    this._streamPercentage = event.percent;
    this._updateBar();
  },

  didInsertElement() {
    this._super();

    this.appEvents.on('composer:will-open', this, this._dock)
                  .on("composer:resized", this, this._dock)
                  .on('composer:closed', this, this._dock)
                  .on("topic:scrolled", this, this._dock)
                  .on('topic:current-post-scrolled', this, this._topicScrolled)
                  .on('topic-progress:keyboard-trigger', this, this.keyboardTrigger);

    Ember.run.scheduleOnce('afterRender', this, this._updateProgressBar);
  },

  willDestroyElement() {
    this._super();
    this.appEvents.off('composer:will-open', this, this._dock)
                  .off("composer:resized", this, this._dock)
                  .off('composer:closed', this, this._dock)
                  .off('topic:scrolled', this, this._dock)
                  .off('topic:current-post-scrolled')
                  .off('topic-progress:keyboard-trigger');
  },

  _updateProgressBar() {
    if (this.isDestroyed || this.isDestroying || this.get('hidden')) { return; }

    const $topicProgress = this.$('#topic-progress');
    // speeds up stuff, bypass jquery slowness and extra checks
    if (!this._totalWidth) {
      this._totalWidth = $topicProgress[0].offsetWidth;
    }
    const totalWidth = this._totalWidth;
    const progressWidth = (this._streamPercentage || 0) * totalWidth;

    const borderSize = (progressWidth === totalWidth) ? "0px" : "1px";
    const $bg = $topicProgress.find('.bg');
    if ($bg.length === 0) {
      const style = `border-right-width: ${borderSize}; width: ${progressWidth}px`;
      $topicProgress.append(`<div class='bg' style="${style}">&nbsp;</div>`);
    } else {
      $bg.css("border-right-width", borderSize).width(progressWidth);
    }
  },

  _dock() {
    const maximumOffset = $('#topic-footer-buttons').offset(),
          composerHeight = $('#reply-control').height() || 0,
          $topicProgressWrapper = this.$(),
          offset = window.pageYOffset || $('html').scrollTop(),
          topicProgressHeight = $('#topic-progress').height();

    let isDocked = false;
    if (maximumOffset) {
      const threshold = maximumOffset.top;
      const windowHeight = $(window).height();
      isDocked = offset >= threshold - windowHeight + topicProgressHeight + composerHeight;
    }

    const $mainButtons = $('#topic-footer-main-buttons');
    const mainPos = $mainButtons.length > 0 ? $mainButtons.offset().top : 0;
    const dockPos = $(document).height() - mainPos - topicProgressHeight;

    if (composerHeight > 0) {
      if (isDocked) {
        $topicProgressWrapper.css('bottom', dockPos);
      } else {
        const height = composerHeight + "px";
        if ($topicProgressWrapper.css('bottom') !== height) {
          $topicProgressWrapper.css('bottom', height);
        }
      }
    } else {
      $topicProgressWrapper.css('bottom', isDocked ? dockPos : '');
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
