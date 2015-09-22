export default Ember.Component.extend({
  classNameBindings: [':gap', ':jagged-border', 'gap::hidden'],

  initGaps: function(){
    this.set('loading', false);
    const before = this.get('before') === 'true';
    const gaps = before ? this.get('postStream.gaps.before') : this.get('postStream.gaps.after');

    if (gaps) {
      this.set('gap', gaps[this.get('post.id')]);
    }
  }.on('init'),

  gapsChanged: function(){
    this.initGaps();
    this.rerender();
  }.observes('post.hasGap'),

  render(buffer) {
    if (this.get('loading')) {
      buffer.push(I18n.t('loading'));
    } else {
      const gapLength = this.get('gap.length');
      if (gapLength) {
        buffer.push(I18n.t('post.gap', {count: gapLength}));
      }
    }
  },

  click() {
    if (this.get('loading') || (!this.get('gap'))) { return false; }
    this.set('loading', true);
    this.rerender();

    const postStream = this.get('postStream');
    const filler = this.get('before') === 'true' ? postStream.fillGapBefore : postStream.fillGapAfter;

    filler.call(postStream, this.get('post'), this.get('gap')).then(() => {
      this.set('gap', null);
    });

    return false;
  }
});
