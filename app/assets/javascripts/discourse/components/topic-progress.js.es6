import { default as computed, observes } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  elementId: 'topic-progress-wrapper',
  classNameBindings: ['docked'],
  docked: false,
  progressPosition: null,
  postStream: Ember.computed.alias('topic.postStream'),
  _streamPercentage: null,

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

  @computed('progressPosition', 'topic.last_read_post_id')
  showBackButton(position, lastReadId) {
    if (!lastReadId) { return; }

    const stream = this.get('postStream.stream');
    const readPos = stream.indexOf(lastReadId) || 0;
    return (readPos < (stream.length - 1)) && (readPos > position);
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
                  .on('topic:current-post-scrolled', this, this._topicScrolled);

    const prevEvent = this.get('prevEvent');
    if (prevEvent) {
      Ember.run.scheduleOnce('afterRender', this, this._topicScrolled, prevEvent);
    } else {
      Ember.run.scheduleOnce('afterRender', this, this._updateProgressBar);
    }
    Ember.run.scheduleOnce('afterRender', this, this._dock);
  },

  willDestroyElement() {
    this._super();
    this.appEvents.off('composer:will-open', this, this._dock)
                  .off("composer:resized", this, this._dock)
                  .off('composer:closed', this, this._dock)
                  .off('topic:scrolled', this, this._dock)
                  .off('topic:current-post-scrolled', this, this._topicScrolled);
  },

  _updateProgressBar() {
    if (this.isDestroyed || this.isDestroying) { return; }

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

    if (!$topicProgressWrapper || $topicProgressWrapper.length === 0) {
      return;
    }

    let isDocked = false;
    if (maximumOffset) {
      const threshold = maximumOffset.top;
      const windowHeight = $(window).height();
      isDocked = offset >= threshold - windowHeight + topicProgressHeight + composerHeight;
    }

    const dockPos = $(document).height() - $('#topic-bottom').offset().top;
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


  actions: {
    toggleExpansion() {
      this.toggleProperty('expanded');
    },

    goBack() {
      this.attrs.jumpToPost(this.get('topic.last_read_post_number'));
    }
  },

});
