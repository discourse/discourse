export default Ember.View.extend({
  elementId: 'topic-progress-wrapper',
  docked: false,
  classNameBindings: ['docked'],

  _inserted: function() {
    this.appEvents.on("composer:opened", this, '_dock')
                  .on("composer:resized", this, '_dock')
                  .on("composer:closed", this, '_dock')
                  .on("topic:scrolled", this, '_dock');

    // Reflows are expensive. Cache the jQuery selector
    // and the width when inserted into the DOM
    this._$topicProgress = this.$('#topic-progress');
  }.on('didInsertElement'),

  _unbindEvents: function() {
    this.appEvents.off("composer:opened", this, '_dock')
                  .off("composer:resized", this, '_dock')
                  .off("composer:closed", this, '_dock')
                  .off('topic:scrolled', this, '_dock');
  }.on('willDestroyElement'),

  _updateBar: function() {
    Em.run.scheduleOnce('afterRender', this, '_updateProgressBar');
  }.observes('controller.streamPercentage', 'controller.model.postStream.stream.@each').on('init'),

  _updateProgressBar: function() {
    // speeds up stuff, bypass jquery slowness and extra checks
    if (!this._totalWidth) {
      this._totalWidth = this._$topicProgress[0].offsetWidth;
    }
    const totalWidth = this._totalWidth;
    const progressWidth = this.get('controller.streamPercentage') * totalWidth;

    this._$topicProgress.find('.bg')
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

  _focusWhenOpened: function() {

    // Don't focus on mobile or touch
    if (Discourse.Mobile.mobileView || this.capabilities.get('touch')) {
      return;
    }

    if (this.get('controller.expanded')) {
      const self = this;
      Em.run.schedule('afterRender', function() {
        self.$('input').focus();
      });
    }
  }.observes('controller.expanded'),

  click(e) {
    if ($(e.target).parents('#topic-progress').length) {
      this.get('controller').send('toggleExpansion');
    }
  },

  keyDown(e) {
    const controller = this.get('controller');
    if (controller.get('expanded')) {
      if (e.keyCode === 13) {
        controller.send('jumpPost');
      } else if (e.keyCode === 27) {
        controller.send('toggleExpansion');
      }
    }
  }

});
