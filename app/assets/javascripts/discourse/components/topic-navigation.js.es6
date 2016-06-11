export default Ember.Component.extend({
  composerOpen: null,
  classNameBindings: ['composerOpen'],
  showTimeline: null,
  info: null,

  _checkSize() {
    const renderTimeline = $(window).width() > 960;
    this.set('info', { renderTimeline, showTimeline: renderTimeline && !this.get('composerOpen') });
  },

  composerOpened() {
    this.set('composerOpen', true);
    this._checkSize();
  },

  composerClosed() {
    this.set('composerOpen', false);
    this._checkSize();
  },

  didInsertElement() {
    this._super();

    if (!this.site.mobileView) {
      $(window).on('resize.discourse-topic-navigation', () => this._checkSize());
      this.appEvents.on('composer:will-open', this, this.composerOpened);
      this.appEvents.on('composer:will-close', this, this.composerClosed);
      this._checkSize();
    } else {
      this.set('info', null);
    }
  },

  willDestroyElement() {
    this._super();
    if (!this.site.mobileView) {
      $(window).off('resize.discourse-topic-navigation');
      this.appEvents.off('composer:will-open', this, this.composerOpened);
      this.appEvents.off('composer:will-close', this, this.composerClosed);
    }
  }
});
