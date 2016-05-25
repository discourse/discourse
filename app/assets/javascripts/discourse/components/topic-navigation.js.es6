export default Ember.Component.extend({
  showTimeline: null,

  _checkSize() {
    const width = $(window).width();
    this.set('showTimeline', width > 960);
  },

  didInsertElement() {
    this._super();

    if (!this.site.mobileView) {
      $(window).on('resize.discourse-topic-navigation', () => this._checkSize());
      this._checkSize();
    } else {
      this.set('showTimeline', false);
    }
  },

  willDestroyElement() {
    this._super();
    if (!this.site.mobileView) {
      $(window).off('resize.discourse-topic-navigation');
    }
  }
});
